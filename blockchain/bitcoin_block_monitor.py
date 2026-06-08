#!/usr/bin/env python3
"""
Bitcoin block monitor — displays live block data in a formatted terminal box.
Author: Ioannis Konstas — IT Solutions USA

Requires a fully synced Bitcoin Core node with bitcoin-core.cli in PATH.
Polls every 10 seconds and displays a new box whenever a new block is detected.
Block data is also appended to bitcoin_block_log.txt in the working directory.

Usage:
    python3 bitcoin_block_monitor.py
"""

import json
import subprocess
import time
import os
from datetime import datetime, timezone

BOX_WIDTH = 100
POLL_INTERVAL = 10  # seconds between block height checks


def run_cli(*args):
    """Runs a bitcoin-core.cli command and returns stdout, or None on error."""
    try:
        result = subprocess.run(
            ["bitcoin-core.cli", *args],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True
        )
        return result.stdout.decode("utf-8").strip()
    except subprocess.CalledProcessError as e:
        print(f"[!] bitcoin-core.cli error: {e.stderr.decode('utf-8').strip()}")
        return None


def get_current_block_height():
    raw = run_cli("getblockcount")
    return int(raw) if raw else None


def get_block_hash(height):
    return run_cli("getblockhash", str(height))


def get_block_data(block_hash):
    raw = run_cli("getblock", block_hash)
    return json.loads(raw) if raw else None


def get_transaction_data(tx_hash):
    raw = run_cli("getrawtransaction", tx_hash, "true")
    return json.loads(raw) if raw else None


def get_first_output_value(block):
    """Returns the value of the first output of the coinbase transaction."""
    try:
        first_tx_hash = block["tx"][0]
        tx = get_transaction_data(first_tx_hash)
        if tx and "vout" in tx:
            for output in tx["vout"]:
                if "value" in output:
                    return output["value"]
    except (KeyError, IndexError, TypeError):
        pass
    return "N/A"


def parse_block(block):
    timestamp = block.get("time")
    date_time = (
        datetime.fromtimestamp(timestamp, timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        if timestamp else "N/A"
    )
    return {
        "Block Hash":          block.get("hash", "N/A"),
        "Block Height":        block.get("height", "N/A"),
        "Date and Time":       date_time,
        "Transaction Value":   get_first_output_value(block),
        "Num Transactions":    block.get("nTx", "N/A"),
        "Block Size":          f"{block.get('size', 'N/A'):,} bytes" if block.get("size") else "N/A",
        "Difficulty":          block.get("difficulty", "N/A"),
        "Merkle Root":         block.get("merkleroot", "N/A"),
        "Version":             block.get("versionHex", "N/A"),
        "Nonce":               block.get("nonce", "N/A"),
    }


def print_block_box(info):
    os.system("cls" if os.name == "nt" else "clear")
    border = "+" + "-" * (BOX_WIDTH - 2) + "+"
    title = "BITCOIN BLOCK MONITOR — IT Solutions USA".center(BOX_WIDTH - 4)
    print(border)
    print(f"| {title} |")
    print(border)
    for label, value in info.items():
        line = f"{label}: {value}"
        print(f"| {line:<{BOX_WIDTH - 4}} |")
    print(border)


def log_block(info):
    with open("bitcoin_block_log.txt", "a") as f:
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        f.write(f"{timestamp} — {json.dumps(info)}\n")


def monitor_blocks():
    print("[*] Starting Bitcoin block monitor. Waiting for new blocks...")
    last_height = -1

    while True:
        height = get_current_block_height()
        if height is None:
            print("[!] Could not reach Bitcoin Core. Retrying...")
            time.sleep(POLL_INTERVAL)
            continue

        if height > last_height:
            block_hash = get_block_hash(height)
            if not block_hash:
                time.sleep(POLL_INTERVAL)
                continue

            block = get_block_data(block_hash)
            if not block:
                time.sleep(POLL_INTERVAL)
                continue

            info = parse_block(block)
            print_block_box(info)
            log_block(info)
            last_height = height
        else:
            print(f"[~] Block {height} — waiting for next block...", end="\r")

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    monitor_blocks()
