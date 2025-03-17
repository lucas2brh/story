# Stake Precompile Upgrades

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