// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;
/* solhint-disable no-console */
/* solhint-disable max-line-length */

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
// solhint-disable-next-line max-line-length
import { TransparentUpgradeableProxy, ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

// CDRStorageLayoutPoC
//
// Standalone proof-of-concept that PR #799 inserts the new `maxBatchSize`
// field at the wrong position within CDRStorage, shifting the `vaults`
// mapping seed slot from CDRStorageLocation+7 to CDRStorageLocation+8.
// For any pre-existing vault data on a deployed CDR proxy, the upgrade
// orphans it: data physically remains, but new bytecode reads from a
// different slot.
//
// Uses the real CDRStorageLocation constant from contracts/src/protocol/
// CDR.sol so this PoC operates on the same storage region as production.
//
// Wraps the implementations in TransparentUpgradeableProxy + auto-created
// ProxyAdmin to match how Story's predeploys (CDR / DKG / SGXValidationHook /
// etc) are deployed by GenerateAlloc.s.sol. The upgrade step goes through
// ProxyAdmin.upgradeAndCall, mirroring UpgradeCDR.s.sol's production path.
//
// Self-contained otherwise: no Vault struct dependency (storage value
// simplified to bytes32), no Predeploys / TimelockController.
//
// Run: forge test --mc CDRStorageLayoutPoC -vv

bytes32 constant CDR_STORAGE_LOCATION = 0x38eb98a52971d8773d43e336c762a70f1492f62ea143e494a29d8ec99eadf600;

/// @dev Pre-#799 layout — vaults mapping at relative slot 7
contract CDR_Before {
    struct CDRStorage {
        uint32 uuid;
        uint256 baseFee;
        uint256 writeFee;
        uint256 readFee;
        uint256 allocateFee;
        uint256 maxEncryptedDataSize;
        uint256 maxEncryptedPartialSize;
        mapping(uint32 => bytes32) vaults; // relative slot 7
    }

    function _s() private pure returns (CDRStorage storage $) {
        bytes32 slot = CDR_STORAGE_LOCATION;
        assembly {
            $.slot := slot
        }
    }

    function setVault(uint32 uuid, bytes32 data) external {
        _s().vaults[uuid] = data;
    }

    function getVault(uint32 uuid) external view returns (bytes32) {
        return _s().vaults[uuid];
    }
}

/// @dev #799 layout — `maxBatchSize` inserted BEFORE `vaults`; vaults seed shifts to relative slot 8
contract CDR_BuggyAfter {
    struct CDRStorage {
        uint32 uuid;
        uint256 baseFee;
        uint256 writeFee;
        uint256 readFee;
        uint256 allocateFee;
        uint256 maxEncryptedDataSize;
        uint256 maxEncryptedPartialSize;
        uint256 maxBatchSize; // inserted at relative slot 7
        mapping(uint32 => bytes32) vaults; // shifted to relative slot 8
    }

    function _s() private pure returns (CDRStorage storage $) {
        bytes32 slot = CDR_STORAGE_LOCATION;
        assembly {
            $.slot := slot
        }
    }

    function setVault(uint32 uuid, bytes32 data) external {
        _s().vaults[uuid] = data;
    }

    function getVault(uint32 uuid) external view returns (bytes32) {
        return _s().vaults[uuid];
    }

    function setMaxBatchSize(uint256 v) external {
        _s().maxBatchSize = v;
    }

    function getMaxBatchSize() external view returns (uint256) {
        return _s().maxBatchSize;
    }
}

/// @dev Correct fix — `maxBatchSize` APPENDED after `vaults`; vaults stays at relative slot 7
contract CDR_FixedAfter {
    struct CDRStorage {
        uint32 uuid;
        uint256 baseFee;
        uint256 writeFee;
        uint256 readFee;
        uint256 allocateFee;
        uint256 maxEncryptedDataSize;
        uint256 maxEncryptedPartialSize;
        mapping(uint32 => bytes32) vaults; // STAYS at relative slot 7
        uint256 maxBatchSize; // appended at relative slot 8
    }

    function _s() private pure returns (CDRStorage storage $) {
        bytes32 slot = CDR_STORAGE_LOCATION;
        assembly {
            $.slot := slot
        }
    }

    function setVault(uint32 uuid, bytes32 data) external {
        _s().vaults[uuid] = data;
    }

    function getVault(uint32 uuid) external view returns (bytes32) {
        return _s().vaults[uuid];
    }

    function setMaxBatchSize(uint256 v) external {
        _s().maxBatchSize = v;
    }

    function getMaxBatchSize() external view returns (uint256) {
        return _s().maxBatchSize;
    }
}

contract CDRStorageLayoutPoC is Test {
    CDR_Before internal beforeImpl;
    CDR_BuggyAfter internal buggyImpl;
    CDR_FixedAfter internal fixedImpl;

    function setUp() public {
        beforeImpl = new CDR_Before();
        buggyImpl = new CDR_BuggyAfter();
        fixedImpl = new CDR_FixedAfter();
    }

    /// @dev Deploy a TransparentUpgradeableProxy wrapping `impl`, with this contract as the
    ///      owner of the auto-created ProxyAdmin. Mirrors GenerateAlloc.s.sol's predeploy setup.
    function _deployProxy(address impl) internal returns (address) {
        return address(new TransparentUpgradeableProxy(impl, address(this), ""));
    }

    /// @dev Read the auto-created ProxyAdmin out of the EIP-1967 admin slot.
    function _getProxyAdmin(address proxy) internal view returns (ProxyAdmin) {
        bytes32 raw = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return ProxyAdmin(address(uint160(uint256(raw))));
    }

    /// @dev Upgrade through ProxyAdmin.upgradeAndCall — same path as UpgradeCDR.s.sol uses
    ///      via the timelock in production. This contract owns the ProxyAdmin (set in
    ///      _deployProxy), so onlyOwner gating is satisfied.
    function _upgradeImpl(address proxy, address newImpl) internal {
        _getProxyAdmin(proxy).upgradeAndCall(ITransparentUpgradeableProxy(proxy), newImpl, "");
    }

    /// @dev Compute the absolute storage slot at which `vaults[uuid]` is stored, given the
    ///      mapping seed's *relative* slot inside the ERC-7201 namespaced struct.
    function _vaultStorageSlot(uint32 uuid, uint256 relativeSlot) internal pure returns (bytes32) {
        bytes32 absSlot = bytes32(uint256(CDR_STORAGE_LOCATION) + relativeSlot);
        return keccak256(abi.encode(uuid, absSlot));
    }

    /// @notice Test 1 — buggy upgrade (#799 layout) orphans pre-existing vault data
    function test_BuggyUpgrade_OrphansVaultData() public {
        address p = _deployProxy(address(beforeImpl));

        // 1. Under BEFORE layout, write a vault
        uint32 uuid = 42;
        bytes32 data = bytes32("data42");
        CDR_Before(p).setVault(uuid, data);

        // 2. Sanity: raw storage at OLD slot (relative slot 7 = vaults seed) contains data
        bytes32 oldSlot = _vaultStorageSlot(uuid, 7);
        assertEq(vm.load(p, oldSlot), data, "raw OLD slot should contain data42");
        assertEq(CDR_Before(p).getVault(uuid), data, "Before impl should read data42");

        // 3. Upgrade to BUGGY After impl (maxBatchSize inserted before vaults)
        _upgradeImpl(p, address(buggyImpl));

        // 4. New impl reads vaults at NEW slot (relative slot 8) → empty
        assertEq(CDR_BuggyAfter(p).getVault(uuid), bytes32(0), "BUG: vault data orphaned after upgrade");

        // 5. Old data physically still on chain — proves the bug is a slot shift, not a delete
        assertEq(vm.load(p, oldSlot), data, "raw OLD slot still contains data42 (orphaned, unreachable)");

        // 6. New slot (where new impl looks) is empty
        bytes32 newSlot = _vaultStorageSlot(uuid, 8);
        assertEq(vm.load(p, newSlot), bytes32(0), "raw NEW slot is empty");

        console2.log("Test 1: BUG REPRODUCED -- vault data orphaned by #799 layout");
        console2.log("  OLD slot (relative 7) still holds:");
        console2.logBytes32(vm.load(p, oldSlot));
        console2.log("  NEW slot (relative 8) reads:");
        console2.logBytes32(vm.load(p, newSlot));
    }

    /// @notice Test 2 — fixed upgrade (append-at-end) preserves vault data and lets the new field work
    function test_FixedUpgrade_PreservesVaultData() public {
        address p = _deployProxy(address(beforeImpl));

        // 1. Under BEFORE layout, write a vault
        uint32 uuid = 99;
        bytes32 data = bytes32("data99");
        CDR_Before(p).setVault(uuid, data);

        // 2. Upgrade to FIXED After impl (maxBatchSize appended after vaults)
        _upgradeImpl(p, address(fixedImpl));

        // 3. Vault data preserved — vaults stayed at relative slot 7
        assertEq(CDR_FixedAfter(p).getVault(uuid), data, "vault preserved across fixed upgrade");

        // 4. New maxBatchSize field is independent and works as expected
        CDR_FixedAfter(p).setMaxBatchSize(20);
        assertEq(CDR_FixedAfter(p).getMaxBatchSize(), 20, "maxBatchSize at relative slot 8 works correctly");

        // 5. Vault unchanged after maxBatchSize write — proves no slot collision
        assertEq(CDR_FixedAfter(p).getVault(uuid), data, "vault still preserved after maxBatchSize write");

        console2.log("Test 2: FIXED UPGRADE OK -- vault preserved + maxBatchSize works independently");
    }
}
