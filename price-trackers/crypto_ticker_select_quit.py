import requests
import time
import sys
import os
import select

# Configuration (moved to top for easier modification)
CURRENCIES_TO_TRACK = ['BTC', 'ETH', 'LTC', 'DOGE']
API_TIMEOUT = 5  # seconds
UPDATE_INTERVAL = 10  # seconds

# Function to fetch cryptocurrency price
def fetch_crypto_price(currency):
    """Fetches the price of a cryptocurrency from Coinbase."""
    url = f"https://api.coinbase.com/v2/prices/{currency}-USD/spot"
    try:
        response = requests.get(url, timeout=API_TIMEOUT)
        response.raise_for_status()  # Check for HTTP errors (4xx or 5xx)
        data = response.json()
        return float(data.get('data', {}).get('amount'))  # Simplified extraction
    except requests.exceptions.RequestException as e:
        print(f"Error fetching {currency} price: {e}", file=sys.stderr)  # Print errors to stderr
    except (KeyError, TypeError, ValueError) as e:  # Handle JSON/type errors
        print(f"Error parsing {currency} data: {e}. Check API response.", file=sys.stderr)
    return None  # Return None if fetching fails

# Function to format the price change with color
def format_price_change(current_price, previous_price):
    """Formats price with color based on change."""
    if current_price is None:
        return "\033[0;33mData unavailable\033[0m"  # Yellow text for unavailable data

    formatted_price = f"{current_price:.2f}"  # Default format

    if previous_price is not None:
        change = current_price - previous_price
        if change > 0:
            formatted_price = f"\033[0;32m{current_price:.2f} (+{change:.2f})\033[0m"  # Green
        elif change < 0:
            formatted_price = f"\033[0;31m{current_price:.2f} ({change:.2f})\033[0m"  # Red
    return formatted_price

# Function to display the cryptocurrency prices
def display_crypto_prices(currencies, previous_prices):
    """Fetches and displays cryptocurrency prices."""
    os.system('cls' if os.name == 'nt' else 'clear')  # Cross-platform clear

    print("\033[1;36m════════════════════════════════\033[0m")
    print("\033[1;36m       Crypto Prices (USD)       \033[0m")
    print("\033[1;36m════════════════════════════════\033[0m")

    for currency in currencies:
        current_price = fetch_crypto_price(currency)
        formatted_price = format_price_change(current_price, previous_prices.get(currency))
        print(f" {currency}: {formatted_price}")

        if current_price is not None:
            previous_prices[currency] = current_price  # Update previous price

    print("\033[1;36m════════════════════════════════\033[0m")
    print("\033[1;33m Press 'Q' to Quit \033[0m")


# Main loop to keep the program running
def main():
    """Main function to run the price tracker."""
    previous_prices = {}  # Dictionary to store previous prices

    try:
        while True:
            # Check for keypress (e.g., 'Q' to quit) with timeout
            if sys.stdin in select.select([sys.stdin], [], [], UPDATE_INTERVAL)[0]:  # Timeout matches update interval
                if sys.stdin.read(1).lower() == 'q':  # If 'Q' is pressed, quit
                    print("\nExiting price tracker. Goodbye!")
                    break

            display_crypto_prices(CURRENCIES_TO_TRACK, previous_prices)

    except KeyboardInterrupt:
        print("\nExiting price tracker. Goodbye!")

if __name__ == "__main__":
    main()

