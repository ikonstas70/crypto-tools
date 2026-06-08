#!/bin/bash

# Define block heights for the 5 phases to fetch block hashes
BLOCK_HEIGHTS=(1 209999 210000 419999 420000 629999 630000 839999 840000 1049999)

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
WHITE='\033[1;37m'  # White for transaction amount
NC='\033[0m'  # No Color

# Loop over each block height and fetch the corresponding block hash
for ((i=0; i<${#BLOCK_HEIGHTS[@]}-1; i+=2)); do
    # Determine the phase range dynamically
    PHASE_START=${BLOCK_HEIGHTS[$i]}
    PHASE_END=${BLOCK_HEIGHTS[$((i+1))]}
    
    # Output the phase level with red color
    echo -e "${RED}Phase $(($i/2+1)): Block Heights $PHASE_START to $PHASE_END${NC}"
    
    # Fetch the block hash for the starting block of this phase
    echo "Fetching block hash for the start of the phase (block height $PHASE_START)"
    START_BLOCK_HASH=$(bitcoin-core.cli getblockhash "$PHASE_START" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        # Fetch block data for the start block to get the transaction value and timestamp
        START_BLOCK_DATA=$(bitcoin-core.cli getblock "$START_BLOCK_HASH" 2)
        START_BLOCK_VALUE=$(echo "$START_BLOCK_DATA" | jq -r '.tx[0].vout[0].value')
        START_BLOCK_TIMESTAMP=$(echo "$START_BLOCK_DATA" | jq -r '.time')
        START_BLOCK_DATE=$(date -d @$START_BLOCK_TIMESTAMP '+%Y-%m-%d %H:%M:%S')

        echo "Block hash at height $PHASE_START: $START_BLOCK_HASH"
        echo -e "Transaction Value at height $PHASE_START: ${WHITE}$START_BLOCK_VALUE${NC}"
        echo "Block Creation Date at height $PHASE_START: $START_BLOCK_DATE"
    else
        echo "Error: Block height $PHASE_START is out of range or not available."
    fi

    # Fetch the block hash for the ending block of this phase
    echo "Fetching block hash for the end of the phase (block height $PHASE_END)"
    END_BLOCK_HASH=$(bitcoin-core.cli getblockhash "$PHASE_END" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        # Fetch block data for the end block to get the transaction value and timestamp
        END_BLOCK_DATA=$(bitcoin-core.cli getblock "$END_BLOCK_HASH" 2)
        END_BLOCK_VALUE=$(echo "$END_BLOCK_DATA" | jq -r '.tx[0].vout[0].value')
        END_BLOCK_TIMESTAMP=$(echo "$END_BLOCK_DATA" | jq -r '.time')
        END_BLOCK_DATE=$(date -d @$END_BLOCK_TIMESTAMP '+%Y-%m-%d %H:%M:%S')

        echo "Block hash at height $PHASE_END: $END_BLOCK_HASH"
        echo -e "Transaction Value at height $PHASE_END: ${WHITE}$END_BLOCK_VALUE${NC}"
        echo "Block Creation Date at height $PHASE_END: $END_BLOCK_DATE"
    else
        echo "Error: Block height $PHASE_END is out of range or not available."
    fi
    
    # Optional: sleep for 1 second to avoid overwhelming the server
    sleep 1
done

# Special Phase 5: Add additional block heights (850000, 860000, 870000, 880000)
echo -e "${RED}Phase 5: Block Heights 850000 to 880000${NC}"

# Loop over additional block heights for Phase 5
SPECIAL_BLOCKS=(850000 860000 870000 880000)
for BLOCK_HEIGHT in "${SPECIAL_BLOCKS[@]}"; do
    echo "Fetching block hash for block height $BLOCK_HEIGHT"
    BLOCK_HASH=$(bitcoin-core.cli getblockhash "$BLOCK_HEIGHT" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        # Fetch block data for this block to get the transaction value and timestamp
        BLOCK_DATA=$(bitcoin-core.cli getblock "$BLOCK_HASH" 2)
        BLOCK_VALUE=$(echo "$BLOCK_DATA" | jq -r '.tx[0].vout[0].value')
        BLOCK_TIMESTAMP=$(echo "$BLOCK_DATA" | jq -r '.time')
        BLOCK_DATE=$(date -d @$BLOCK_TIMESTAMP '+%Y-%m-%d %H:%M:%S')

        echo "Block hash at height $BLOCK_HEIGHT: $BLOCK_HASH"
        echo -e "Transaction Value at height $BLOCK_HEIGHT: ${WHITE}$BLOCK_VALUE${NC}"
        echo "Block Creation Date at height $BLOCK_HEIGHT: $BLOCK_DATE"
    else
        echo "Error: Block height $BLOCK_HEIGHT is out of range or not available."
    fi
    
    # Optional: sleep for 1 second to avoid overwhelming the server
    sleep 1
done

echo -e "${GREEN}Finished fetching block hashes and transaction values for the phases.${NC}"
