#!/usr/bin/env bash
#
# bitcoin_node_security_monitor.sh
# Author: Ioannis Alexander Konstas — IT Solutions USA
#
# Intelligent Bitcoin node dashboard with heuristic threat detection.
#
# Features:
#   - Auto-detects bitcoin-cli if BITCOIN_CLI is not set
#   - Validates RPC JSON responses and logs errors
#   - Collects getnetworkinfo, getpeerinfo, getblockchaininfo, getmempoolinfo, getchaintips
#   - Heuristic checks: inbound peer counts, peer spikes, time drift, stale peers,
#     suspicious subversions, peer concentration, chain tip divergence, debug.log errors
#   - Clean dashboard with top peers by ping
#   - Writes alerts to a logfile and optionally to syslog via logger
#   - Keeps state in /tmp to detect spikes across runs
#   - Graceful shutdown (Ctrl+C) and cursor restore
#
# Requirements: bash, jq, bitcoin-cli (or set BITCOIN_CLI to your path)
#
# Usage:
#   chmod +x bitcoin_node_security_monitor.sh
#   ./bitcoin_node_security_monitor.sh
#

set -o errexit
set -o pipefail
set -o nounset

# ---------------------------
# Configuration
# ---------------------------
BITCOIN_CLI="${BITCOIN_CLI:-/snap/bin/bitcoin-core.cli}"  # override or leave unset to auto-detect
LOGFILE="${HOME}/bitcoin_node_monitor.log"
UPDATE_INTERVAL=20                # seconds between updates

# Alert thresholds
ALERT_SYSLOG=true
PEER_SPIKE_THRESHOLD=15
HIGH_INBOUND_THRESHOLD=50
RPC_ERROR_ALERT_THRESHOLD=5
CONCENTRATION_THRESHOLD=40        # percentage
TIME_DRIFT_THRESHOLD=300          # seconds (5 minutes)
STALE_PEER_THRESHOLD=6            # blocks behind
CHAIN_TIP_DIVERGENCE_THRESHOLD=3

SUSPICIOUS_USERAGENTS="masscan|nmap|zmap|nikto|scan|masscan/|nmap/"  # regex, case-insensitive

# State files
PEER_COUNT_FILE="/tmp/bitcoin_peer_count.prev"

# Colors
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_WHITE='\033[1;37m'
C_GRAY='\033[0;90m'

# Globals
declare -A data
declare -a alerts
TIMESTAMP=""

# ---------------------------
# Helpers
# ---------------------------
log_msg() {
    local level="$1"; shift
    local msg="$*"
    TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$TIMESTAMP] [$level] $msg" >> "$LOGFILE"
}

alert() {
    local msg="$1"
    alerts+=("$msg")
    log_msg "ALERT" "$msg"
    if [[ "$ALERT_SYSLOG" == "true" && "$(command -v logger >/dev/null 2>&1; echo $?)" -eq 0 ]]; then
        logger -t bitcoin-monitor "ALERT: $msg"
    fi
}

abs() {
    local v=$1
    if (( v < 0 )); then echo $(( -v )); else echo "$v"; fi
}

safe_jq_field() {
    local json="$1" filter="$2" default="${3:-}"
    echo "$json" | jq -r "$filter" 2>/dev/null || echo "$default"
}

# ---------------------------
# Initialization
# ---------------------------
initialize() {
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${C_RED}Error: 'jq' is required. Install jq and re-run.${C_RESET}" >&2
        exit 1
    fi

    if [[ -z "${BITCOIN_CLI:-}" || ! -x "$BITCOIN_CLI" ]]; then
        if command -v bitcoin-cli >/dev/null 2>&1; then
            BITCOIN_CLI="$(command -v bitcoin-cli)"
        else
            echo -e "${C_RED}Error: bitcoin-cli not found. Set BITCOIN_CLI to your client path.${C_RESET}" >&2
            exit 1
        fi
    fi

    trap cleanup INT TERM
    stty -echo 2>/dev/null || true
    clear
    echo -e "${C_BLUE}Initializing Bitcoin Node Monitor...${C_RESET}"
    echo -e "CLI: ${C_YELLOW}${BITCOIN_CLI}${C_RESET}  |  Log: ${C_YELLOW}${LOGFILE}${C_RESET}  |  Interval: ${C_YELLOW}${UPDATE_INTERVAL}s${C_RESET}"
    sleep 1
}

