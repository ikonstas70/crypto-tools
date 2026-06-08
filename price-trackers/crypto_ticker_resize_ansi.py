import requests
import time
import sys
import os
import select

# Function to fetch cryptocurrency price
def fetch_crypto_price(currency):
    """Fetches the price of a cryptocurrency from Coinbase."""
    url = f"https://api.coinbase.com/v2/prices/{currency}-USD/spot"
    try:
        response = requests.get(url, timeout=5)
        response.raise_for_status()  # Check for HTTP errors (4xx or 5xx)
        data = response.json()
        return float(data.get('data', {}).get('amount', 0))  # Extract and convert to float
    except requests.exceptions.RequestException as e:
        print(f"Error fetching {currency} price: {e}")
    except (KeyError, TypeError, ValueError) as e:  # Handle JSON/type errors
        print(f"Error parsing {currency} data: {e}. Check API response.")
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
    os.system('clear')  # Clear the screen for dynamic output

    print("\033[1;36m══════════════════════════════════════\033[0m")
    print("\033[1;36m         Crypto Prices (USD)         \033[0m")
    print("\033[1;36m══════════════════════════════════════\033[0m")

    for currency in currencies:
        current_price = fetch_crypto_price(currency)
        formatted_price = format_price_change(current_price, previous_prices.get(currency))
        print(f" {currency}: {formatted_price}")

        if current_price is not None:
            previous_prices[currency] = current_price  # Update previous price

    print("\033[1;36m══════════════════════════════════════\033[0m")
    print("\033[1;33m Press 'Q' to Quit \033[0m")

# Main loop to keep the program running
def main():
    """Main function to run the price tracker."""
    currencies_to_track = ['BTC', 'ETH', 'LTC', 'DOGE']  # Tracked currencies
    previous_prices = {}  # Dictionary to store previous prices

    # Manually set terminal size using ANSI escape codes
    sys.stdout.write("\033[8;10;36t")  # Resize terminal to 36x10

    try:
        while True:
            # Check for keypress (e.g., 'Q' to quit)
            if sys.stdin in select.select([sys.stdin], [], [], 10)[0]:  # 10s timeout
                if sys.stdin.read(1).lower() == 'q':  # If 'Q' is pressed, quit
                    print("\nExiting price tracker. Goodbye!")
                    break

            # Display the prices
            display_crypto_prices(currencies_to_track, previous_prices)
            time.sleep(10)  # Delay for 10 seconds before updating

    except KeyboardInterrupt:
        print("\nExiting price tracker. Goodbye!")

if __name__ == "__main__":
    main()
