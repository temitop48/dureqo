// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable2Step } from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title ContinuityVault
/// @notice Phase 2 structural foundation for DUREQO's single-asset vault.
contract ContinuityVault is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Mode {
        ACTIVE,
        CAUTION,
        CONTINUITY
    }

    struct Commitment {
        address recipient;
        uint128 amount;
        uint64 interval;
        uint64 nextDue;
        bool active;
    }

    error ZeroAddress();
    error ZeroAmount();
    error InvalidCommitment(uint256 id);
    error NotActiveMode();
    error ContinuityAlreadyActive();
    error ContinuityNotEligible(uint256 eligibleAt);
    error CommitmentInactive(uint256 id);
    error CommitmentNotDue(uint256 id, uint256 nextDue);
    error InsufficientAvailableBalance(uint256 requested, uint256 available);
    error InsufficientVaultBalance(uint256 required, uint256 balance);
    error InsufficientFundingForCommitment(uint256 requiredProtected, uint256 balance);
    error InvalidInterval();
    error InvalidDueTime();
    error RecoveryNotRequested();
    error RecoveryAlreadyRequested();
    error RecoveryDelayNotElapsed(uint256 executableAt);
    error OwnershipRenunciationDisabled();
    error ZeroHeartbeatInterval();
    error ZeroGracePeriod();
    error ZeroRecoveryDelay();
    error TimestampOverflow();

    event Deposited(address indexed depositor, uint256 amount);
    event CommitmentCreated(
        uint256 indexed id,
        address indexed recipient,
        uint256 amount,
        uint256 interval,
        uint256 firstDue
    );
    event CommitmentCancelled(uint256 indexed id);
    event CommitmentExecuted(
        uint256 indexed id, address indexed recipient, uint256 amount, uint256 nextDue
    );
    event AvailableWithdrawn(address indexed recipient, uint256 amount);
    event Heartbeat(uint256 timestamp);
    event ContinuityActivated(address indexed caller, uint256 timestamp);
    event RecoveryRequested(uint256 requestedAt, uint256 executableAt);
    event RecoveryCancelled();
    event RecoveryCompleted(uint256 timestamp);

    IERC20 public immutable usdg;
    uint64 public immutable heartbeatInterval;
    uint64 public immutable gracePeriod;
    uint64 public immutable recoveryDelay;

    uint64 public lastHeartbeat;
    bool public continuityActivated;
    uint64 public recoveryRequestedAt;

    uint256 public protectedBalance;
    uint256 public commitmentCount;

    mapping(uint256 => Commitment) private _commitments;

    constructor(
        address initialOwner,
        address usdgAddress,
        uint64 heartbeatInterval_,
        uint64 gracePeriod_,
        uint64 recoveryDelay_
    ) Ownable(initialOwner) {
        if (usdgAddress == address(0)) revert ZeroAddress();
        if (heartbeatInterval_ == 0) revert ZeroHeartbeatInterval();
        if (gracePeriod_ == 0) revert ZeroGracePeriod();
        if (recoveryDelay_ == 0) revert ZeroRecoveryDelay();
        if (block.timestamp > type(uint64).max) revert TimestampOverflow();

        usdg = IERC20(usdgAddress);
        heartbeatInterval = heartbeatInterval_;
        gracePeriod = gracePeriod_;
        recoveryDelay = recoveryDelay_;
        lastHeartbeat = uint64(block.timestamp);
    }

    /// @dev Ownership renunciation would permanently remove the controller foundation.
    function renounceOwnership() public pure override {
        revert OwnershipRenunciationDisabled();
    }

    function mode() public view returns (Mode) {
        if (continuityActivated) return Mode.CONTINUITY;
        if (block.timestamp <= activeUntil()) return Mode.ACTIVE;
        return Mode.CAUTION;
    }

    /// @dev Deadline arithmetic is intentionally uint256. Phase 2 stores only
    /// the heartbeat and configuration values as uint64; it does not narrow
    /// either computed future deadline back into uint64 storage.
    function activeUntil() public view returns (uint256) {
        return uint256(lastHeartbeat) + uint256(heartbeatInterval);
    }

    function continuityEligibleAt() public view returns (uint256) {
        return activeUntil() + uint256(gracePeriod);
    }

    function getCommitment(uint256 id) external view returns (Commitment memory) {
        if (id == 0 || id > commitmentCount) revert InvalidCommitment(id);
        return _commitments[id];
    }

    function availableBalance() public view returns (uint256) {
        uint256 balance = usdg.balanceOf(address(this));
        return balance > protectedBalance ? balance - protectedBalance : 0;
    }

    function isFunded() public view returns (bool) {
        return usdg.balanceOf(address(this)) >= protectedBalance;
    }

    /// @notice Deposit USDG into the treasury without creating depositor claims.
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        usdg.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    /// @notice Withdraw unreserved USDG while the vault remains operational.
    function withdrawAvailable(address recipient, uint256 amount) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (mode() != Mode.ACTIVE) revert NotActiveMode();

        uint256 available = availableBalance();
        if (amount > available) revert InsufficientAvailableBalance(amount, available);

        usdg.safeTransfer(recipient, amount);
        emit AvailableWithdrawn(recipient, amount);
    }

    function createCommitment(address recipient, uint128 amount, uint64 interval, uint64 firstDue)
        external
        onlyOwner
        returns (uint256 id)
    {
        if (mode() != Mode.ACTIVE) revert NotActiveMode();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (uint256(firstDue) < block.timestamp) revert InvalidDueTime();

        uint256 actualBalance = usdg.balanceOf(address(this));
        if (protectedBalance > type(uint256).max - uint256(amount)) {
            revert InsufficientFundingForCommitment(type(uint256).max, actualBalance);
        }
        uint256 newProtectedBalance = protectedBalance + uint256(amount);
        if (actualBalance < newProtectedBalance) {
            revert InsufficientFundingForCommitment(newProtectedBalance, actualBalance);
        }

        id = ++commitmentCount;
        _commitments[id] = Commitment({
            recipient: recipient,
            amount: amount,
            interval: interval,
            nextDue: firstDue,
            active: true
        });
        protectedBalance = newProtectedBalance;

        emit CommitmentCreated(id, recipient, amount, interval, firstDue);
    }

    function cancelCommitment(uint256 id) external onlyOwner {
        if (mode() != Mode.ACTIVE) revert NotActiveMode();
        if (id == 0 || id > commitmentCount) revert InvalidCommitment(id);

        Commitment storage commitment = _commitments[id];
        if (!commitment.active) revert CommitmentInactive(id);

        commitment.active = false;
        protectedBalance -= uint256(commitment.amount);

        emit CommitmentCancelled(id);
    }

    function executeCommitment(uint256 id) external nonReentrant {
        if (id == 0 || id > commitmentCount) revert InvalidCommitment(id);

        Commitment storage commitment = _commitments[id];
        if (!commitment.active) revert CommitmentInactive(id);
        if (block.timestamp < uint256(commitment.nextDue)) {
            revert CommitmentNotDue(id, commitment.nextDue);
        }

        uint256 actualBalance = usdg.balanceOf(address(this));
        if (actualBalance < uint256(commitment.amount)) {
            revert InsufficientVaultBalance(commitment.amount, actualBalance);
        }

        address recipient = commitment.recipient;
        uint128 amount = commitment.amount;
        uint64 nextDue = commitment.nextDue;

        if (commitment.interval == 0) {
            commitment.active = false;
            protectedBalance -= uint256(amount);
        } else {
            uint256 nextDue256 = block.timestamp + uint256(commitment.interval);
            if (nextDue256 > type(uint64).max) revert TimestampOverflow();
            // forge-lint: disable-next-line(unsafe-typecast) -- bounded above.
            nextDue = uint64(nextDue256);
            commitment.nextDue = nextDue;
        }

        usdg.safeTransfer(recipient, amount);
        emit CommitmentExecuted(id, recipient, amount, nextDue);
    }
}
