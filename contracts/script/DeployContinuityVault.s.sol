// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script, console2 } from "../lib/openzeppelin-contracts/lib/forge-std/src/Script.sol";
import { ContinuityVault } from "../src/ContinuityVault.sol";

contract DeployContinuityVault is Script {
    uint256 private constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

    function run() external returns (ContinuityVault vault) {
        require(block.chainid == ARBITRUM_SEPOLIA_CHAIN_ID, "wrong deployment chain");

        uint256 deployerKey = vm.envUint("DUREQO_DEPLOYER_PRIVATE_KEY");
        address initialOwner = vm.envAddress("DUREQO_INITIAL_OWNER");
        address usdgAddress = vm.envAddress("DUREQO_USDG_ADDRESS");
        uint256 heartbeatInterval = vm.envUint("DUREQO_HEARTBEAT_INTERVAL");
        uint256 gracePeriod = vm.envUint("DUREQO_GRACE_PERIOD");
        uint256 recoveryDelay = vm.envUint("DUREQO_RECOVERY_DELAY");

        require(initialOwner != address(0), "owner is zero");
        require(usdgAddress != address(0), "USDG is zero");
        require(heartbeatInterval > 0 && heartbeatInterval <= type(uint64).max, "invalid heartbeat");
        require(gracePeriod > 0 && gracePeriod <= type(uint64).max, "invalid grace");
        require(recoveryDelay > 0 && recoveryDelay <= type(uint64).max, "invalid recovery delay");

        vm.startBroadcast(deployerKey);
        vault = new ContinuityVault(
            initialOwner,
            usdgAddress,
            uint64(heartbeatInterval),
            uint64(gracePeriod),
            uint64(recoveryDelay)
        );
        vm.stopBroadcast();

        console2.log("ContinuityVault", address(vault));
        console2.log("deployer", vm.addr(deployerKey));
        console2.log("owner", initialOwner);
        console2.log("USDG", usdgAddress);
        console2.log("heartbeatInterval", heartbeatInterval);
        console2.log("gracePeriod", gracePeriod);
        console2.log("recoveryDelay", recoveryDelay);
    }
}
