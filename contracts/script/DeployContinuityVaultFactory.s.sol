// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script, console2 } from "../lib/openzeppelin-contracts/lib/forge-std/src/Script.sol";
import { ContinuityVaultFactory } from "../src/ContinuityVaultFactory.sol";

contract DeployContinuityVaultFactory is Script {
    uint256 private constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    address private constant CANONICAL_USDG = 0xFFC95faa3d63Cde504a05B567C600B78C0b41892;
    uint64 private constant EXPECTED_HEARTBEAT_INTERVAL = 300;
    uint64 private constant EXPECTED_GRACE_PERIOD = 180;
    uint64 private constant EXPECTED_RECOVERY_DELAY = 180;

    function run() external returns (ContinuityVaultFactory factory) {
        require(block.chainid == ARBITRUM_SEPOLIA_CHAIN_ID, "wrong deployment chain");

        uint256 deployerKey = vm.envUint("DUREQO_DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        factory = new ContinuityVaultFactory();
        vm.stopBroadcast();

        require(factory.ASSET() == CANONICAL_USDG, "unexpected factory asset");
        require(
            factory.HEARTBEAT_INTERVAL() == EXPECTED_HEARTBEAT_INTERVAL,
            "unexpected heartbeat interval"
        );
        require(factory.GRACE_PERIOD() == EXPECTED_GRACE_PERIOD, "unexpected grace period");
        require(factory.RECOVERY_DELAY() == EXPECTED_RECOVERY_DELAY, "unexpected recovery delay");

        console2.log("ContinuityVaultFactory", address(factory));
        console2.log("deployer", vm.addr(deployerKey));
        console2.log("chainId", block.chainid);
        console2.log("USDG", factory.ASSET());
        console2.log("heartbeatInterval", factory.HEARTBEAT_INTERVAL());
        console2.log("gracePeriod", factory.GRACE_PERIOD());
        console2.log("recoveryDelay", factory.RECOVERY_DELAY());
    }
}
