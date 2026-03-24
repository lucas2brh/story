#!/bin/bash
# Post-upgrade verification: check state that was set up before upgrade
# Usage: ./scripts/devnet-post-upgrade-verify.sh <contract_addr> <pre_upgrade_height> <pre_upgrade_balance>

set -euo pipefail

RPC="https://devnet0.storyrpc.io"
PROPOSER_KEY="${DEVNET_PROPOSER_KEY:?Set DEVNET_PROPOSER_KEY env var}"
PROPOSER_ADDR=$(cast wallet address "$PROPOSER_KEY")

CONTRACT="${1:?Usage: $0 <contract_addr> <pre_upgrade_height> <pre_upgrade_balance>}"
PRE_HEIGHT="${2:?}"
PRE_BALANCE="${3:?}"

echo "=== Post-Upgrade Verification ==="
echo ""

HEIGHT=$(curl -s "$RPC/status" | jq -r '.result.sync_info.latest_block_height')
echo "Current height: $HEIGHT"
echo ""

PASS=0
FAIL=0

check() {
  if [ "$1" = "PASS" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
  echo "  $1  $2"
}

# --- F1: Unbonding delegation ---
echo "=== F1: Unbonding delegation ==="
echo "  (Check manually via staking queries if unbonding matured correctly)"
echo "  Skipping automated check — unbonding period likely longer than test window"
echo ""

# --- F2: tx-load results ---
echo "=== F2: TX continuity ==="
echo "  Check tx-load.sh output for fail count"
echo ""

# --- F3: ERC20 contract state survival ---
echo "=== F3: ERC20 state ==="
NAME=$(cast call "$CONTRACT" "name()(string)" --rpc-url "$RPC" 2>/dev/null | tr -d '"' || echo "fail")
SUPPLY=$(cast call "$CONTRACT" "totalSupply()(uint256)" --rpc-url "$RPC" 2>/dev/null | awk '{print $1}')
EXEC_BAL=$(cast call "$CONTRACT" "balanceOf(address)(uint256)" "0x28756A43b51ca11031f32b9a3616930471aC40eb" --rpc-url "$RPC" 2>/dev/null | awk '{print $1}')
if [ "$NAME" = "TestToken" ]; then
  check "PASS" "ERC20 name=$NAME"
else
  check "FAIL" "ERC20 name=$NAME (expected TestToken)"
fi
if [ "$SUPPLY" = "1000000000000000000000000" ]; then
  check "PASS" "ERC20 totalSupply intact"
else
  check "FAIL" "ERC20 totalSupply=$SUPPLY"
fi
if [ "$EXEC_BAL" = "1000000000000000000000" ]; then
  check "PASS" "Executor TT balance intact"
else
  check "FAIL" "Executor TT balance=$EXEC_BAL (expected 1000000000000000000000)"
fi
echo ""

# --- F5: Block time comparison ---
echo "=== F5: Block time ==="
H1=$(curl -s "$RPC/status" | jq -r '.result.sync_info.latest_block_height')
sleep 20
H2=$(curl -s "$RPC/status" | jq -r '.result.sync_info.latest_block_height')
BLOCKS=$((H2 - H1))
AVG=$(echo "scale=1; 20 / $BLOCKS" | bc)
echo "  Post-upgrade: $BLOCKS blocks in 20s → avg ${AVG}s/block"
if [ "$BLOCKS" -ge 5 ]; then
  check "PASS" "Block production normal (${BLOCKS} blocks/20s)"
else
  check "FAIL" "Block production slow (${BLOCKS} blocks/20s)"
fi
echo ""

# --- F7: Historical RPC query ---
echo "=== F7: Historical query ==="
HEX_HEIGHT=$(printf '0x%x' "$PRE_HEIGHT")
HIST_BALANCE=$(cast balance "$PROPOSER_ADDR" --rpc-url "$RPC" --block "$HEX_HEIGHT" 2>/dev/null || echo "fail")
if [ "$HIST_BALANCE" = "$PRE_BALANCE" ]; then
  check "PASS" "Historical balance at $PRE_HEIGHT matches"
else
  check "FAIL" "Historical balance mismatch: got $HIST_BALANCE expected $PRE_BALANCE"
fi
echo ""

# --- Smoke test ---
echo "=== Smoke test ==="
TX_STATUS=$(cast send "$PROPOSER_ADDR" --value 0.001ether --private-key "$PROPOSER_KEY" --rpc-url "$RPC" --legacy --json 2>/dev/null | jq -r '.status' 2>/dev/null || echo "fail")
if [ "$TX_STATUS" = "0x1" ]; then
  check "PASS" "Transfer tx"
else
  check "FAIL" "Transfer tx status=$TX_STATUS"
fi

CALL=$(cast call "0xCCcCcC0000000000000000000000000000000001" "minStakeAmount()(uint256)" --rpc-url "$RPC" 2>/dev/null && echo "ok" || echo "fail")
if [ "$CALL" = "fail" ]; then
  check "FAIL" "Contract call"
else
  check "PASS" "Contract call"
fi
echo ""

echo "=== Results: $PASS passed, $FAIL failed ==="
