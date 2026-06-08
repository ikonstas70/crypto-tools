#!/usr/bin/env bash
#
# bitcoin_genesis_block_query.sh
# Author: Ioannis Alexander Konstas — IT Solutions USA
#
# Six methods to query the Bitcoin Genesis Block (height 0) using
# bitcoin-cli, curl (JSON-RPC), and the REST interface.
#
# Requirements: bitcoin-core.cli (or bitcoin-cli) in PATH, jq
#
# Usage:
#   chmod +x bitcoin_genesis_block_query.sh
#   ./bitcoin_genesis_block_query.sh
#

CLI="${BITCOIN_CLI:-/snap/bin/bitcoin-core.cli}"
RPC_USER="${BITCOIN_RPC_USER:-user}"
RPC_PASS="${BITCOIN_RPC_PASS:-pass}"
RPC_HOST="127.0.0.1"
RPC_PORT="8332"

separator() { echo; echo "--- $1 ---"; echo; }

# -------------------------------------------------------
# Method 1: By block height (recommended)
# -------------------------------------------------------
separator "Method 1 — By block height (recommended)"

GENESIS_HASH=$("$CLI" getblockhash 0)
echo "Genesis hash: $GENESIS_HASH"
echo
"$CLI" getblock "$GENESIS_HASH" | jq '{hash, height, time, nTx, size, difficulty, merkleroot, nonce, version: .versionHex}'

# -------------------------------------------------------
# Method 2: Header only (lighter / faster)
# -------------------------------------------------------
separator "Method 2 — Block header only"

"$CLI" getblockheader "$GENESIS_HASH" | jq '{hash, height, time, difficulty, mediantime, chainwork}'

# -------------------------------------------------------
# Method 3: Coinbase transaction
# -------------------------------------------------------
separator "Method 3 — Coinbase transaction (requires txindex=1)"

TXID=$("$CLI" getblock "$GENESIS_HASH" | jq -r '.tx[0]')
echo "Genesis coinbase txid: $TXID"
echo "Note: getrawtransaction may fail without txindex=1 in bitcoin.conf"
"$CLI" getrawtransaction "$TXID" true 2>/dev/null | jq '{txid, size, vout: [.vout[] | {value, scriptType: .scriptPubKey.type}]}' || \
    echo "(getrawtransaction unavailable — enable txindex=1 and reindex)"

# -------------------------------------------------------
# Method 4: JSON-RPC via curl
# -------------------------------------------------------
separator "Method 4 — JSON-RPC via curl"

HASH_RESULT=$(curl -s --user "$RPC_USER:$RPC_PASS" \
    --data-binary '{"jsonrpc":"1.0","id":"genesis","method":"getblockhash","params":[0]}' \
    -H 'content-type:text/plain;' "http://${RPC_HOST}:${RPC_PORT}/" 2>/dev/null)

if echo "$HASH_RESULT" | jq -e '.result' >/dev/null 2>&1; then
    CURL_HASH=$(echo "$HASH_RESULT" | jq -r '.result')
    echo "Hash via RPC: $CURL_HASH"
    curl -s --user "$RPC_USER:$RPC_PASS" \
        --data-binary "{\"jsonrpc\":\"1.0\",\"id\":\"genesis\",\"method\":\"getblock\",\"params\":[\"$CURL_HASH\"]}" \
        -H 'content-type:text/plain;' "http://${RPC_HOST}:${RPC_PORT}/" | jq '.result | {hash, height, time, nTx}'
else
    echo "(curl RPC unavailable — set BITCOIN_RPC_USER / BITCOIN_RPC_PASS or use cookie auth)"
    COOKIE_FILE="${HOME}/.bitcoin/.cookie"
    if [[ -f "$COOKIE_FILE" ]]; then
        echo "Trying cookie auth..."
        COOKIE=$(cat "$COOKIE_FILE")
        curl -s --user "$COOKIE" \
            --data-binary '{"jsonrpc":"1.0","id":"genesis","method":"getblockhash","params":[0]}' \
            -H 'content-type:text/plain;' "http://${RPC_HOST}:${RPC_PORT}/" | jq '.result'
    fi
fi

# -------------------------------------------------------
# Method 5: REST interface (if enabled)
# -------------------------------------------------------
separator "Method 5 — REST interface (requires rest=1 in bitcoin.conf)"

REST_RESULT=$(curl -sf "http://${RPC_HOST}:${RPC_PORT}/rest/block/${GENESIS_HASH}.json" 2>/dev/null)
if [[ -n "$REST_RESULT" ]]; then
    echo "$REST_RESULT" | jq '{hash, height, time, nTx}'
else
    echo "(REST not available — add rest=1 to bitcoin.conf and restart)"
fi

# -------------------------------------------------------
# Method 6: Iterate first N blocks
# -------------------------------------------------------
separator "Method 6 — First 3 blocks (height 0, 1, 2)"

for h in 0 1 2; do
    HASH=$("$CLI" getblockhash "$h")
    echo "Block $h: $HASH"
    "$CLI" getblock "$HASH" | jq '{height, hash, time, nTx, merkleroot}' | sed 's/^/  /'
    echo
done

echo "Done."
