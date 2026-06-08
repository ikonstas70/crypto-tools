import requests
import time
import shutil
import os

def fetch_crypto_price(currency):
    """Fetches the price of a cryptocurrency from Coinbase."""
    url = f"https://api.coinbase.com/v2/prices/{currency}-USD/spot"
    try:
        response = requests.get(url, timeout=5)
        response.raise_for_status()
        data = response.json()
        return float(data.get('data', {}).get('amount', 0))
    except requests.exceptions.RequestException:
        return None  # Return None if there's an error

def format_price_change(current_price, previous_price):
    """Formats price with color based on change."""
    if current_price is None:
        return "\033[0;33mData unavailable\033[0m"

    formatted_price = f"{current_price:.2f}"

    if previous_price is not None:
        change = current_price - previous_price
        if change > 0:
            formatted_price = f"\033[0;32m{current_price:.2f} (+{change:.2f})\033[0m"
        elif change < 0:
            formatted_price = f"\033[0;31m{current_price:.2f} ({change:.2f})\033[0m"
    
    return formatted_price

def display_crypto_prices(currencies, previous_prices, frame_width):
    """Fetches and displays cryptocurrency prices inside a static frame, aligned left."""
    
    # Move cursor up to overwrite previous content (doesn't scroll)
    print("\033[H", end="")

    # Print static frame
    print("═" * frame_width)
    print(" Crypto Prices (USD) ")
    print("═" * frame_width)

    # Fetch and print prices
    for currency in currencies:
        current_price = fetch_crypto_price(currency)
        formatted_price = format_price_change(current_price, previous_prices.get(currency))
        print(f" {currency}: {formatted_price}")  # Left-aligned output

        if current_price is not None:
            previous_prices[currency] = current_price  # Update previous price

    print("═" * frame_width)

def main():
    """Main function to run the price tracker."""
    currencies_to_track = ['BTC', 'ETH', 'LTC', 'DOGE']
    previous_prices = {}

    # Get terminal width and set frame width
    frame_width = min(shutil.get_terminal_size((80, 20)).columns, 50)

    try:
        os.system('clear' if os.name == 'posix' else 'cls')  # Clear terminal before start
        while True:
            display_crypto_prices(currencies_to_track, previous_prices, frame_width)
            time.sleep(10)
    except KeyboardInterrupt:
        print("\nExiting price tracker. Goodbye!")

if __name__ == "__main__":
    main()
