import json
import os
import glob
from datetime import datetime

print("✅ Skript gestartet...")

def get_latest_file(path):
    list_of_files = glob.glob(f'{path}/*.json')
    if not list_of_files:
        return None
    return max(list_of_files, key=os.path.getctime)

def transform_odds():
    print("🔍 Suche nach Daten...")
    raw_path = os.path.join(os.getcwd(), "data/raw")
    
    if not os.path.exists(raw_path):
        print(f"❌ Ordner nicht gefunden: {raw_path}")
        return

    latest_file = get_latest_file(raw_path)
    
    if not latest_file:
        print(f"❌ Keine .json Dateien in {raw_path} gefunden.")
        return

    print(f"🔄 Verarbeite: {latest_file}")

    with open(latest_file, "r", encoding="utf-8") as f:
        raw_data = json.load(f)

    processed_data = []

    for game in raw_data:
        home_team = game.get('home_team')
        away_team = game.get('away_team')
        
        # Variablen zum Speichern der besten Angebote
        best_home_price = 0
        best_home_bookie = ""
        best_away_price = 0
        best_away_bookie = ""
        
        all_home_prices = []
        all_away_prices = []

        for bookmaker in game.get('bookmakers', []):
            bookie_name = bookmaker.get('title')
            for market in bookmaker.get('markets', []):
                if market['key'] == 'h2h':
                    for outcome in market['outcomes']:
                        price = outcome['price']
                        if outcome['name'] == home_team:
                            all_home_prices.append(price)
                            # Prüfen, ob dies der neue Bestwert ist
                            if price > best_home_price:
                                best_home_price = price
                                best_home_bookie = bookie_name
                        elif outcome['name'] == away_team:
                            all_away_prices.append(price)
                            # Prüfen, ob dies der neue Bestwert ist
                            if price > best_away_price:
                                best_away_price = price
                                best_away_bookie = bookie_name

        if all_home_prices and all_away_prices:
            avg_home = sum(all_home_prices) / len(all_home_prices)
            avg_away = sum(all_away_prices) / len(all_away_prices)
            
            processed_data.append({
                "game": f"{home_team} vs {away_team}",
                "avg_home": round(avg_home, 2),
                "max_home": best_home_price,
                "bookie_home": best_home_bookie, # <--- NEU
                "is_home_value": best_home_price > (avg_home * 1.05),
                "avg_away": round(avg_away, 2),
                "max_away": best_away_price,
                "bookie_away": best_away_bookie, # <--- NEU
                "is_away_value": best_away_price > (avg_away * 1.05)
            })

    # Speichern in data/processed
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = os.path.join(os.getcwd(), "data/processed", f"value_bets_{timestamp}.json")
    
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(processed_data, f, indent=4, ensure_ascii=False)

    print(f"🏁 Fertig! {len(processed_data)} Spiele in {output_path} gespeichert.")

if __name__ == "__main__":
    transform_odds()