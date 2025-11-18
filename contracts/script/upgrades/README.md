# Stake Precompile Upgrades

This directory contains scripts for managing the staking precompile contract upgrades.

## DeployNewIPTokenStaking_V1_0_2

This script deploys a new implementation of IPTokenStaking contract to be used for upgrading. It only deploys the implementation contract, it does not perform the upgrade.

### Prerequisites for DeployNewIPTokenStaking_V1_0_2

- Set up your environment with the required variables:
  - `PRIVATE_KEY` or `DEPLOYER_PRIVATE_KEY`: The private key of the deployer account
  - `FORK_URL`: The RPC URL of the target network (optional if using internal-devnet target)

### Usage for DeployNewIPTokenStaking_V1_0_2

#### Using Makefile (Recommended)

**For internal-devnet (default verification enabled):**

```bash
# Using PRIVATE_KEY
make deploy-staking-impl-internal-devnet PRIVATE_KEY=your_private_key

# Using DEPLOYER_PRIVATE_KEY from .env file
make deploy-staking-impl-internal-devnet
```

**For custom network:**

```bash
make deploy-staking-impl FORK_URL=https://rpc.devnet.storyrpc.io PRIVATE_KEY=your_private_key
```

#### Using Forge Script Directly

**For internal-devnet:**

```bash
forge script script/upgrades/DeployNewIPTokenStaking_V1_0_2.s.sol \
  --fork-url https://rpc.devnet.storyrpc.io \
  --private-key <PRIVATE_KEY> \
  --verify \
  --verifier=blockscout \
  --verifier-url=https://devnet.storyscan.xyz/api \
  -vvvv \
  --priority-gas-price 1 \
  --legacy \
  --broadcast
```

### Internal-Devnet Network Info

- **Chain ID**: 1512
- **RPC endpoint**: `https://rpc.devnet.storyrpc.io`
- **WSS endpoint**: `wss://rpc.devnet.storyrpc.io/ws/`
- **Explorer**: `https://devnet.storyscan.xyz`
- **Verifier URL**: `https://devnet.storyscan.xyz/api`

### Script Details for DeployNewIPTokenStaking_V1_0_2

- **Deployment Method**: Uses Create3 for deterministic address deployment
- **Salt**: `keccak256("IPTokenStaking_Implementation_v1_0_2")`
- **Constructor Args**: `defaultMinFee = 1 ether`, `maxDataLength = 256`
- **Verification**: Enabled by default with Blockscout verifier

## StakePrecompileUpgrades

This script is used to manage the upgrade process for the staking precompile contract. It allows you to schedule and execute upgrades using a timelock controller and a proxy admin.

## Prerequisites

- Ensure you have the necessary private keys for the upgrade admin and executor.
- Set up your environment with the required variables.

## Environment Variables

- `UPGRADE_ADMIN_KEY`: The private key of the upgrade admin.
- `EXECUTOR_KEY`: The private key of the executor.
- `IS_EXECUTE`: A boolean flag to determine whether to schedule or execute the upgrade.

## Usage

### Scheduling an Upgrade

To schedule an upgrade, set the `IS_EXECUTE` environment variable to `false` and run the following command:

```bash
export IS_EXECUTE=false
forge script script/upgrades/StakePrecompileUpgrades.sol --rpc-url https://rpc.devnet.storyrpc.io -vvvv --priority-gas-price 1 --legacy --broadcast
```

### Executing an Upgrade

To execute an upgrade, set the `IS_EXECUTE` environment variable to `true` and run the following command:

```bash
export IS_EXECUTE=true
forge script script/upgrades/StakePrecompileUpgrades.sol --rpc-url https://rpc.devnet.storyrpc.io -vvvv --priority-gas-price 1 --legacy --broadcast
```

## Script Details

- **Timelock Controller**: Ensures that upgrades are scheduled with a minimum delay.
- **Proxy Admin**: Manages the upgrade process for the proxy contract.
- **New Implementation**: The address of the new implementation contract to upgrade to.

## Verification

After executing the upgrade, the script will verify:

- The minimum stake amount is set to `1024 ether`.
- The implementation address matches the new implementation address.

## Logging

The script uses `console2` for logging various steps in the upgrade process, including scheduling, execution, and verification.

## Linter Warnings

- The script contains console statements for logging, which may trigger linter warnings.
- Some lines exceed the maximum line length of 120 characters.
