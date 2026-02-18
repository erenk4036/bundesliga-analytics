"""
analytics.py  -  ETL Stage 3: Load
Lambda function that reads the latest processed value-bets JSON from S3
and writes high-conviction signals to DynamoDB.

Environment variables (set by Terraform):
    PROCESSED_BUCKET_NAME - S3 bucket for processed data
    DYNAMODB_ODDS_TABLE   - DynamoDB table for raw odds records
    DYNAMODB_BETS_TABLE   - DynamoDB table for value-bet signals
    LOG_LEVEL             - "INFO" or "WARNING"
"""

import json
import os
import logging
import uuid
import boto3
from datetime import datetime, timezone
from decimal import Decimal
from typing import List, Dict, Optional
from boto3.dynamodb.conditions import Key

# --------------------------------------------------------------------------
# Logging
# --------------------------------------------------------------------------
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# --------------------------------------------------------------------------
# AWS Clients (outside handler for warm-start connection reuse)
# --------------------------------------------------------------------------
s3_client  = boto3.client("s3")
dynamodb   = boto3.resource("dynamodb")

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
PROCESSED_BUCKET_NAME = os.environ["PROCESSED_BUCKET_NAME"]
DYNAMODB_ODDS_TABLE   = os.environ["DYNAMODB_ODDS_TABLE"]
DYNAMODB_BETS_TABLE   = os.environ["DYNAMODB_BETS_TABLE"]
PROCESSED_PREFIX      = "odds/processed/"

# DynamoDB TTL: retain records for 90 days
TTL_DAYS = 90


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def get_ttl_timestamp() -> int:
    """Return a Unix timestamp 90 days in the future for DynamoDB TTL."""
    from datetime import timedelta
    future = datetime.now(timezone.utc) + timedelta(days=TTL_DAYS)
    return int(future.timestamp())


def float_to_decimal(value) -> Decimal:
    """
    DynamoDB does not accept Python float — convert to Decimal.
    Using str(value) avoids floating-point precision artifacts.
    """
    if isinstance(value, float):
        return Decimal(str(value))
    return value


def sanitise_record(record: dict) -> dict:
    """Recursively convert all floats in a dict to Decimal for DynamoDB."""
    return {
        k: float_to_decimal(v) if isinstance(v, float) else v
        for k, v in record.items()
    }


def get_latest_processed_key(bucket: str, prefix: str) -> Optional[str]:
    """Return the S3 key of the most recently modified processed file."""
    response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
    contents = response.get("Contents", [])

    if not contents:
        logger.warning("No processed files found in s3://%s/%s", bucket, prefix)
        return None

    latest = max(contents, key=lambda obj: obj["LastModified"])
    logger.info("Latest processed file: %s", latest["Key"])
    return latest["Key"]


def read_json_from_s3(bucket: str, key: str) -> list:
    """Download and parse a JSON object from S3."""
    response = s3_client.get_object(Bucket=bucket, Key=key)
    return json.loads(response["Body"].read().decode("utf-8"))


# --------------------------------------------------------------------------
# DynamoDB write logic
# --------------------------------------------------------------------------

def write_value_bets(data: List[Dict], table_name: str) -> int:
    """
    Write strong buy / buy signals to the value_bets DynamoDB table.
    Uses batch_writer for efficiency (up to 25 items per API call).
    Returns the number of items written.
    """
    table     = dynamodb.Table(table_name)
    today     = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    ttl_value = get_ttl_timestamp()
    written   = 0

    # Filter only actionable signals (STRONG BUY or BUY)
    signals = [
        g for g in data
        if g.get("home_recommendation") in ("STRONG BUY", "BUY")
        or g.get("away_recommendation") in ("STRONG BUY", "BUY")
    ]

    logger.info("Writing %d value-bet signals to DynamoDB", len(signals))

    # Collect items first, add uniqueness
    items_to_write = []
    counter = 0
    
    for game in signals:
        # One item per side that has a BUY signal
        for side in ("home", "away"):
            recommendation = game.get(f"{side}_recommendation", "HOLD")
            if recommendation not in ("STRONG BUY", "BUY"):
                continue

            # Make value_percentage unique by adding tiny offset
            value_pct = float(game.get(f"{side}_value_pct", 0))
            unique_value = value_pct + (counter * 0.0001)
            counter += 1
            
            item = sanitise_record({
                # Partition key: date (matches DynamoDB schema)
                "date":             today,
                # Sort key: value_percentage (must be unique)
                "value_percentage": float_to_decimal(unique_value),
                # Additional attributes
                "game_id":          str(uuid.uuid4()),
                "game":             game.get("game"),
                "side":             side.upper(),
                "team":             game.get(f"{side}_team"),
                "best_odds":        float_to_decimal(game.get(f"max_{side}", 0)),
                "bookmaker":        game.get(f"bookie_{side}"),
                "recommendation":   recommendation,
                "market_efficiency": float_to_decimal(
                    game.get(f"{side}_market_efficiency", 0)
                ),
                "actual_value_pct": float_to_decimal(value_pct),  # Original value
                "commence_time":    game.get("commence_time"),
                "bookmaker_count":  game.get("bookmaker_count", 0),
                "expiration_time":  ttl_value,
                "created_at":       datetime.now(timezone.utc).isoformat(),
            })
            items_to_write.append(item)
    
    # Write in batch
    with table.batch_writer() as batch:
        for item in items_to_write:
            batch.put_item(Item=item)
            written += 1

    return written


