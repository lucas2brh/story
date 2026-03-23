#!/bin/bash
# Continuous tx load generator for devnet testing
# Sends transfer + contract call every N seconds
# Usage: ./scripts/devnet-tx-load.sh [interval_seconds]
# Stop: Ctrl+C or kill

set -euo pipefail

RPC="https://devnet0.storyrpc.io"
INTERVAL="${1:-3}"
PROPOSER_KEY="${DEVNET_PROPOSER_KEY:?Set DEVNET_PROPOSER_KEY env var}"
EXECUTOR_ADDR="0x28756A43b51ca11031f32b9a3616930471aC40eb"
STAKING="0xCCcCcC0000000000000000000000000000000001"

TX_COUNT=0
FAIL_COUNT=0
START_TIME=$(date +%s)

cleanup() {
  ELAPSED=$(( $(date +%s) - START_TIME ))
  echo ""
  echo "=== TX Load Summary ==="
  echo "Duration: ${ELAPSED}s"
  echo "Total: $TX_COUNT tx sent, $FAIL_COUNT failed"
  echo "Rate: $(echo "scale=1; $TX_COUNT / $ELAPSED" | bc 2>/dev/null || echo "n/a") tx/s"
  exit 0
}
trap cleanup INT TERM

echo "=== TX Load Generator ==="
echo "RPC: $RPC"
echo "Interval: ${INTERVAL}s"
echo "Press Ctrl+C to stop"
echo ""

while true; do
  HEIGHT=$(curl -s "$RPC/status" 2>/dev/null | jq -r '.result.sync_info.latest_block_height' 2>/dev/null || echo "?")

  # Transfer
  TX_STATUS=$(cast send "$EXECUTOR_ADDR" --value 0.001ether \
    --private-key "$PROPOSER_KEY" --rpc-url "$RPC" --legacy --json 2>/dev/null \
    | jq -r '.status' 2>/dev/null || echo "fail")

  if [ "$TX_STATUS" = "0x1" ]; then
    TX_COUNT=$((TX_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  # Contract read
  CALL_RESULT=$(cast call "$STAKING" "minStakeAmount()(uint256)" --rpc-url "$RPC" 2>/dev/null && echo "ok" || echo "fail")

  echo "$(date +%H:%M:%S) h=$HEIGHT tx=$TX_COUNT fail=$FAIL_COUNT transfer=$TX_STATUS call=${CALL_RESULT##*$'\n'}"

  sleep "$INTERVAL"
done
