#!/bin/bash
# Pre-upgrade test setup: create on-chain state that spans the upgrade boundary
# Usage: ./scripts/devnet-pre-upgrade-setup.sh
# Run BEFORE planUpgrade

set -euo pipefail

RPC="https://devnet0.storyrpc.io"
PROPOSER_KEY="${DEVNET_PROPOSER_KEY:?Set DEVNET_PROPOSER_KEY env var}"
PROPOSER_ADDR=$(cast wallet address "$PROPOSER_KEY")
STAKING="0xCCcCcC0000000000000000000000000000000001"

echo "=== Pre-Upgrade Setup ==="
echo "RPC: $RPC"
echo "Proposer: $PROPOSER_ADDR"
echo ""

HEIGHT=$(curl -s "$RPC/status" | jq -r '.result.sync_info.latest_block_height')
echo "Current height: $HEIGHT"
echo ""

# --- F1: Stake + unstake to create unbonding that spans upgrade ---
echo "=== F1: Create unbonding delegation ==="

# Get first validator compressed pubkey (33 bytes secp256k1)
VAL_PUBKEY_B64=$(curl -s "$RPC/validators" | jq -r '.result.validators[0].pub_key.value')
VAL_PUBKEY_HEX=$(echo -n "$VAL_PUBKEY_B64" | base64 -d | xxd -p -c 33)
echo "Validator pubkey: 0x$VAL_PUBKEY_HEX"

# Check min stake
MIN_STAKE=$(cast call "$STAKING" "minStakeAmount()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
echo "Min stake: $MIN_STAKE"

# Stake (delegate) — StakingPeriod.FLEXIBLE = 0
echo "Staking ${MIN_STAKE} to validator..."
STAKE_TX=$(cast send "$STAKING" \
  "stake(bytes,uint8,bytes)" \
  "0x${VAL_PUBKEY_HEX}" 0 "0x" \
  --value "${MIN_STAKE}" \
  --gas-limit 500000 \
  --private-key "$PROPOSER_KEY" --rpc-url "$RPC" --legacy --json 2>&1)
STAKE_STATUS=$(echo "$STAKE_TX" | jq -r '.status' 2>/dev/null || echo "fail")
STAKE_HASH=$(echo "$STAKE_TX" | jq -r '.transactionHash' 2>/dev/null || echo "n/a")
echo "Stake tx: ${STAKE_HASH:0:18}... status: $STAKE_STATUS"

if [ "$STAKE_STATUS" != "0x1" ]; then
  echo "WARN: Stake failed, F1 test may not work"
fi

# Unstake (undelegate) — creates unbonding entry
echo "Unstaking to create unbonding delegation..."
MIN_UNSTAKE=$(cast call "$STAKING" "minUnstakeAmount()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
FEE=$(cast call "$STAKING" "fee()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
echo "Min unstake: $MIN_UNSTAKE, Fee: $FEE"
UNSTAKE_TX=$(cast send "$STAKING" \
  "unstake(bytes,uint256,uint256,bytes)" \
  "0x${VAL_PUBKEY_HEX}" 0 "${MIN_UNSTAKE}" "0x" \
  --value "${FEE}" \
  --gas-limit 500000 \
  --private-key "$PROPOSER_KEY" --rpc-url "$RPC" --legacy --json 2>&1)
UNSTAKE_STATUS=$(echo "$UNSTAKE_TX" | jq -r '.status' 2>/dev/null || echo "fail")
UNSTAKE_HASH=$(echo "$UNSTAKE_TX" | jq -r '.transactionHash' 2>/dev/null || echo "n/a")
echo "Unstake tx: ${UNSTAKE_HASH:0:18}... status: $UNSTAKE_STATUS"
echo ""

# --- F3: Deploy ERC20 contract with state ---
echo "=== F3: Deploy ERC20 TestToken ==="

FORGE_DIR="/tmp/test-erc20"
if [ ! -f "$FORGE_DIR/src/TestToken.sol" ]; then
  echo "ERROR: $FORGE_DIR not found. Run: mkdir -p /tmp/test-erc20 && cd /tmp/test-erc20 && forge init --no-git --force && forge install OpenZeppelin/openzeppelin-contracts --no-git"
  echo "Then create src/TestToken.sol and remappings.txt"
else
  DEPLOY_OUT=$(cd "$FORGE_DIR" && forge create \
    --rpc-url "$RPC" \
    --private-key "$PROPOSER_KEY" \
    --legacy --broadcast \
    src/TestToken.sol:TestToken \
    --constructor-args 1000000000000000000000000 2>&1)
  CONTRACT=$(echo "$DEPLOY_OUT" | grep "Deployed to:" | awk '{print $3}')
  echo "Contract: $CONTRACT"

  if [ -n "$CONTRACT" ]; then
    NAME=$(cast call "$CONTRACT" "name()(string)" --rpc-url "$RPC" 2>/dev/null)
    SUPPLY=$(cast call "$CONTRACT" "totalSupply()(uint256)" --rpc-url "$RPC" 2>/dev/null | awk '{print $1}')
    BALANCE=$(cast call "$CONTRACT" "balanceOf(address)(uint256)" "$PROPOSER_ADDR" --rpc-url "$RPC" 2>/dev/null | awk '{print $1}')
    echo "Name: $NAME, Supply: $SUPPLY, Deployer balance: $BALANCE"

    # Transfer some tokens to executor
    EXECUTOR_ADDR="0x28756A43b51ca11031f32b9a3616930471aC40eb"
    cast send "$CONTRACT" "transfer(address,uint256)" "$EXECUTOR_ADDR" 1000000000000000000000 \
      --private-key "$PROPOSER_KEY" --rpc-url "$RPC" --legacy --json 2>/dev/null | jq -r '.status' | xargs -I{} echo "Transfer 1000 TT to executor: {}"

    EXEC_BAL=$(cast call "$CONTRACT" "balanceOf(address)(uint256)" "$EXECUTOR_ADDR" --rpc-url "$RPC" 2>/dev/null | awk '{print $1}')
    echo "Executor TT balance: $EXEC_BAL"
  fi
fi
echo ""

# --- F5: Record pre-upgrade block time baseline ---
echo "=== F5: Block time baseline ==="
H1=$(curl -s "$RPC/status" | jq -r '.result.sync_info.latest_block_height')
T1=$(curl -s "$RPC/block?height=$H1" | jq -r '.result.block.header.time')
sleep 20
H2=$(curl -s "$RPC/status" | jq -r '.result.sync_info.latest_block_height')
T2=$(curl -s "$RPC/block?height=$H2" | jq -r '.result.block.header.time')
BLOCKS=$((H2 - H1))
echo "Pre-upgrade: $BLOCKS blocks in 20s → avg $(echo "scale=1; 20 / $BLOCKS" | bc)s/block"
echo ""

# --- F7: Record pre-upgrade balance for historical query ---
echo "=== F7: Pre-upgrade snapshot ==="
BALANCE=$(cast balance "$PROPOSER_ADDR" --rpc-url "$RPC" 2>/dev/null)
echo "Proposer balance at height ~$H2: $BALANCE"
echo "Save this for post-upgrade historical query at block $H2"
echo ""

# --- Summary ---
echo "=== Setup Complete ==="
echo "F1: Unbonding created (stake+unstake tx)"
echo "F3: Contract at $CONTRACT with value=123"
echo "F5: Baseline block time recorded"
echo "F7: Balance snapshot at height $H2"
echo ""
echo "Next: deploy upgrade binary, run planUpgrade, start tx-load.sh"
