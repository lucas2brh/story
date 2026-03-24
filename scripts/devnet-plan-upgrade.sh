#!/bin/bash
# planUpgrade via TimelockController for devnet v2.0.0 upgrade
# Usage: ./scripts/devnet-plan-upgrade.sh [upgrade_height]
#
# Flow: proposer schedules → wait delay (10s) → executor executes
# Result: UpgradeEntrypoint.planUpgrade("v2.0.0", H, "") is called

set -euo pipefail

# --- Config ---
RPC="https://devnet0.storyrpc.io"
UPGRADE_HEIGHT="${1:-200}"
UPGRADE_NAME="v2.0.0"
UPGRADE_INFO=""

TIMELOCK="0x4827c76bD61A223Ddd36D013c78F825eb0bb3Be3"
UPGRADE_ENTRYPOINT="0xccCCcc0000000000000000000000000000000003"

# Keys from l1-tests/.env.internal-devnet
PROPOSER_KEY="${DEVNET_PROPOSER_KEY:?Set DEVNET_PROPOSER_KEY env var}"
EXECUTOR_KEY="${DEVNET_EXECUTOR_KEY:?Set DEVNET_EXECUTOR_KEY env var}"

# TimelockController params
PREDECESSOR="0x0000000000000000000000000000000000000000000000000000000000000000"
SALT="0x0000000000000000000000000000000000000000000000000000000000000000"
MIN_DELAY=10  # devnet: 10 seconds

# --- Encode planUpgrade calldata ---
echo "=== planUpgrade via TimelockController ==="
echo "Upgrade: $UPGRADE_NAME at height $UPGRADE_HEIGHT"
echo ""

# planUpgrade(string name, int64 height, string info)
CALLDATA=$(cast calldata "planUpgrade(string,int64,string)" "$UPGRADE_NAME" "$UPGRADE_HEIGHT" "$UPGRADE_INFO")
echo "planUpgrade calldata: $CALLDATA"

# --- Check current block height ---
CURRENT_HEIGHT=$(curl -s "$RPC/status" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['sync_info']['latest_block_height'])")
echo "Current block height: $CURRENT_HEIGHT"

if [ "$CURRENT_HEIGHT" -ge "$UPGRADE_HEIGHT" ]; then
    echo "ERROR: Current height ($CURRENT_HEIGHT) >= upgrade height ($UPGRADE_HEIGHT). Upgrade height already passed."
    exit 1
fi

# --- Step 1: Schedule via proposer ---
echo ""
echo "Step 1: Scheduling upgrade (proposer)..."
SCHEDULE_TX=$(cast send "$TIMELOCK" \
    "schedule(address,uint256,bytes,bytes32,bytes32,uint256)" \
    "$UPGRADE_ENTRYPOINT" 0 "$CALLDATA" "$PREDECESSOR" "$SALT" "$MIN_DELAY" \
    --private-key "$PROPOSER_KEY" \
    --rpc-url "$RPC" \
    --legacy \
    --json)

SCHEDULE_HASH=$(echo "$SCHEDULE_TX" | python3 -c "import sys,json; print(json.load(sys.stdin)['transactionHash'])")
SCHEDULE_STATUS=$(echo "$SCHEDULE_TX" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")
echo "Schedule tx: $SCHEDULE_HASH (status: $SCHEDULE_STATUS)"

if [ "$SCHEDULE_STATUS" != "0x1" ]; then
    echo "ERROR: Schedule transaction failed"
    exit 1
fi

# --- Step 2: Wait for delay ---
echo ""
echo "Step 2: Waiting ${MIN_DELAY}s for timelock delay..."
sleep $((MIN_DELAY + 2))

# --- Step 3: Execute via executor ---
echo ""
echo "Step 3: Executing upgrade (executor)..."
EXECUTE_TX=$(cast send "$TIMELOCK" \
    "execute(address,uint256,bytes,bytes32,bytes32)" \
    "$UPGRADE_ENTRYPOINT" 0 "$CALLDATA" "$PREDECESSOR" "$SALT" \
    --private-key "$EXECUTOR_KEY" \
    --rpc-url "$RPC" \
    --legacy \
    --json)

EXECUTE_HASH=$(echo "$EXECUTE_TX" | python3 -c "import sys,json; print(json.load(sys.stdin)['transactionHash'])")
EXECUTE_STATUS=$(echo "$EXECUTE_TX" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")
echo "Execute tx: $EXECUTE_HASH (status: $EXECUTE_STATUS)"

if [ "$EXECUTE_STATUS" != "0x1" ]; then
    echo "ERROR: Execute transaction failed"
    exit 1
fi

# --- Verify ---
echo ""
echo "=== Verification ==="
echo "planUpgrade('$UPGRADE_NAME', $UPGRADE_HEIGHT) submitted successfully"
echo "Nodes running old binary will halt at height $UPGRADE_HEIGHT with: UPGRADE \"$UPGRADE_NAME\" NEEDED"
echo ""
echo "Check pending upgrade:"
echo "  curl -s $RPC/evmengine/pending_upgrade"
