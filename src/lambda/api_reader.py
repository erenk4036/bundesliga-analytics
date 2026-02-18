"""
api_reader.py - API Backend Lambda
Reads value betting data from DynamoDB and returns it to the frontend
via API Gateway.

Environment variables (set by Terraform):
    DYNAMODB_BETS_TABLE - DynamoDB table for value-bet signals
    DYNAMODB_ODDS_TABLE - DynamoDB table for odds records
    LOG_LEVEL           - "INFO" or "WARNING"
"""

import json
import os
import logging
import boto3
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from typing import List, Dict

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
# AWS Clients
# --------------------------------------------------------------------------
dynamodb = boto3.resource("dynamodb")

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
DYNAMODB_BETS_TABLE = os.environ["DYNAMODB_BETS_TABLE"]


# --------------------------------------------------------------------------
# Helper Functions
# --------------------------------------------------------------------------

def decimal_to_float(obj):
    """Convert Decimal objects to float for JSON serialization."""
    if isinstance(obj, Decimal):
        return float(obj)
    elif isinstance(obj, dict):
        return {k: decimal_to_float(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [decimal_to_float(i) for i in obj]
    return obj


def get_value_bets(date: str = None, limit: int = 50) -> List[Dict]:
    """
    Query DynamoDB for value betting signals.
    If date is None, gets today's bets.
    """
    table = dynamodb.Table(DYNAMODB_BETS_TABLE)
    
    # Default to today if no date provided
    if not date:
        date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    
    try:
        response = table.query(
            KeyConditionExpression="date = :date",
            ExpressionAttributeValues={
                ":date": date
            },
            ScanIndexForward=False,  # Sort by value_percentage descending
            Limit=limit
        )
        
        items = response.get("Items", [])
        logger.info(f"Retrieved {len(items)} value bets for date {date}")
        
        # Convert Decimal to float for JSON
        return decimal_to_float(items)
        
    except Exception as exc:
        logger.exception(f"Error querying DynamoDB: {exc}")
        return []


def get_recent_bets(days: int = 7, limit: int = 100) -> List[Dict]:
    """
    Scan for recent bets across multiple days.
    Used for dashboard overview.
    """
    table = dynamodb.Table(DYNAMODB_BETS_TABLE)
    
    try:
        # Calculate date range
        today = datetime.now(timezone.utc)
        dates = [(today - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(days)]
        
        all_items = []
        
        for date in dates:
            response = table.query(
                KeyConditionExpression="date = :date",
                ExpressionAttributeValues={
                    ":date": date
                },
                ScanIndexForward=False,
                Limit=limit // days  # Distribute limit across days
            )
            all_items.extend(response.get("Items", []))
        
        # Sort by value percentage
        all_items.sort(key=lambda x: float(x.get("value_percentage", 0)), reverse=True)
        
        logger.info(f"Retrieved {len(all_items)} bets across {days} days")
        
        return decimal_to_float(all_items[:limit])
        
    except Exception as exc:
        logger.exception(f"Error scanning DynamoDB: {exc}")
        return []


# --------------------------------------------------------------------------
# Lambda Handler
# --------------------------------------------------------------------------

def lambda_handler(event: dict, context) -> dict:
    """
    API Gateway Lambda handler.
    
    Query Parameters:
        - date: YYYY-MM-DD (optional, defaults to today)
        - days: number of recent days (optional, defaults to 1)
        - limit: max results (optional, defaults to 50)
    
    Returns JSON array of value betting opportunities.
    """
    logger.info("API Reader Lambda invoked")
    
    # CORS headers for browser requests
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type"
    }
    
    try:
        # Parse query parameters
        params = event.get("queryStringParameters") or {}
        date = params.get("date")
        days = int(params.get("days", "1"))
        limit = int(params.get("limit", "50"))
        
        # Validate inputs
        if limit > 200:
            limit = 200  # Cap at 200 for performance
        
        # Fetch data based on parameters
        if days > 1:
            data = get_recent_bets(days=days, limit=limit)
        else:
            data = get_value_bets(date=date, limit=limit)
        
        # Response metadata
        response_body = {
            "success": True,
            "count": len(data),
            "date": date or datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            "days": days,
            "data": data,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps(response_body, default=str)
        }
        
    except ValueError as exc:
        logger.error(f"Invalid parameter: {exc}")
        return {
            "statusCode": 400,
            "headers": headers,
            "body": json.dumps({
                "success": False,
                "error": "Invalid query parameters",
                "message": str(exc)
            })
        }
        
    except Exception as exc:
        logger.exception(f"API Reader failed: {exc}")
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({
                "success": False,
                "error": "Internal server error",
                "message": str(exc)
            })
        }
