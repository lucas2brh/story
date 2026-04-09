// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IPTokenStaking } from "src/protocol/IPTokenStaking.sol";
import { ITransparentUpgradeableProxy } from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { EIP1967Helper } from "../utils/EIP1967Helper.sol";
import { Predeploys } from "src/libraries/Predeploys.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title StakePrecompileUpgrades_SIP00010
 * @notice Timelock batch: upgrade IPTokenStaking impl (defaultMinFee 0.1 IP) + set params
 * @dev SIP-00010: Reducing Staking Thresholds
 *
 *  Usage:
 *    Schedule: IS_EXECUTE=false forge script script/upgrades/StakePrecompileUpgrades_SIP00010.s.sol \
 *              --rpc-url <RPC> -vvvv --priority-gas-price 1 --legacy --broadcast
 *    Execute:  IS_EXECUTE=true  forge script script/upgrades/StakePrecompileUpgrades_SIP00010.s.sol \
 *              --rpc-url <RPC> -vvvv --priority-gas-price 1 --legacy --broadcast
 */
contract StakePrecompileUpgrades_SIP00010 is Script {
    // Replace with actual deployed implementation address from DeployNewIPTokenStaking_SIP00010
    address public newImpl = address(0x0); // TODO: set after deployment
    // Timelock controller address (devnet)
    TimelockController internal timelock = TimelockController(payable(0x4827c76bD61A223Ddd36D013c78F825eb0bb3Be3));
    bytes32 public salt = keccak256(abi.encodePacked("SIP00010-StakingUpgrade"));

    uint256 constant NEW_MIN_STAKE = 32 ether;
    uint256 constant NEW_MIN_UNSTAKE = 32 ether;
    uint256 constant NEW_FEE = 0.1 ether;

    function run() public {
        require(newImpl != address(0), "Set newImpl address first");
        bool isExecution = vm.envBool("IS_EXECUTE");
        if (isExecution) {
            executeUpgrade();
        } else {
            scheduleUpgrade();
        }
    }

    function _buildBatch() internal view returns (
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory payloads
    ) {
        ProxyAdmin proxyAdmin = ProxyAdmin(EIP1967Helper.getAdmin(Predeploys.Staking));

        targets = new address[](4);
        values = new uint256[](4);
        payloads = new bytes[](4);

        // Op 1: Upgrade implementation
        targets[0] = address(proxyAdmin);
        values[0] = 0;
        payloads[0] = abi.encodeWithSelector(
            proxyAdmin.upgradeAndCall.selector,
            ITransparentUpgradeableProxy(Predeploys.Staking),
            newImpl,
            ""
        );

        // Op 2: setMinStakeAmount(32 IP)
        targets[1] = Predeploys.Staking;
        values[1] = 0;
        payloads[1] = abi.encodeWithSelector(IPTokenStaking.setMinStakeAmount.selector, NEW_MIN_STAKE);

        // Op 3: setMinUnstakeAmount(32 IP)
        targets[2] = Predeploys.Staking;
        values[2] = 0;
        payloads[2] = abi.encodeWithSelector(IPTokenStaking.setMinUnstakeAmount.selector, NEW_MIN_UNSTAKE);

        // Op 4: setFee(0.1 IP) — requires new impl with DEFAULT_MIN_FEE = 0.1 ether
        targets[3] = Predeploys.Staking;
        values[3] = 0;
        payloads[3] = abi.encodeWithSelector(IPTokenStaking.setFee.selector, NEW_FEE);
    }

    function scheduleUpgrade() public {
        uint256 upgradeKey = vm.envUint("UPGRADE_ADMIN_KEY");
        address upgrader = vm.addr(upgradeKey);
        vm.startBroadcast(upgradeKey);

        console2.log("=== SIP-00010: Scheduling Upgrade Batch ===");
        console2.log("Upgrader:", upgrader);
        console2.log("New Implementation:", newImpl);

        (address[] memory targets, uint256[] memory values, bytes[] memory payloads) = _buildBatch();

        uint256 minDelay = timelock.getMinDelay();
        require(minDelay > 0, "Invalid Min Delay");

        bytes32 batchId = timelock.hashOperationBatch(targets, values, payloads, bytes32(0), salt);
        console2.log("Batch Operation ID:", vm.toString(batchId));

        timelock.scheduleBatch(targets, values, payloads, bytes32(0), salt, minDelay);
        console2.log("Scheduled with delay:", minDelay);
        console2.log("Operations: Upgrade -> setMinStakeAmount -> setMinUnstakeAmount -> setFee");

        vm.stopBroadcast();
    }

    function executeUpgrade() public {
        uint256 executorKey = vm.envUint("EXECUTOR_KEY");
        address executor = vm.addr(executorKey);
        vm.startBroadcast(executorKey);

        console2.log("=== SIP-00010: Executing Upgrade Batch ===");
        console2.log("Executor:", executor);

        (address[] memory targets, uint256[] memory values, bytes[] memory payloads) = _buildBatch();

        bytes32 batchId = timelock.hashOperationBatch(targets, values, payloads, bytes32(0), salt);
        console2.log("Batch Operation ID:", vm.toString(batchId));
        require(timelock.isOperationReady(batchId), "Batch not ready");

        timelock.executeBatch(targets, values, payloads, bytes32(0), salt);
        console2.log("Batch executed.");

        _verify();
        vm.stopBroadcast();
    }

    function _verify() internal view {
        console2.log("=== Verifying ===");
        address implAddr = EIP1967Helper.getImplementation(Predeploys.Staking);
        uint256 minStake = IPTokenStaking(Predeploys.Staking).minStakeAmount();
        uint256 minUnstake = IPTokenStaking(Predeploys.Staking).minUnstakeAmount();
        uint256 fee = IPTokenStaking(Predeploys.Staking).fee();
        uint256 defaultMinFee = IPTokenStaking(Predeploys.Staking).DEFAULT_MIN_FEE();

        console2.log("impl:", implAddr);
        console2.log("minStakeAmount:", minStake);
        console2.log("minUnstakeAmount:", minUnstake);
        console2.log("fee:", fee);
        console2.log("DEFAULT_MIN_FEE:", defaultMinFee);

        require(implAddr == newImpl, "impl mismatch");
        require(minStake == NEW_MIN_STAKE, "minStakeAmount mismatch");
        require(minUnstake == NEW_MIN_UNSTAKE, "minUnstakeAmount mismatch");
        require(fee == NEW_FEE, "fee mismatch");
        require(defaultMinFee == NEW_FEE, "DEFAULT_MIN_FEE mismatch");

        console2.log("All verified.");
    }
}
