#!/bin/bash
# TX load generator using forge script
# Deploys ERC20, creates 5 wallets, sends 200 tx (ETH + ERC20 transfers)
# Usage: DEVNET_PROPOSER_KEY="0x..." ./scripts/devnet-tx-load.sh [iterations]
#
# Prerequisites: forge project at /tmp/test-erc20 with TxLoad.s.sol
# Setup: see docs/v2_upgrade_test_plan.md

set -euo pipefail

RPC="https://devnet0.storyrpc.io"
PRIVATE_KEY="${DEVNET_PROPOSER_KEY:?Set DEVNET_PROPOSER_KEY env var}"
FORGE_DIR="/tmp/test-erc20"
ITERATIONS="${1:-100}"

if [ ! -f "$FORGE_DIR/script/TxLoad.s.sol" ]; then
  echo "ERROR: Forge project not found at $FORGE_DIR"
  echo "Setup:"
  echo "  mkdir -p /tmp/test-erc20 && cd /tmp/test-erc20"
  echo "  forge init --no-git --force"
  echo "  forge install OpenZeppelin/openzeppelin-contracts --no-git"
  echo "  echo '@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/' > remappings.txt"
  echo "  # Copy TestToken.sol to src/ and TxLoad.s.sol to script/"
  exit 1
fi

echo "=== TX Load Generator (forge script) ==="
echo "RPC: $RPC"
echo "Iterations: $ITERATIONS (x2 tx each = $((ITERATIONS * 2)) total)"
echo ""

cd "$FORGE_DIR"
PRIVATE_KEY="$PRIVATE_KEY" forge script script/TxLoad.s.sol:TxLoad \
  --rpc-url "$RPC" \
  --legacy --broadcast \
  -vv

echo ""
echo "TX receipts saved to: $FORGE_DIR/broadcast/"
