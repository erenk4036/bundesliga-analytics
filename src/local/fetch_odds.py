import requests
import json
import os
from datetime import datetime
from dotenv import load_dotenv

# Konfiguration
load_dotenv()
API_KEY = os.getenv("ODDS_API_KEY")
SPORT = "soccer_germany_bundesliga" 
REGION = "eu"
MARKETS = "h2h" # Sieg, Unentschieden, Niederlage

def fetch_and_save_odds():
    if not API_KEY:
        print("❌ Fehler: API_KEY nicht in .env gefunden!")
        return

    url = f"https://api.the-odds-api.com/v4/sports/{SPORT}/odds/?apiKey={API_KEY}&regions={REGION}&markets={MARKETS}"
    
    try:
        print(f"📡 Rufe Bundesliga-Daten ab...")
        response = requests.get(url)
        response.raise_for_status() # Throw Error for 5xx and 4xx 
        
        data = response.json()
        
        # Dateiname mit Zeitstempel erstellen
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"data/raw/odds_{timestamp}.json"
        
        # Daten lokal speichern
        with open(filename, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4, ensure_ascii=False)
            
        print(f"✅ Erfolg! {len(data)} Spiele gespeichert unter: {filename}")
        
    except Exception as e:
        print(f"❌ Ein Fehler ist aufgetreten: {e}")

if __name__ == "__main__":
    fetch_and_save_odds()