def write_all_odds(data: List[Dict], table_name: str) -> int:
    """
    Write ALL processed games to the odds DynamoDB table for historical record.
    Returns the number of items written.
    """
    table     = dynamodb.Table(table_name)
    ttl_value = get_ttl_timestamp()
    written   = 0

    with table.batch_writer() as batch:
        for game in data:
            game_id   = f"{game.get('home_team', '')}-vs-{game.get('away_team', '')}"
            timestamp = game.get("fetch_timestamp", datetime.now(timezone.utc).isoformat())

            item = sanitise_record({
                # Partition + sort key (must match DynamoDB schema)
                "game_id":                game_id,
                "timestamp":              timestamp,
                # Attributes
                "game":                   game.get("game"),
                "home_team":              game.get("home_team"),
                "away_team":              game.get("away_team"),
                "commence_time":          game.get("commence_time"),
                "avg_home":               float_to_decimal(game.get("avg_home", 0)),
                "max_home":               float_to_decimal(game.get("max_home", 0)),
                "home_recommendation":    game.get("home_recommendation"),
                "avg_away":               float_to_decimal(game.get("avg_away", 0)),
                "max_away":               float_to_decimal(game.get("max_away", 0)),
                "away_recommendation":    game.get("away_recommendation"),
                "bookmaker_count":        game.get("bookmaker_count", 0),
                "expiration_time":        ttl_value,
                "created_at":             datetime.now(timezone.utc).isoformat(),
            })
            batch.put_item(Item=item)
            written += 1

    return written


# --------------------------------------------------------------------------
# Lambda handler
# --------------------------------------------------------------------------

def lambda_handler(event: dict, context) -> dict:
    logger.info("analytics Lambda started")

    try:
        # 1. Find latest processed file
        processed_key = get_latest_processed_key(PROCESSED_BUCKET_NAME, PROCESSED_PREFIX)
        if not processed_key:
            return {"statusCode": 404, "body": {"error": "No processed data found in S3"}}

        # 2. Load processed data
        data = read_json_from_s3(PROCESSED_BUCKET_NAME, processed_key)
        logger.info("Loaded %d records from %s", len(data), processed_key)

        # 3. Write to DynamoDB
        bets_written = write_value_bets(data, DYNAMODB_BETS_TABLE)
        odds_written = write_all_odds(data, DYNAMODB_ODDS_TABLE)

        # 4. Log strong signals summary
        strong = [
            g for g in data
            if g.get("home_recommendation") == "STRONG BUY"
            or g.get("away_recommendation") == "STRONG BUY"
        ]
        logger.info("High-conviction signals (STRONG BUY): %d", len(strong))
        for game in strong:
            side  = "HOME" if game.get("home_recommendation") == "STRONG BUY" else "AWAY"
            value = game.get("home_value_pct") if side == "HOME" else game.get("away_value_pct")
            logger.info("  → %s | %s | Edge: +%s%%", game.get("game"), side, value)

        return {
            "statusCode": 200,
            "body": {
                "message":           "Analytics complete",
                "records_processed": len(data),
                "value_bets_written": bets_written,
                "odds_written":       odds_written,
                "strong_signals":     len(strong),
                "source_key":         processed_key,
                "timestamp":          datetime.now(timezone.utc).isoformat(),
            }
        }

    except Exception as exc:
        logger.exception("Analytics Lambda failed: %s", exc)
        return {"statusCode": 500, "body": {"error": str(exc)}}