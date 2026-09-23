// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ContinuityVault } from "../../../src/ContinuityVault.sol";
import { Vm } from "../../../lib/openzeppelin-contracts/lib/forge-std/src/Vm.sol";
import { SecurityMockUSDG } from "../SecurityMockUSDG.sol";

contract ContinuityVaultHandler {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address public constant OWNER = address(0x1001);
    address public constant PENDING_OWNER = address(0x1002);
    address public constant RANDOM_USER = address(0x1003);
    address public constant EXECUTOR_A = address(0x1004);
    address public constant EXECUTOR_B = address(0x1005);
    address public constant DEPOSITOR = address(0x1006);

    SecurityMockUSDG public immutable token;
    ContinuityVault public immutable vault;

    uint256 public calls;
    uint256 public successfulExecutions;

    constructor() {
        token = new SecurityMockUSDG();
        vault = new ContinuityVault(OWNER, address(token), 1 days, 2 days, 3 days);
    }

    function deposit(uint256 rawAmount, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        uint256 amount = _amount(rawAmount, 1e24);
        token.mint(actor, amount);
        vm.prank(actor);
        token.approve(address(vault), amount);
        _call(actor, abi.encodeWithSelector(vault.deposit.selector, amount));
        calls++;
    }

    function directTransfer(uint256 rawAmount, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        uint256 amount = _amount(rawAmount, 1e24);
        token.mint(actor, amount);
        vm.prank(actor);
        token.transfer(address(vault), amount);
        calls++;
    }

    function createOneTimeCommitment(uint256 rawAmount, uint256 rawDue, uint256 actorSeed)
        external
    {
        address actor = _actor(actorSeed);
        uint256 amount = _amount(rawAmount, 1e18);
        uint64 due = _due(rawDue);
        _fundIfOwner(actor, amount);
        _call(
            actor,
            abi.encodeWithSelector(vault.createCommitment.selector, RANDOM_USER, amount, 0, due)
        );
        calls++;
    }

    function createRecurringCommitment(uint256 rawAmount, uint256 rawInterval, uint256 actorSeed)
        external
    {
        address actor = _actor(actorSeed);
        uint256 amount = _amount(rawAmount, 1e18);
        uint64 interval = uint64(rawInterval % 30 days + 1);
        _fundIfOwner(actor, amount);
        _call(
            actor,
            abi.encodeWithSelector(
                vault.createCommitment.selector, PENDING_OWNER, amount, interval, _due(rawInterval)
            )
        );
        calls++;
    }

    function cancelCommitment(uint256 rawId, uint256 actorSeed) external {
        _call(
            _actor(actorSeed), abi.encodeWithSelector(vault.cancelCommitment.selector, _id(rawId))
        );
        calls++;
    }

    function executeCommitment(uint256 rawId, uint256 actorSeed) external {
        (bool success,) = _call(
            _actor(actorSeed), abi.encodeWithSelector(vault.executeCommitment.selector, _id(rawId))
        );
        if (success) successfulExecutions++;
        calls++;
    }

    function checkIn(uint256 actorSeed) external {
        _call(_actor(actorSeed), abi.encodeWithSelector(vault.checkIn.selector));
        calls++;
    }

    function activateContinuity(uint256 actorSeed) external {
        _call(_actor(actorSeed), abi.encodeWithSelector(vault.activateContinuity.selector));
        calls++;
    }

    function transferOwnership(uint256 actorSeed) external {
        _call(
            _actor(actorSeed),
            abi.encodeWithSelector(vault.transferOwnership.selector, PENDING_OWNER)
        );
        calls++;
    }

    function acceptOwnership(uint256 actorSeed) external {
        address actor = actorSeed % 3 == 0 ? PENDING_OWNER : _actor(actorSeed);
        _call(actor, abi.encodeWithSelector(vault.acceptOwnership.selector));
        calls++;
    }

    function requestRecovery(uint256 actorSeed) external {
        _call(_actor(actorSeed), abi.encodeWithSelector(vault.requestRecovery.selector));
        calls++;
    }

    function cancelRecovery(uint256 actorSeed) external {
        _call(_actor(actorSeed), abi.encodeWithSelector(vault.cancelRecovery.selector));
        calls++;
    }

    function completeRecovery(uint256 actorSeed) external {
        _call(_actor(actorSeed), abi.encodeWithSelector(vault.completeRecovery.selector));
        calls++;
    }

    function warpForward(uint256 rawDelta) external {
        uint256 delta = rawDelta % 14 days;
        vm.warp(block.timestamp + delta);
        calls++;
    }

    function setTokenFailures(uint256 rawFlags) external {
        token.setFailTransfer(rawFlags & 1 == 1);
        token.setFailTransferFrom(rawFlags & 2 == 2);
        calls++;
    }

    function clearTokenFailures() external {
        token.setFailTransfer(false);
        token.setFailTransferFrom(false);
        calls++;
    }

    function _fundIfOwner(address actor, uint256 amount) private {
        if (actor != vault.owner()) return;
        uint256 funding = amount * 2;
        token.mint(actor, funding);
        vm.prank(actor);
        token.approve(address(vault), funding);
        _call(actor, abi.encodeWithSelector(vault.deposit.selector, funding));
    }

    function _call(address actor, bytes memory data)
        private
        returns (bool success, bytes memory result)
    {
        vm.prank(actor);
        (success, result) = address(vault).call(data);
    }

    function _actor(uint256 seed) private pure returns (address) {
        uint256 choice = seed % 6;
        if (choice == 0) return OWNER;
        if (choice == 1) return PENDING_OWNER;
        if (choice == 2) return RANDOM_USER;
        if (choice == 3) return EXECUTOR_A;
        if (choice == 4) return EXECUTOR_B;
        return DEPOSITOR;
    }

    function _amount(uint256 raw, uint256 maximum) private pure returns (uint256) {
        return raw % maximum + 1;
    }

    function _due(uint256 raw) private view returns (uint64) {
        return uint64(block.timestamp + raw % 7 days);
    }

    function _id(uint256 raw) private view returns (uint256) {
        uint256 count = vault.commitmentCount();
        return count == 0 ? raw % 3 + 1 : raw % (count + 2) + 1;
    }
}
