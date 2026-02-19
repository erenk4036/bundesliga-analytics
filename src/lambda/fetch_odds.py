"""
fetch_odds.py  -  ETL Stage 1: Extract
Lambda function that fetches Bundesliga odds from The Odds API
and stores raw JSON in the S3 raw-data bucket.

Environment variables (set by Terraform):
    RAW_BUCKET_NAME  - S3 bucket for raw data
    SECRET_ARN       - Secrets Manager ARN containing the API key
    SPORT            - e.g. "soccer_germany_bundesliga"
    REGION           - e.g. "eu"
    MARKETS          - e.g. "h2h"
    ODDS_FORMAT      - e.g. "decimal"
    LOG_LEVEL        - "INFO" or "WARNING"
"""

import json
import os
import logging
import boto3
import requests
from datetime import datetime, timezone

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
# AWS Clients - initialised outside the handler for connection reuse
# across warm Lambda invocations (best practice)
# --------------------------------------------------------------------------
secrets_client = boto3.client("secretsmanager")
s3_client = boto3.client("s3")

# --------------------------------------------------------------------------
# Configuration from environment
# --------------------------------------------------------------------------
RAW_BUCKET_NAME = os.environ["RAW_BUCKET_NAME"]
SECRET_ARN      = os.environ["SECRET_ARN"]
SPORT           = os.environ.get("SPORT",       "soccer_germany_bundesliga")
REGION          = os.environ.get("REGION",      "eu")
MARKETS         = os.environ.get("MARKETS",     "h2h")
ODDS_FORMAT     = os.environ.get("ODDS_FORMAT", "decimal")


def get_api_key() -> str:
    """Retrieve API key from AWS Secrets Manager (cached on warm invocations)."""
    response = secrets_client.get_secret_value(SecretId=SECRET_ARN)
    secret   = json.loads(response["SecretString"])
    return secret["ODDS_API_KEY"]


def fetch_odds(api_key: str) -> list:
    """Call The Odds API and return parsed JSON data."""
    url    = f"https://api.the-odds-api.com/v4/sports/{SPORT}/odds/"
    params = {
        "apiKey":     api_key,
        "regions":    REGION,
        "markets":    MARKETS,
        "oddsFormat": ODDS_FORMAT,
    }

    logger.info("Fetching odds for sport: %s", SPORT)
    response = requests.get(url, params=params, timeout=10)
    response.raise_for_status()

    # Log API quota headers
    requests_remaining = response.headers.get("x-requests-remaining", "unknown")
    requests_used      = response.headers.get("x-requests-used",      "unknown")
    logger.info("API quota - used: %s, remaining: %s", requests_used, requests_remaining)

    if requests_remaining != "unknown" and int(requests_remaining) < 50:
        logger.warning("Low API quota: %s requests remaining", requests_remaining)

    return response.json()


def save_to_s3(data: list, bucket: str) -> str:
    """Serialise data to JSON and upload to S3. Returns the S3 key."""
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    s3_key    = f"odds/raw/bundesliga_{timestamp}.json"

    s3_client.put_object(
        Bucket      = bucket,
        Key         = s3_key,
        Body        = json.dumps(data, indent=2, ensure_ascii=False).encode("utf-8"),
        ContentType = "application/json",
    )
    logger.info("Stored %d matches → s3://%s/%s", len(data), bucket, s3_key)
    return s3_key


# --------------------------------------------------------------------------
# Lambda handler - entry point called by AWS
# --------------------------------------------------------------------------
def lambda_handler(event: dict, context) -> dict:
    """
    Main entry point for the Lambda function.
    AWS passes an `event` dict (from EventBridge) and a `context` object.
    Must return a dict with at least a `statusCode` key.
    """
    logger.info("fetch_odds Lambda started")

    try:
        api_key  = get_api_key()
        data     = fetch_odds(api_key)
        s3_key   = save_to_s3(data, RAW_BUCKET_NAME)

        result = {
            "statusCode": 200,
            "body": {
                "message":      "Data ingestion successful",
                "matches_count": len(data),
                "s3_key":        s3_key,
                "timestamp":     datetime.now(timezone.utc).isoformat(),
            }
        }
        logger.info("fetch_odds Lambda completed successfully")
        return result

    except requests.exceptions.RequestException as exc:
        logger.error("Network / API error: %s", exc)
        return {"statusCode": 502, "body": {"error": str(exc)}}

    except Exception as exc:
        logger.exception("Unexpected error: %s", exc)
        return {"statusCode": 500, "body": {"error": str(exc)}}
