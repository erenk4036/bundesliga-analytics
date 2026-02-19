"""
transform_data.py  -  ETL Stage 2: Transform
Lambda function that reads the latest raw odds JSON from S3,
computes value-bet metrics, and writes the processed results
back to the S3 processed-data bucket.

Environment variables (set by Terraform):
    RAW_BUCKET_NAME       - S3 bucket containing raw odds files
    PROCESSED_BUCKET_NAME - S3 bucket for processed / value-bet files
    LOG_LEVEL             - "INFO" or "WARNING"
"""

import json
import os
import logging
import boto3
from datetime import datetime, timezone
from typing import List, Dict, Optional

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
# AWS Clients (outside handler for warm-start reuse)
# --------------------------------------------------------------------------
s3_client = boto3.client("s3")

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
RAW_BUCKET_NAME       = os.environ["RAW_BUCKET_NAME"]
PROCESSED_BUCKET_NAME = os.environ["PROCESSED_BUCKET_NAME"]
RAW_PREFIX            = "odds/raw/"         # Must match fetch_odds.py S3 key prefix
PROCESSED_PREFIX      = "odds/processed/"


# --------------------------------------------------------------------------
# Pure calculation helpers (unchanged from your original script)
# --------------------------------------------------------------------------

def implied_probability(odds: float) -> float:
    """Calculate implied probability percentage from decimal odds."""
    if odds <= 1.0:
        return 0.0
    return round((1 / odds) * 100, 2)


def calculate_std_dev(prices: List[float]) -> float:
    """Standard deviation of a list of odds."""
    if not prices or len(prices) < 2:
        return 0.0
    avg      = sum(prices) / len(prices)
    variance = sum((p - avg) ** 2 for p in prices) / len(prices)
    return variance ** 0.5


def market_efficiency_score(prices: List[float]) -> float:
    """Coefficient of Variation: lower = more efficient / consensus market."""
    if not prices or len(prices) < 2:
        return 0.0
    avg = sum(prices) / len(prices)
    std = calculate_std_dev(prices)
    return round(std / avg, 4) if avg != 0 else 0.0


def get_recommendation(value_pct: float, efficiency: float) -> str:
    """Generate a betting recommendation based on value and market consensus."""
    if value_pct > 7 and efficiency < 0.03:
        return "STRONG BUY"
    elif value_pct > 5 and efficiency < 0.05:
        return "BUY"
    elif value_pct > 3:
        return "CONSIDER"
    return "HOLD"


def calculate_value_percentage(best_price: float, avg_price: float) -> float:
    """Percentage by which the best odds exceed the market average."""
    if avg_price == 0:
        return 0.0
    return round(((best_price - avg_price) / avg_price) * 100, 2)


# --------------------------------------------------------------------------
# S3 helpers
# --------------------------------------------------------------------------

def get_latest_raw_key(bucket: str, prefix: str) -> Optional[str]:
    """Return the S3 key of the most recently modified object under `prefix`."""
    response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
    contents = response.get("Contents", [])

    if not contents:
        logger.warning("No objects found in s3://%s/%s", bucket, prefix)
        return None

    latest = max(contents, key=lambda obj: obj["LastModified"])
    logger.info("Latest raw file: %s (modified: %s)", latest["Key"], latest["LastModified"])
    return latest["Key"]


def read_json_from_s3(bucket: str, key: str) -> list:
    """Download and parse a JSON object from S3."""
    response = s3_client.get_object(Bucket=bucket, Key=key)
    return json.loads(response["Body"].read().decode("utf-8"))


def write_json_to_s3(data: list, bucket: str, key: str) -> None:
    """Serialise `data` to JSON and upload to S3."""
    s3_client.put_object(
        Bucket      = bucket,
        Key         = key,
        Body        = json.dumps(data, indent=2, ensure_ascii=False).encode("utf-8"),
        ContentType = "application/json",
    )
    logger.info("Wrote %d records → s3://%s/%s", len(data), bucket, key)


