import requests
import sys
import json

CURRENCIES_TO_TRACK = ['BTC', 'ETH', 'LTC', 'DOGE']
API_TIMEOUT = 5  # seconds

def fetch_crypto_price(currency):
    """Fetches the price of a cryptocurrency from Coinbase."""
    url = f"https://api.coinbase.com/v2/prices/{currency}-USD/spot"
    try:
        response = requests.get(url, timeout=API_TIMEOUT)
        response.raise_for_status()  # Check for HTTP errors (4xx or 5xx)
        data = response.json()
        return float(data.get('data', {}).get('amount'))  # Simplified extraction
    except requests.exceptions.RequestException as e:
        return None  # If there's an error, return None
    except (KeyError, TypeError, ValueError) as e:
        return None  # Handle JSON/type errors

def get_prices():
    """Fetches and returns cryptocurrency prices."""
    prices = {}
    for currency in CURRENCIES_TO_TRACK:
        prices[currency] = fetch_crypto_price(currency)
    return prices

if __name__ == "__main__":
    prices = get_prices()
    print(json.dumps(prices))  # Output as JSON
