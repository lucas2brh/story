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

contract PrecompileUpgrades is Script {
    TimelockController internal timelock;
    address public newImpl = address(0xB8ba785A5FC96afE8d90Bc87d2f20Ad738E970c2); // replace
    bytes32 public salt = keccak256(abi.encodePacked("StakingUpgrade-v1.0.2"));

    function run() public {
        bool isExecution = vm.envBool("IS_EXECUTE");
        if (isExecution) {
            executeUpgrade();
        } else {
            scheduleUpgrade();
        }
    }

    function scheduleUpgrade() public {
        timelock = TimelockController(payable(0x4827c76bD61A223Ddd36D013c78F825eb0bb3Be3));
        uint256 upgradeKey = vm.envUint("UPGRADE_ADMIN_KEY");
        address upgrader = vm.addr(upgradeKey);
        
        vm.startBroadcast(upgradeKey);

        console2.log("=== Scheduling Upgrade Batch ===");
        console2.log("Upgrader Address:", upgrader);
        console2.log("New Implementation Address:", newImpl);

        ProxyAdmin proxyAdmin = ProxyAdmin(EIP1967Helper.getAdmin(Predeploys.Staking));
        console2.log("ProxyAdmin Address:", address(proxyAdmin));

        uint256 minDelay = timelock.getMinDelay();
        require(minDelay > 0, "Invalid Min Delay");

        // Prepare batch operations
        // Note: scheduleBatch requires all operations to share the same predecessor and salt
        // Operations execute in array order, so order is guaranteed
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory payloads = new bytes[](2);

        // Operation 1: Upgrade
        bytes memory upgradeData = abi.encodeWithSelector(
            proxyAdmin.upgradeAndCall.selector,
            ITransparentUpgradeableProxy(Predeploys.Staking),
            newImpl,
            ""
        );
        targets[0] = address(proxyAdmin);
        values[0] = 0;
        payloads[0] = upgradeData;

        // Operation 2: Set minCreateValidatorAmount
        // This will execute after upgrade in the same batch (guaranteed by array order)
        bytes memory setMinData = abi.encodeWithSelector(
            IPTokenStaking.setMinCreateValidatorAmount.selector,
            1024 ether
        );
        targets[1] = Predeploys.Staking;
        values[1] = 0;
        payloads[1] = setMinData;

        // All operations share the same predecessor (bytes32(0) = no predecessor)
        // and the same salt for batch operations
        bytes32 batchPredecessor = bytes32(0);
        bytes32 batchSalt = salt;

        // Calculate batch operation ID for logging
        bytes32 batchOperationId = timelock.hashOperationBatch(targets, values, payloads, batchPredecessor, batchSalt);
        console2.log("Batch Operation ID:", vm.toString(batchOperationId));

        // Schedule batch - operations execute in array order
        timelock.scheduleBatch(targets, values, payloads, batchPredecessor, batchSalt, minDelay);
        console2.log("Scheduled Batch Operations with Min Delay:", minDelay);
        console2.log("Operations will execute in order: Upgrade -> SetMinCreateValidatorAmount");

        vm.stopBroadcast();
    }

    function executeUpgrade() public {
        timelock = TimelockController(payable(0x4827c76bD61A223Ddd36D013c78F825eb0bb3Be3));
        uint256 executorKey = vm.envUint("EXECUTOR_KEY");
        address executor = vm.addr(executorKey);

        vm.startBroadcast(executorKey);

        console2.log("=== Executing Upgrade Batch ===");
        console2.log("Executor Address:", executor);

        ProxyAdmin proxyAdmin = ProxyAdmin(EIP1967Helper.getAdmin(Predeploys.Staking));
        
        // Prepare batch operations (same as schedule)
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory payloads = new bytes[](2);

        // Operation 1: Upgrade
        bytes memory upgradeData = abi.encodeWithSelector(
            proxyAdmin.upgradeAndCall.selector,
            ITransparentUpgradeableProxy(Predeploys.Staking),
            newImpl,
            ""
        );
        targets[0] = address(proxyAdmin);
        values[0] = 0;
        payloads[0] = upgradeData;

        // Operation 2: Set minCreateValidatorAmount
        bytes memory setMinData = abi.encodeWithSelector(
            IPTokenStaking.setMinCreateValidatorAmount.selector,
            1024 ether
        );
        targets[1] = Predeploys.Staking;
        values[1] = 0;
        payloads[1] = setMinData;

        // All operations share the same predecessor and salt (same as schedule)
        bytes32 batchPredecessor = bytes32(0);
        bytes32 batchSalt = salt;

        // Verify batch operation is ready using hashOperationBatch
        bytes32 batchOperationId = timelock.hashOperationBatch(targets, values, payloads, batchPredecessor, batchSalt);
        console2.log("Batch Operation ID:", vm.toString(batchOperationId));
        require(timelock.isOperationReady(batchOperationId), "Batch operation not ready for execution.");

        // Execute batch - operations execute in array order
        timelock.executeBatch(targets, values, payloads, batchPredecessor, batchSalt);
        console2.log("Batch Executed Successfully.");
        console2.log("Operations executed in order: Upgrade -> SetMinCreateValidatorAmount");

        verifyUpgrade();
        vm.stopBroadcast();
    }

    function verifyUpgrade() internal view {
        console2.log("Verifying Upgrade...");
        uint256 minStake = IPTokenStaking(Predeploys.Staking).minStakeAmount();
        uint256 minUnstake = IPTokenStaking(Predeploys.Staking).minUnstakeAmount();
        uint256 minCreateValidator = IPTokenStaking(Predeploys.Staking).minCreateValidatorAmount();
        address implAddress = EIP1967Helper.getImplementation(Predeploys.Staking);
        console2.log("implAddress: ", implAddress);
        console2.log("minStakeAmount: ", minStake);
        console2.log("minUnstakeAmount: ", minUnstake);
        console2.log("minCreateValidatorAmount: ", minCreateValidator);
        
        // Verify all parameters are set correctly
        require(minStake == 1024 ether, "Min stake amount mismatch.");
        require(minUnstake == 1024 ether, "Min unstake amount mismatch.");
        require(minCreateValidator == 1024 ether, "Min create validator amount mismatch.");
        require(implAddress == newImpl, "Implementation address mismatch.");

        console2.log("All parameters verified successfully!");
        console2.log("Upgrade Verified Successfully!");
    }

}