# --------------------------------------------------------------------------
# Core transform logic
# --------------------------------------------------------------------------

def transform(raw_data: list) -> list:
    """Convert raw odds list into value-bet analysis records."""
    processed = []

    for game in raw_data:
        home_team = game.get("home_team")
        away_team = game.get("away_team")

        all_home, all_away, all_draw = [], [], []
        best_home = best_away = best_draw = 0.0
        bk_home = bk_away = bk_draw = ""

        for bookmaker in game.get("bookmakers", []):
            name = bookmaker.get("title")
            for market in bookmaker.get("markets", []):
                if market["key"] == "h2h":
                    for outcome in market["outcomes"]:
                        price = outcome["price"]
                        team  = outcome["name"]
                        if team == home_team:
                            all_home.append(price)
                            if price > best_home:
                                best_home, bk_home = price, name
                        elif team == away_team:
                            all_away.append(price)
                            if price > best_away:
                                best_away, bk_away = price, name
                        elif team == "Draw":
                            all_draw.append(price)
                            if price > best_draw:
                                best_draw, bk_draw = price, name

        if not all_home or not all_away:
            continue  # Skip incomplete data

        avg_h = sum(all_home) / len(all_home)
        avg_a = sum(all_away) / len(all_away)
        avg_d = sum(all_draw) / len(all_draw) if all_draw else 0.0

        home_val = calculate_value_percentage(best_home, avg_h)
        away_val = calculate_value_percentage(best_away, avg_a)
        home_eff = market_efficiency_score(all_home)
        away_eff = market_efficiency_score(all_away)

        processed.append({
            "game":                     f"{home_team} vs {away_team}",
            "home_team":                home_team,
            "away_team":                away_team,
            "commence_time":            game.get("commence_time"),
            "fetch_timestamp":          datetime.now(timezone.utc).isoformat(),
            "avg_home":                 round(avg_h, 2),
            "max_home":                 best_home,
            "bookie_home":              bk_home,
            "home_value_pct":           home_val,
            "home_market_efficiency":   home_eff,
            "home_recommendation":      get_recommendation(home_val, home_eff),
            "avg_away":                 round(avg_a, 2),
            "max_away":                 best_away,
            "bookie_away":              bk_away,
            "away_value_pct":           away_val,
            "away_market_efficiency":   away_eff,
            "away_recommendation":      get_recommendation(away_val, away_eff),
            "bookmaker_count":          len(game.get("bookmakers", [])),
        })

    return processed


# --------------------------------------------------------------------------
# Lambda handler
# --------------------------------------------------------------------------

def lambda_handler(event: dict, context) -> dict:
    logger.info("transform_data Lambda started")

    try:
        # 1. Find the most recent raw file
        raw_key = get_latest_raw_key(RAW_BUCKET_NAME, RAW_PREFIX)
        if not raw_key:
            return {"statusCode": 404, "body": {"error": "No raw data found in S3"}}

        # 2. Load raw data
        raw_data = read_json_from_s3(RAW_BUCKET_NAME, raw_key)
        logger.info("Loaded %d fixtures from %s", len(raw_data), raw_key)

        # 3. Transform
        processed_data = transform(raw_data)
        logger.info("Transformation produced %d value-bet records", len(processed_data))

        # 4. Save processed output
        timestamp     = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        processed_key = f"{PROCESSED_PREFIX}value_bets_{timestamp}.json"
        write_json_to_s3(processed_data, PROCESSED_BUCKET_NAME, processed_key)

        return {
            "statusCode": 200,
            "body": {
                "message":         "Transformation successful",
                "fixtures_input":  len(raw_data),
                "records_output":  len(processed_data),
                "source_key":      raw_key,
                "output_key":      processed_key,
                "timestamp":       datetime.now(timezone.utc).isoformat(),
            }
        }

    except Exception as exc:
        logger.exception("Transformation failed: %s", exc)
        return {"statusCode": 500, "body": {"error": str(exc)}}