// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;
/* solhint-disable no-console */

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { IPTokenStaking } from "../../src/protocol/IPTokenStaking.sol";
import { Predeploys } from "../../src/libraries/Predeploys.sol";
import { Create3 } from "../../src/deploy/Create3.sol";

/**
 * @title DeployNewIPTokenStaking_SIP00010
 * @notice Deploys a new IPTokenStaking implementation with reduced defaultMinFee (0.1 IP)
 * @dev SIP-00010: Reducing Staking Thresholds
 *      - defaultMinFee: 1 IP → 0.1 IP (immutable, requires new implementation)
 *      - After upgrade, call setMinStakeAmount(32 ether), setMinUnstakeAmount(32 ether), setFee(0.1 ether) via timelock
 */
contract DeployNewIPTokenStaking_SIP00010 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        Create3 create3 = Create3(Predeploys.Create3);

        bytes memory creationCode = abi.encodePacked(
            type(IPTokenStaking).creationCode,
            abi.encode(0.1 ether, 256) // Constructor args: defaultMinFee (0.1 IP), maxDataLength
        );

        bytes32 salt = keccak256(abi.encodePacked("IPTokenStaking_Implementation_SIP00010"));

        address newImplementation = create3.deploy(salt, creationCode);
        if (create3.getDeployed(deployer, salt) != newImplementation) {
            revert("Deployment failed");
        }

        vm.stopBroadcast();

        console2.log("New IPTokenStaking implementation deployed at:", newImplementation);
        console2.log("DEFAULT_MIN_FEE:", IPTokenStaking(newImplementation).DEFAULT_MIN_FEE());
    }
}
