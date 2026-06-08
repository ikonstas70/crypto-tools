# Crypto Tools

**Author:** Ioannis Konstas — IT Solutions USA

Real-time cryptocurrency price trackers and Bitcoin blockchain explorer tools. Scripts are organized into two groups: live price monitoring via the Coinbase API, and Bitcoin Core blockchain queries.

---

## `price-trackers/` — Real-Time Crypto Price Monitoring

Live terminal dashboards tracking BTC, ETH, LTC, and DOGE prices in USD via the Coinbase public API. Color-coded: green for gains, red for losses. Represents an iterative series from a minimal loop to a production-ready dashboard.

| Script | Description |
|---|---|
| `crypto_ticker_basic.py` | Minimal ticker — polls Coinbase every 10s, prints color-coded price changes to the terminal |
| `crypto_ticker_framed_centered.py` | Prices displayed inside a centered bordered box that refreshes in place without scrolling |
| `crypto_ticker_framed_left_aligned.py` | Same bordered box display with left-aligned prices instead of centered |
| `crypto_ticker_terminal_lock.py` | Locks the terminal window to 36×8 and exits on a single Q keypress via raw tty input |
| `crypto_ticker_resize_shell.py` | Resizes the terminal to a fixed size using the `resize` shell command before starting |
| `crypto_ticker_resize_ansi.py` | Resizes the terminal using the ANSI `\033[8;rows;colst` escape sequence |
| `crypto_ticker_clean_config.py` | Production version — all parameters as named constants, errors to stderr, cross-platform clear |
| `crypto_price_json_output.py` | One-shot price fetcher — outputs current BTC/ETH/LTC/DOGE prices as a JSON object to stdout |
| `crypto_prices_colored_display.py` | Cyan double-line bordered frame with continuous 10-second refresh loop |
| `crypto_prices_colored_display_v2.py` | Same as above with a slightly narrower frame width |
| `crypto_ticker_select_quit.py` | Uses `select.select()` for non-blocking Q-to-quit — more responsive than sleep-based versions |

**Requirements:** `pip install requests`

---

## `blockchain/` — Bitcoin Core Blockchain Explorer

Scripts that query a local Bitcoin Core node to retrieve block data and explore the halving phase timeline.

| Script | Description |
|---|---|
| `bitcoin_halving_phases_explorer.sh` | Queries a local Bitcoin Core node for block hash, coinbase reward, and timestamp at each halving boundary (Phases 1–5) |
| `bitcoin_block_monitor.py` | Live block monitor — polls every 10s, displays hash, height, coinbase value, difficulty, Merkle root, and nonce in a 100-char terminal box; logs to file |
| `bitcoin_node_security_monitor.sh` | Intelligent Bitcoin node security dashboard — heuristic threat detection (peer spikes, time drift, suspicious agents, chain tip divergence), alerts to log and syslog |
| `bitcoin_genesis_block_query.sh` | Six methods to query the Genesis Block (height 0) — by height, header only, coinbase tx, curl JSON-RPC, REST interface, and multi-block iteration |
| `bitcoin_lxd_sandbox_analysis.md` | LXD container network isolation analysis — confirms Bitcoin sandbox is isolated from LAN with only expected ports open |

**Requirements:** Fully synced Bitcoin Core node with `bitcoin-core.cli` in PATH; `jq` for the shell script.

---

*© Ioannis Konstas — IT Solutions USA*
