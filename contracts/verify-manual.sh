#!/bin/bash
# Manual verification script for IPTokenStaking contract
# Usage: ./verify-manual.sh

CONTRACT_ADDRESS="0xd91113d0d8f26d85e264a9e3405a787a1abd1e7a"
VERIFIER_URL="${VERIFIER_URL:-https://devnet.storyscan.xyz/api}"
CHAIN_ID=1512

echo "Verifying contract at $CONTRACT_ADDRESS..."

forge verify-contract \
  $CONTRACT_ADDRESS \
  src/protocol/IPTokenStaking.sol:IPTokenStaking \
  --verifier blockscout \
  --verifier-url $VERIFIER_URL \
  --chain-id $CHAIN_ID \
  --constructor-args $(cast abi-encode "constructor(uint256,uint256)" 1000000000000000000 256) \
  --libraries src/protocol/libraries/Secp256k1.sol:Secp256k1:0x00000000000000000000000000000000000256f1 \
  --compiler-version 0.8.23 \
  --num-of-optimizations 20000 \
  --watch

