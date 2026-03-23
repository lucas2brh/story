#!/bin/bash
# Post-upgrade smoke test for devnet
# Verifies EVM layer works: token transfer + contract interaction
# Usage: ./scripts/devnet-smoke-test.sh

set -euo pipefail

RPC="https://devnet0.storyrpc.io"

PROPOSER_KEY="${DEVNET_PROPOSER_KEY:?Set DEVNET_PROPOSER_KEY env var}"
EXECUTOR_ADDR="0x28756A43b51ca11031f32b9a3616930471aC40eb"

echo "=== Devnet Smoke Test ==="
echo ""

echo "1. Token transfer (0.01 IP)..."
TX=$(cast send "$EXECUTOR_ADDR" --value 0.01ether \
  --private-key "$PROPOSER_KEY" --rpc-url "$RPC" --legacy --json)

STATUS=$(echo "$TX" | jq -r '.status')
HASH=$(echo "$TX" | jq -r '.transactionHash')
if [ "$STATUS" = "0x1" ]; then
  echo "   PASS  tx: ${HASH:0:18}..."
else
  echo "   FAIL  tx: $HASH status: $STATUS"; exit 1
fi

echo "2. Contract call (StakingContract.minStakeAmount)..."
STAKING="0xCCcCcC0000000000000000000000000000000001"
RESULT=$(cast call "$STAKING" "minStakeAmount()(uint256)" --rpc-url "$RPC" 2>&1)
if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
  echo "   PASS  minStakeAmount=$RESULT"
else
  echo "   FAIL  contract call failed: $RESULT"; exit 1
fi

echo "3. Chain producing blocks..."
H1=$(curl -s "$RPC/status" | jq -r '.result.sync_info.latest_block_height')
sleep 3
H2=$(curl -s "$RPC/status" | jq -r '.result.sync_info.latest_block_height')
if [ "$H2" -gt "$H1" ]; then
  echo "   PASS  height $H1 -> $H2"
else
  echo "   FAIL  chain stalled at $H1"; exit 1
fi

echo ""
echo "=== All checks passed ==="
