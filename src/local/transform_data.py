import json
import os
import glob
import logging
from datetime import datetime
from typing import List, Dict, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def get_latest_file(path: str) -> Optional[str]:
    """Locate the most recent JSON file in the given directory"""
    list_of_files = glob.glob(f'{path}/*.json')
    if not list_of_files:
        return None
    return max(list_of_files, key=os.path.getctime)

def implied_probability(odds: float) -> float:
    """Calculate implied probability percentage from decimal odds"""
    if odds <= 1.0:
        return 0.0
    return round((1 / odds) * 100, 2)

def calculate_std_dev(prices: List[float]) -> float:
    """Calculate the standard deviation of a given list of odds"""
    if not prices or len(prices) < 2:
        return 0.0
    
    avg = sum(prices) / len(prices)
    variance = sum((p - avg) ** 2 for p in prices) / len(prices)
    return variance ** 0.5

def market_efficiency_score(prices: List[float]) -> float:
    """
    Calculate Coefficient of Variation as a market efficiency metric.
    Lower score indicates higher bookmaker consensus (efficient market).
    """
    if not prices or len(prices) < 2:
        return 0.0
    
    avg = sum(prices) / len(prices)
    std = calculate_std_dev(prices)
    
    if avg == 0:
        return 0.0
    
    return round(std / avg, 4)

def get_recommendation(value_pct: float, efficiency: float) -> str:
    """Generate a betting recommendation based on value and market consensus"""
    if value_pct > 7 and efficiency < 0.03:
        return "STRONG BUY"
    elif value_pct > 5 and efficiency < 0.05:
        return "BUY"
    elif value_pct > 3:
        return "CONSIDER"
    else:
        return "HOLD"

def calculate_value_percentage(best_price: float, avg_price: float) -> float:
    """Determine the percentage by which the best odds exceed the market average"""
    if avg_price == 0:
        return 0.0
    return round(((best_price - avg_price) / avg_price) * 100, 2)

def transform_odds():
    """Main pipeline: Transform raw market data into value betting analysis"""
    logger.info("Initializing data transformation pipeline")
    
    raw_path = os.path.join(os.getcwd(), "data/raw")
    latest_file = get_latest_file(raw_path)
    
    if not latest_file:
        logger.error(f"Directory empty or not found: {raw_path}")
        return

    logger.info(f"Processing source file: {os.path.basename(latest_file)}")

    try:
        with open(latest_file, "r", encoding="utf-8") as f:
            raw_data = json.load(f)
    except Exception as e:
        logger.error(f"Failed to load source JSON: {e}")
        return

    processed_data = []
    logger.info(f"Analyzing {len(raw_data)} fixtures")

    for game in raw_data:
        home_team = game.get('home_team')
        away_team = game.get('away_team')
        
        all_home_prices, all_away_prices, all_draw_prices = [], [], []
        best_home, best_away, best_draw = 0, 0, 0
        b_home_bk, b_away_bk, b_draw_bk = "", "", ""

        for bookmaker in game.get('bookmakers', []):
            name = bookmaker.get('title')
            for market in bookmaker.get('markets', []):
                if market['key'] == 'h2h':
                    for outcome in market['outcomes']:
                        p, n = outcome['price'], outcome['name']
                        if n == home_team:
                            all_home_prices.append(p)
                            if p > best_home: best_home, b_home_bk = p, name
                        elif n == away_team:
                            all_away_prices.append(p)
                            if p > best_away: best_away, b_away_bk = p, name
                        elif n == 'Draw':
                            all_draw_prices.append(p)
                            if p > best_draw: best_draw, b_draw_bk = p, name

        if all_home_prices and all_away_prices:
            avg_h, avg_a = sum(all_home_prices)/len(all_home_prices), sum(all_away_prices)/len(all_away_prices)
            avg_d = sum(all_draw_prices)/len(all_draw_prices) if all_draw_prices else 0
            
            # Pack processed data
            processed_data.append({
                "game": f"{home_team} vs {away_team}",
                "home_team": home_team, "away_team": away_team,
                "commence_time": game.get('commence_time'),
                "fetch_timestamp": datetime.now().isoformat(),
                "avg_home": round(avg_h, 2), "max_home": best_home, "bookie_home": b_home_bk,
                "home_value_pct": calculate_value_percentage(best_home, avg_h),
                "home_market_efficiency": market_efficiency_score(all_home_prices),
                "home_recommendation": get_recommendation(calculate_value_percentage(best_home, avg_h), market_efficiency_score(all_home_prices)),
                "avg_away": round(avg_a, 2), "max_away": best_away, "bookie_away": b_away_bk,
                "away_value_pct": calculate_value_percentage(best_away, avg_a),
                "away_market_efficiency": market_efficiency_score(all_away_prices),
                "away_recommendation": get_recommendation(calculate_value_percentage(best_away, avg_a), market_efficiency_score(all_away_prices)),
                "bookmaker_count": len(game.get('bookmakers', []))
            })

    # Save output
    output_path = f"data/processed/value_bets_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    os.makedirs("data/processed", exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(processed_data, f, indent=4)
    
    logger.info(f"Transformation complete. Results saved to {output_path}")

if __name__ == "__main__":
    transform_odds()