cleanup() {
    echo -e "${C_RESET}\nStopped. Logs: ${LOGFILE}"
    stty echo 2>/dev/null || true
    exit 0
}

# ---------------------------
# Fetch RPC data
# ---------------------------
fetch_and_process_data() {
    alerts=()

    local netinfo_raw blockinfo_raw mempool_raw peerinfo_raw chaintips_raw

    netinfo_raw="$("$BITCOIN_CLI" getnetworkinfo 2>&1)"   || { alert "getnetworkinfo RPC failed: ${netinfo_raw}";   return 1; }
    blockinfo_raw="$("$BITCOIN_CLI" getblockchaininfo 2>&1)" || { alert "getblockchaininfo RPC failed: ${blockinfo_raw}"; return 1; }
    mempool_raw="$("$BITCOIN_CLI" getmempoolinfo 2>&1)"   || { alert "getmempoolinfo RPC failed: ${mempool_raw}";   return 1; }
    peerinfo_raw="$("$BITCOIN_CLI" getpeerinfo 2>&1)"     || { alert "getpeerinfo RPC failed: ${peerinfo_raw}";     return 1; }
    chaintips_raw="$("$BITCOIN_CLI" getchaintips 2>&1)"   || { alert "getchaintips RPC failed: ${chaintips_raw}";   return 1; }

    if ! echo "$netinfo_raw"  | jq -e . >/dev/null 2>&1; then alert "getnetworkinfo returned invalid JSON";  return 1; fi
    if ! echo "$peerinfo_raw" | jq -e . >/dev/null 2>&1; then alert "getpeerinfo returned invalid JSON";     return 1; fi

    data[version]=$(safe_jq_field "$netinfo_raw" '.subversion // "n/a"' "n/a")
    data[protocol]=$(safe_jq_field "$netinfo_raw" '.protocolversion // 0' "0")
    data[services]=$(safe_jq_field "$netinfo_raw" '.localservicesnames // [] | join(", ")' "")
    data[network_active]=$(safe_jq_field "$netinfo_raw" '.networkactive // false' "false")
    data[connections]=$(safe_jq_field "$netinfo_raw" '.connections // 0' "0")
    data[relay_fee]=$(safe_jq_field "$netinfo_raw" '.relayfee // 0' "0")
    data[networks]=$(safe_jq_field "$netinfo_raw" '.networks | map(.name) | join(", ")' "")

    data[chain]=$(safe_jq_field "$blockinfo_raw" '.chain // "n/a"' "n/a")
    data[blocks]=$(safe_jq_field "$blockinfo_raw" '.blocks // 0' "0")
    data[headers]=$(safe_jq_field "$blockinfo_raw" '.headers // 0' "0")
    data[median_time]=$(safe_jq_field "$blockinfo_raw" '.mediantime // 0' "0")
    data[verification_progress]=$(safe_jq_field "$blockinfo_raw" '.verificationprogress // 0' "0")
    data[tip_count]=$(echo "$chaintips_raw" | jq -r 'length // 0' 2>/dev/null || echo 0)

    data[mempool_size]=$(safe_jq_field "$mempool_raw" '.size // 0' "0")
    data[mempool_bytes]=$(safe_jq_field "$mempool_raw" '.bytes // 0' "0")

    data[inbound]=$(echo "$peerinfo_raw" | jq -r '[.[] | select(.inbound==true)] | length')
    data[outbound]=$(echo "$peerinfo_raw" | jq -r '[.[] | select(.inbound==false)] | length')
    data[peer_count]=$(echo "$peerinfo_raw" | jq -r 'length')
    data[all_peers_info]="$peerinfo_raw"

    log_msg "INFO" "peers=${data[peer_count]} blocks=${data[blocks]} headers=${data[headers]}"
}

