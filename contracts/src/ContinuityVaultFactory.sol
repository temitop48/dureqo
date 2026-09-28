// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ContinuityVault } from "./ContinuityVault.sol";

/// @title ContinuityVaultFactory
/// @notice Creates one fixed-policy USDG ContinuityVault per creator.
contract ContinuityVaultFactory {
    address public constant ASSET = 0xFFC95faa3d63Cde504a05B567C600B78C0b41892;
    uint64 public constant HEARTBEAT_INTERVAL = 300;
    uint64 public constant GRACE_PERIOD = 180;
    uint64 public constant RECOVERY_DELAY = 180;

    mapping(address creator => address vault) public vaultCreatedBy;

    error VaultAlreadyExists(address creator, address vault);

    event VaultCreated(
        address indexed creator,
        address indexed vault,
        address indexed asset,
        uint64 heartbeatInterval,
        uint64 gracePeriod,
        uint64 recoveryDelay
    );

    function createVault() external returns (address vault) {
        address existingVault = vaultCreatedBy[msg.sender];
        if (existingVault != address(0)) {
            revert VaultAlreadyExists(msg.sender, existingVault);
        }

        vault = address(
            new ContinuityVault(msg.sender, ASSET, HEARTBEAT_INTERVAL, GRACE_PERIOD, RECOVERY_DELAY)
        );
        vaultCreatedBy[msg.sender] = vault;

        emit VaultCreated(
            msg.sender, vault, ASSET, HEARTBEAT_INTERVAL, GRACE_PERIOD, RECOVERY_DELAY
        );
    }
}
