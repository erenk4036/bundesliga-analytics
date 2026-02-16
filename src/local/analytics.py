import json
import glob
import os
from datetime import datetime
from typing import List, Dict

def load_latest_processed_data() -> List[Dict]:
    """Retrieve the most recent analyzed dataset from the processed directory"""
    processed_path = "data/processed"
    list_of_files = glob.glob(f'{processed_path}/value_bets_*.json')
    
    if not list_of_files:
        print("Error: No processed data files found.")
        return []
    
    latest_file = max(list_of_files, key=os.path.getctime)
    with open(latest_file, 'r', encoding='utf-8') as f:
        return json.load(f)

def print_value_bets_report(data: List[Dict]):
    """Generate a formatted terminal report of current betting opportunities"""
    print("\n" + "="*80)
    print("BUNDESLIGA VALUE BETTING ANALYTICS")
    print("="*80)
    print(f"Analysis Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Events Analyzed: {len(data)}")
    print("="*80)
    
    strong_signals = [g for g in data if g['home_recommendation'] == 'STRONG BUY' or g['away_recommendation'] == 'STRONG BUY']
    
    print(f"\n[HIGH CONVICTION SIGNALS: {len(strong_signals)}]")
    for game in strong_signals:
        side = 'HOME' if game['home_recommendation'] == 'STRONG BUY' else 'AWAY'
        val = game['home_value_pct'] if side == 'HOME' else game['away_value_pct']
        price = game['max_home'] if side == 'HOME' else game['max_away']
        bookie = game['bookie_home'] if side == 'HOME' else game['bookie_away']
        
        print(f"\nMatch: {game['game']}")
        print(f"Target: {side} WIN | Edge: +{val}%")
        print(f"Execution: {price} at {bookie}")

    print("\n" + "="*80)
    print("REPORT COMPLETE")
    print("="*80)

if __name__ == "__main__":
    data = load_latest_processed_data()
    if data:
        print_value_bets_report(data)