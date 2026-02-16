import requests
import json
import os
import logging
from datetime import datetime
from dotenv import load_dotenv

# Configure Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
load_dotenv()
API_KEY = os.getenv("ODDS_API_KEY")
SPORT = "soccer_germany_bundesliga"
REGION = "eu"
MARKETS = "h2h"
ODDS_FORMAT = "decimal"

def validate_api_key():
    """Verify that the API key is present in environment variables"""
    if not API_KEY:
        raise ValueError("API_KEY not found in .env file!")
    logger.info("API Key validation successful")
    return True

def fetch_and_save_odds():
    """
    Retrieves Bundesliga odds from The Odds API and saves them to local storage
    Returns: Path to the saved file or None if the request fails
    """
    try:
        validate_api_key()
        
        url = f"https://api.the-odds-api.com/v4/sports/{SPORT}/odds/"
        
        params = {
            'apiKey': API_KEY,
            'regions': REGION,
            'markets': MARKETS,
            'oddsFormat': ODDS_FORMAT
        }
        
        logger.info(f"Initialting data fetch for: {SPORT}")
        
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        
        # Log API usage statistics
        requests_remaining = response.headers.get('x-requests-remaining', 'unknown')
        requests_used = response.headers.get('x-requests-used', 'unknown')
        logger.info(f"API Usage - Used: {requests_used}, Remaining: {requests_remaining}")
        
        if requests_remaining != 'unknown' and int(requests_remaining) < 50:
            logger.warning(f"Low API quota: {requests_remaining} requests left")

        # Prepare file storage
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_dir = "data/raw"
        os.makedirs(output_dir, exist_ok=True)
        filename = f"{output_dir}/odds_{timestamp}.json"
        
        # Daten speichern
        with open(filename, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4, ensure_ascii=False)
        
        logger.info(f"Successfully stored {len(data)} matches in {filename}")
        return filename
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Network or API error occurred: {e}")
        return None
    except Exception as e:
        logger.error(f"Unexpected execution error: {e}")
        return None

if __name__ == "__main__":
    result = fetch_and_save_odds()
    if result:
        logger.info("Data ingestion completed successfully")
    else:
        logger.error("Data ingestion failed")
        exit(1)