# ---------------------------
# Security & health checks
# ---------------------------
run_security_and_health_checks() {
    # 1. High inbound peers
    if (( data[inbound] > HIGH_INBOUND_THRESHOLD )); then
        alert "High inbound peers: ${data[inbound]} (threshold ${HIGH_INBOUND_THRESHOLD})"
    fi

    # 2. Peer spike detection
    local prev_peers; prev_peers=$(cat "$PEER_COUNT_FILE" 2>/dev/null || echo 0)
    local diff=$(( data[connections] - prev_peers ))
    if (( prev_peers != 0 && diff >= PEER_SPIKE_THRESHOLD )); then
        alert "Peer spike: +${diff} peers (${prev_peers} -> ${data[connections]})"
    fi
    echo "${data[connections]}" > "$PEER_COUNT_FILE"

    # 3. Time drift
    local sys_time; sys_time=$(date +%s)
    local atime; atime=$(abs $(( sys_time - data[median_time] )))
    if (( atime > TIME_DRIFT_THRESHOLD )); then
        alert "Time drift: ${atime}s difference (> ${TIME_DRIFT_THRESHOLD}s)"
    fi

    # 4. Chain tip divergence
    if (( data[tip_count] > CHAIN_TIP_DIVERGENCE_THRESHOLD )); then
        alert "Chain tip divergence: ${data[tip_count]} tips (possible network split)"
    fi

    # 5. Suspicious user agents
    local suspicious_agents
    suspicious_agents=$(echo "${data[all_peers_info]}" | jq -r --arg p "$SUSPICIOUS_USERAGENTS" '
        [.[] | select((.subver//"") | test($p;"i")) | .subver] | unique | join(", ")
    ' 2>/dev/null || echo "")
    [[ -n "$suspicious_agents" ]] && alert "Suspicious peer subversions: ${suspicious_agents}"

    # 6. Stale peers
    local stale_count
    stale_count=$(echo "${data[all_peers_info]}" | jq -r --argjson h "${data[blocks]}" --argjson t "$STALE_PEER_THRESHOLD" '
        [.[] | select(((.synced_blocks//.startingheight//0)) as $b | ($h-$b) > $t)] | length
    ' 2>/dev/null || echo 0)
    (( stale_count > 0 )) && alert "${stale_count} stale peer(s) detected (behind > ${STALE_PEER_THRESHOLD} blocks)"

    # 7. Peer concentration by /16 prefix
    local top_count
    top_count=$(echo "${data[all_peers_info]}" | jq -r '
        [.[] | select(.addr|test(":")|not) | .addr | split(":")[0] | split(".")[0:2] | join(".")] |
        group_by(.) | map({p:.[0],c:length}) | sort_by(.c) | reverse | .[0]//{p:"",c:0} | .c
    ' 2>/dev/null || echo 0)
    if (( top_count > 0 )); then
        local pct=$(( top_count * 100 / ( data[peer_count] > 0 ? data[peer_count] : 1 ) ))
        if (( pct >= CONCENTRATION_THRESHOLD )); then
            local prefix
            prefix=$(echo "${data[all_peers_info]}" | jq -r '
                [.[] | select(.addr|test(":")|not) | .addr | split(":")[0] | split(".")[0:2] | join(".")] |
                group_by(.) | map({p:.[0],c:length}) | sort_by(.c) | reverse | .[0] | .p
            ' 2>/dev/null || echo "unknown")
            alert "Peer concentration: ${top_count} peers (~${pct}%) from ${prefix}.0.0/16"
        fi
    fi

    # 8. debug.log error count
    local errcount=0
    for p in "/var/log/bitcoin/debug.log" "${HOME}/.bitcoin/debug.log" "/home/bitcoin/.bitcoin/debug.log"; do
        if [[ -f "$p" ]]; then
            errcount=$(tail -n 200 "$p" 2>/dev/null | grep -ic "error" || echo 0)
            break
        fi
    done
    (( errcount > RPC_ERROR_ALERT_THRESHOLD )) && alert "High error count in debug.log: ${errcount} (threshold ${RPC_ERROR_ALERT_THRESHOLD})"
}

# ---------------------------
# Dashboard display
# ---------------------------
display_dashboard() {
    TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

    local sync_percent="100.00"
    (( data[headers] > 0 )) && sync_percent=$(awk "BEGIN{printf \"%.2f\",(${data[blocks]}/${data[headers]})*100}")

    local sync_status sync_color
    if (( $(echo "$sync_percent < 99.9" | bc -l) )); then
        sync_status="Syncing ${sync_percent}%"; sync_color="$C_YELLOW"
    else
        sync_status="Synced"; sync_color="$C_GREEN"
    fi

    local net_color; [[ "${data[network_active]}" == "true" ]] && net_color="$C_GREEN" || net_color="$C_RED"

    clear
    echo -e "${C_WHITE}=== Bitcoin Node Security Monitor ===${C_RESET}"
    echo -e "Updated: ${C_GRAY}${TIMESTAMP}${C_RESET}   Next refresh: ${C_YELLOW}${UPDATE_INTERVAL}s${C_RESET}"
    echo
    printf "Node:     %-40s  Chain:    %-15s\n"  "${data[version]}"  "${data[chain]}"
    printf "Protocol: %-6s   Services: %-30s\n"  "${data[protocol]}" "${data[services]}"
    printf "Network:  %s%-6s%s   Connections: %s%d%s (In:%d Out:%d)\n" \
        "$net_color" "${data[network_active]}" "$C_RESET" \
        "$C_YELLOW" "${data[connections]}" "$C_RESET" \
        "${data[inbound]}" "${data[outbound]}"
    printf "Blocks:   %s/%s  %s%s%s   Progress: %s\n" \
        "${data[blocks]}" "${data[headers]}" \
        "$sync_color" "$sync_status" "$C_RESET" \
        "${data[verification_progress]}"
    printf "Mempool:  %s txs / %s bytes   Relay fee: %s\n" \
        "${data[mempool_size]}" "${data[mempool_bytes]}" "${data[relay_fee]}"
    echo

    echo -e "${C_WHITE}Alerts (${#alerts[@]}):${C_RESET}"
    if [[ ${#alerts[@]} -eq 0 ]]; then
        echo -e "  ${C_GREEN}System nominal. No alerts.${C_RESET}"
    else
        for a in "${alerts[@]}"; do
            echo -e "  ${C_YELLOW}* ${a}${C_RESET}"
        done
    fi
    echo

    echo -e "${C_WHITE}Top 5 peers by ping:${C_RESET}"
    echo "${data[all_peers_info]}" | jq -r '
        sort_by((.pingtime//.minping//9999)) | .[0:5][] |
        "  " + (.id|tostring) + " | " + (.addr//"?") + " | Ping:" +
        ((.pingtime//.minping//0)|tostring) + "s | In:" + (.inbound|tostring) +
        " | " + (.subver//"n/a")
    ' 2>/dev/null || echo "  (unable to parse peers)"

    echo
    echo -e "${C_GRAY}Log: ${LOGFILE}${C_RESET}"
}

# ---------------------------
# Main loop
# ---------------------------
main_loop() {
    while true; do
        if fetch_and_process_data; then
            run_security_and_health_checks
            display_dashboard
        else
            echo -e "${C_RED}RPC fetch failed. Retrying in 5s...${C_RESET}"
            sleep 5
            continue
        fi
        sleep "$UPDATE_INTERVAL"
    done
}

initialize
main_loop
