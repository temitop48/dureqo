// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ContinuityVault } from "../src/ContinuityVault.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface Vm {
    function warp(uint256) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData)
        external;
}

contract MockUSDC is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    bool private _failTransfer;
    bool private _failTransferFrom;

    function mint(address account, uint256 amount) external {
        _balances[account] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), account, amount);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (_failTransfer) return false;
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (_failTransferFrom) return false;
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= amount);
        _allowances[from][msg.sender] = allowed - amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function setFailTransfer(bool value) external {
        _failTransfer = value;
    }

    function setFailTransferFrom(bool value) external {
        _failTransferFrom = value;
    }
}

contract ContinuityVaultTest {
    event Deposited(address indexed depositor, uint256 amount);
    event AvailableWithdrawn(address indexed recipient, uint256 amount);
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
    event Heartbeat(uint256 timestamp);
    event ContinuityActivated(address indexed caller, uint256 timestamp);
    event RecoveryRequested(uint256 requestedAt, uint256 executableAt);
    event RecoveryCancelled();
    event RecoveryCompleted(uint256 timestamp);

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant OWNER = address(0x1001);
    address private constant NEW_OWNER = address(0x1002);
    address private constant OTHER = address(0x1003);
    uint64 private constant HEARTBEAT = 1 days;
    uint64 private constant GRACE = 2 days;
    uint64 private constant RECOVERY_DELAY = 3 days;

    MockUSDC private token;
    ContinuityVault private vault;
    uint256 private deployedAt;

    function setUp() public {
        deployedAt = block.timestamp;
        token = new MockUSDC();
        vault = new ContinuityVault(OWNER, address(token), HEARTBEAT, GRACE, RECOVERY_DELAY);
    }

    function testConstructorState() public view {
        _eq(vault.owner(), OWNER);
        _eq(address(vault.usdg()), address(token));
        _eq(vault.heartbeatInterval(), HEARTBEAT);
        _eq(vault.gracePeriod(), GRACE);
        _eq(vault.recoveryDelay(), RECOVERY_DELAY);
        _eq(vault.lastHeartbeat(), deployedAt);
        _false(vault.continuityActivated());
        _eq(vault.recoveryRequestedAt(), 0);
        _eq(vault.protectedBalance(), 0);
        _eq(vault.commitmentCount(), 0);
    }

    function testConstructorRejectsZeroUSDG() public {
        vm.expectRevert(ContinuityVault.ZeroAddress.selector);
        new ContinuityVault(OWNER, address(0), HEARTBEAT, GRACE, RECOVERY_DELAY);
    }

    function testConstructorRejectsZeroHeartbeat() public {
        vm.expectRevert(ContinuityVault.ZeroHeartbeatInterval.selector);
        new ContinuityVault(OWNER, address(token), 0, GRACE, RECOVERY_DELAY);
    }

    function testConstructorRejectsZeroGrace() public {
        vm.expectRevert(ContinuityVault.ZeroGracePeriod.selector);
        new ContinuityVault(OWNER, address(token), HEARTBEAT, 0, RECOVERY_DELAY);
    }

    function testConstructorRejectsZeroRecoveryDelay() public {
        vm.expectRevert(ContinuityVault.ZeroRecoveryDelay.selector);
        new ContinuityVault(OWNER, address(token), HEARTBEAT, GRACE, 0);
    }

    function testConstructorRejectsZeroOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableInvalidOwner(address)")), address(0))
        );
        new ContinuityVault(address(0), address(token), HEARTBEAT, GRACE, RECOVERY_DELAY);
    }

    function testConstructorRejectsTimestampAboveUint64Max() public {
        vm.warp(uint256(type(uint64).max) + 1);
        vm.expectRevert(abi.encodeWithSelector(ContinuityVault.TimestampOverflow.selector));
        new ContinuityVault(OWNER, address(token), 1, 1, 1);
    }

    function testTimestampDeadlinesRemainUint256AtUint64Boundary() public {
        vm.warp(type(uint64).max);
        ContinuityVault boundaryVault = new ContinuityVault(OWNER, address(token), 1, 1, 1);

        _eq(boundaryVault.lastHeartbeat(), type(uint64).max);
        _eq(boundaryVault.activeUntil(), uint256(type(uint64).max) + 1);
        _eq(boundaryVault.continuityEligibleAt(), uint256(type(uint64).max) + 2);
    }

    function testRenunciationDisabledAndOwnerUnchanged() public {
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.OwnershipRenunciationDisabled.selector);
        vault.renounceOwnership();

        vm.warp(vault.activeUntil() + 1);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.OwnershipRenunciationDisabled.selector);
        vault.renounceOwnership();

        vm.warp(vault.continuityEligibleAt());
        vault.activateContinuity();
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.OwnershipRenunciationDisabled.selector);
        vault.renounceOwnership();

        _eq(vault.owner(), OWNER);
    }

    function testTwoStepOwnershipWorks() public {
        vm.prank(OWNER);
        vault.transferOwnership(NEW_OWNER);
        _eq(vault.pendingOwner(), NEW_OWNER);
        vm.prank(NEW_OWNER);
        vault.acceptOwnership();
        _eq(vault.owner(), NEW_OWNER);
        _eq(vault.pendingOwner(), address(0));
    }

    function testOwnershipTransferInitiationBlockedInCautionAndContinuity() public {
        vm.warp(vault.activeUntil() + 1);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.transferOwnership(NEW_OWNER);
        _eq(vault.pendingOwner(), address(0));

        vm.warp(vault.continuityEligibleAt());
        vault.activateContinuity();
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.transferOwnership(NEW_OWNER);
        _eq(vault.pendingOwner(), address(0));
    }

    function testNonOwnerCannotInitiateOwnershipTransferInActive() public {
        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.transferOwnership(NEW_OWNER);
        _eq(vault.pendingOwner(), address(0));
    }

    function testOwnershipTransferZeroAddressRetainsOZPendingOwnerBehavior() public {
        vm.prank(OWNER);
        vault.transferOwnership(address(0));
        _eq(vault.pendingOwner(), address(0));
        _eq(vault.owner(), OWNER);
    }

    function testPendingOwnerCanAcceptAfterVaultEntersCaution() public {
        vm.prank(OWNER);
        vault.transferOwnership(NEW_OWNER);
        vm.warp(vault.activeUntil() + 1);

        vm.prank(NEW_OWNER);
        vault.acceptOwnership();
        _eq(vault.owner(), NEW_OWNER);
        _eq(vault.pendingOwner(), address(0));
    }

    function testPendingOwnerCanAcceptAfterContinuityActivation() public {
        vm.prank(OWNER);
        vault.transferOwnership(NEW_OWNER);
        vm.warp(vault.continuityEligibleAt());
        vault.activateContinuity();

        vm.prank(NEW_OWNER);
        vault.acceptOwnership();
        _eq(vault.owner(), NEW_OWNER);
        _eq(vault.pendingOwner(), address(0));
    }

    function testUnauthorizedOwnershipTransferFails() public {
        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.transferOwnership(NEW_OWNER);
    }

    function testModeBoundaries() public {
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
        vm.warp(vault.activeUntil());
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
        vm.warp(vault.activeUntil() + 1);
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CAUTION));
        vm.warp(vault.continuityEligibleAt());
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CAUTION));
    }

    function testTimingViews() public view {
        _eq(vault.activeUntil(), deployedAt + HEARTBEAT);
        _eq(vault.continuityEligibleAt(), deployedAt + HEARTBEAT + GRACE);
    }

    function testAccountingViewsReflectActualTokenBalance() public {
        _eq(vault.availableBalance(), 0);
        _true(vault.isFunded());
        token.mint(address(this), 123 ether);
        require(token.transfer(address(vault), 123 ether));
        _eq(vault.availableBalance(), 123 ether);
        _true(vault.isFunded());
    }

    function testOwnerCanDepositExactAmountAndEmitsEvent() public {
        uint256 amount = 100 ether;
        token.mint(OWNER, amount);
        vm.prank(OWNER);
        token.approve(address(vault), amount);

        vm.expectEmit(true, false, false, true);
        emit Deposited(OWNER, amount);
        vm.prank(OWNER);
        vault.deposit(amount);

        _eq(token.balanceOf(address(vault)), amount);
        _eq(vault.availableBalance(), amount);
    }

    function testNonOwnerDepositDoesNotGrantAuthorityOrChangeVaultState() public {
        uint256 amount = 40 ether;
        uint256 heartbeat = vault.lastHeartbeat();
        token.mint(OTHER, amount);
        vm.startPrank(OTHER);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.withdrawAvailable(OTHER, 1);
        vm.stopPrank();

        _eq(vault.owner(), OWNER);
        _eq(vault.pendingOwner(), address(0));
        _eq(vault.protectedBalance(), 0);
        _eq(vault.lastHeartbeat(), heartbeat);
        _eq(token.balanceOf(address(vault)), amount);
    }

    function testDepositsAccumulateThroughActualTokenBalance() public {
        _depositAs(OWNER, 30 ether);
        _depositAs(OTHER, 70 ether);

        _eq(token.balanceOf(address(vault)), 100 ether);
        _eq(vault.availableBalance(), 100 ether);
        _true(vault.isFunded());
    }

    function testDepositZeroReverts() public {
        vm.prank(OTHER);
        vm.expectRevert(ContinuityVault.ZeroAmount.selector);
        vault.deposit(0);
    }

    function testDirectTransferUpdatesAvailableBalanceWithoutAuthority() public {
        uint256 amount = 25 ether;
        token.mint(OTHER, amount);
        vm.prank(OTHER);
        require(token.transfer(address(vault), amount));

        _eq(vault.availableBalance(), amount);
        _eq(vault.protectedBalance(), 0);
        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.withdrawAvailable(OTHER, 1);
    }

    function testDirectTransferAndDepositCoexist() public {
        token.mint(OTHER, 20 ether);
        vm.prank(OTHER);
        require(token.transfer(address(vault), 20 ether));
        _depositAs(OWNER, 80 ether);

        _eq(token.balanceOf(address(vault)), 100 ether);
        _eq(vault.availableBalance(), 100 ether);
        _eq(vault.protectedBalance(), 0);
    }

    function testOwnerWithdrawsAvailableAndEmitsEvent() public {
        _depositAs(OWNER, 100 ether);

        vm.expectEmit(true, false, false, true);
        emit AvailableWithdrawn(OTHER, 40 ether);
        vm.prank(OWNER);
        vault.withdrawAvailable(OTHER, 40 ether);

        _eq(token.balanceOf(address(vault)), 60 ether);
        _eq(token.balanceOf(OTHER), 40 ether);
        _eq(vault.availableBalance(), 60 ether);
    }

    function testOwnerCanWithdrawExactlyAvailableBalance() public {
        _depositAs(OWNER, 100 ether);
        vm.prank(OWNER);
        vault.withdrawAvailable(OTHER, 100 ether);

        _eq(token.balanceOf(address(vault)), 0);
        _eq(vault.availableBalance(), 0);
        _true(vault.isFunded());
    }

    function testWithdrawalAboveAvailableRevertsWithExactError() public {
        _depositAs(OWNER, 100 ether);
        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                ContinuityVault.InsufficientAvailableBalance.selector, 101 ether, 100 ether
            )
        );
        vault.withdrawAvailable(OTHER, 101 ether);

        _eq(token.balanceOf(address(vault)), 100 ether);
    }

    function testWithdrawalRejectsZeroAmountAndRecipient() public {
        _depositAs(OWNER, 100 ether);

        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.ZeroAmount.selector);
        vault.withdrawAvailable(OTHER, 0);

        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.ZeroAddress.selector);
        vault.withdrawAvailable(address(0), 1);
    }

    function testNonOwnerCannotWithdrawEvenWithValidArguments() public {
        _depositAs(OWNER, 100 ether);
        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.withdrawAvailable(OTHER, 1);
    }

    function testWithdrawalAllowedExactlyAtActiveUntil() public {
        _depositAs(OWNER, 10 ether);
        vm.warp(vault.activeUntil());
        vm.prank(OWNER);
        vault.withdrawAvailable(OTHER, 10 ether);

        _eq(token.balanceOf(address(vault)), 0);
    }

    function testWithdrawalBlockedImmediatelyAfterActiveUntil() public {
        _depositAs(OWNER, 10 ether);
        vm.warp(vault.activeUntil() + 1);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.withdrawAvailable(OTHER, 1);
    }

    function testCautionWithdrawalReverts() public {
        _depositAs(OWNER, 10 ether);
        vm.warp(vault.continuityEligibleAt());
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.withdrawAvailable(OTHER, 1);
    }

    function testDepositTransferFailureLeavesAccountingUnchanged() public {
        token.mint(OWNER, 100 ether);
        vm.prank(OWNER);
        token.approve(address(vault), 100 ether);
        token.setFailTransferFrom(true);

        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(token))
        );
        vault.deposit(100 ether);

        _eq(token.balanceOf(address(vault)), 0);
        _eq(token.balanceOf(OWNER), 100 ether);
        _eq(vault.availableBalance(), 0);
    }

    function testWithdrawalTransferFailureLeavesAccountingUnchanged() public {
        _depositAs(OWNER, 100 ether);
        token.setFailTransfer(true);

        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(token))
        );
        vault.withdrawAvailable(OTHER, 40 ether);

        _eq(token.balanceOf(address(vault)), 100 ether);
        _eq(token.balanceOf(OTHER), 0);
        _eq(vault.availableBalance(), 100 ether);
    }

    function testOwnerCreatesFundedCommitmentsAndStoresExactFields() public {
        _depositAs(OWNER, 100 ether);
        uint64 firstDue = uint64(block.timestamp);

        vm.expectEmit(true, true, false, true);
        emit CommitmentCreated(1, OTHER, 30 ether, 0, firstDue);
        uint256 oneTimeId = _createAsOwner(OTHER, 30 ether, 0, firstDue);
        uint256 recurringId = _createAsOwner(OTHER, 40 ether, 1, firstDue);

        _eq(oneTimeId, 1);
        _eq(recurringId, 2);
        _eq(vault.commitmentCount(), 2);
        _eq(vault.protectedBalance(), 70 ether);

        ContinuityVault.Commitment memory commitment = vault.getCommitment(oneTimeId);
        _eq(commitment.recipient, OTHER);
        _eq(commitment.amount, 30 ether);
        _eq(commitment.interval, 0);
        _eq(commitment.nextDue, firstDue);
        _true(commitment.active);
    }

    function testCreateRejectsInvalidInputsAndInsufficientFunding() public {
        _depositAs(OWNER, 100 ether);
        uint64 firstDue = uint64(block.timestamp);

        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.ZeroAddress.selector);
        vault.createCommitment(address(0), 1, 0, firstDue);

        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.ZeroAmount.selector);
        vault.createCommitment(OTHER, 0, 0, firstDue);

        vm.warp(block.timestamp + 1);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.InvalidDueTime.selector);
        vault.createCommitment(OTHER, 1, 0, firstDue);

        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                ContinuityVault.InsufficientFundingForCommitment.selector, 101 ether, 100 ether
            )
        );
        vault.createCommitment(OTHER, 101 ether, 0, uint64(block.timestamp));

        _eq(vault.commitmentCount(), 0);
        _eq(vault.protectedBalance(), 0);
    }

    function testCreateAcceptsDueNowFutureAndIntervalOne() public {
        _depositAs(OWNER, 100 ether);
        uint64 dueNow = uint64(block.timestamp);
        uint64 futureDue = dueNow + 1;

        _createAsOwner(OTHER, 10 ether, 0, dueNow);
        _createAsOwner(OTHER, 10 ether, 1, futureDue);

        _eq(vault.commitmentCount(), 2);
        _eq(vault.protectedBalance(), 20 ether);
    }

    function testNonOwnerCannotCreateCommitment() public {
        _depositAs(OWNER, 100 ether);
        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.createCommitment(OTHER, 1, 0, uint64(block.timestamp));
    }

    function testCreateAllowedAtActiveUntilAndBlockedAfter() public {
        _depositAs(OWNER, 100 ether);
        vm.warp(vault.activeUntil());
        _createAsOwner(OTHER, 10 ether, 0, uint64(block.timestamp));

        vm.warp(vault.activeUntil() + 1);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.createCommitment(OTHER, 10 ether, 0, uint64(block.timestamp));
    }

    function testDirectTransferFundsCommitmentCreation() public {
        token.mint(OTHER, 50 ether);
        vm.prank(OTHER);
        require(token.transfer(address(vault), 50 ether));

        _createAsOwner(OTHER, 50 ether, 0, uint64(block.timestamp));

        _eq(vault.protectedBalance(), 50 ether);
        _eq(vault.availableBalance(), 0);
    }

    function testOwnerCancelsCommitmentsAndPreservesHistory() public {
        _depositAs(OWNER, 100 ether);
        uint256 firstId = _createAsOwner(OTHER, 20 ether, 0, uint64(block.timestamp));
        uint256 secondId = _createAsOwner(NEW_OWNER, 40 ether, 0, uint64(block.timestamp));

        vm.expectEmit(true, false, false, true);
        emit CommitmentCancelled(firstId);
        vm.prank(OWNER);
        vault.cancelCommitment(firstId);

        ContinuityVault.Commitment memory firstCommitment = vault.getCommitment(firstId);
        ContinuityVault.Commitment memory secondCommitment = vault.getCommitment(secondId);
        _eq(firstCommitment.amount, 20 ether);
        _eq(firstCommitment.interval, 0);
        _eq(firstCommitment.nextDue, uint64(block.timestamp));
        _false(firstCommitment.active);
        _eq(secondCommitment.recipient, NEW_OWNER);
        _eq(secondCommitment.amount, 40 ether);
        _eq(secondCommitment.nextDue, uint64(block.timestamp));
        _true(secondCommitment.active);
        _eq(vault.protectedBalance(), 40 ether);
        _eq(vault.availableBalance(), 60 ether);
        _eq(token.balanceOf(address(vault)), 100 ether);
    }

    function testCancellationRejectsInactiveUnknownAndUnauthorized() public {
        _depositAs(OWNER, 20 ether);
        uint256 id = _createAsOwner(OTHER, 20 ether, 0, uint64(block.timestamp));

        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.cancelCommitment(id);

        vm.prank(OWNER);
        vault.cancelCommitment(id);
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(ContinuityVault.CommitmentInactive.selector, id));
        vault.cancelCommitment(id);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(ContinuityVault.InvalidCommitment.selector, 2));
        vault.cancelCommitment(2);
    }

    function testCancellationAllowedAtActiveUntilAndBlockedAfter() public {
        _depositAs(OWNER, 20 ether);
        uint256 id = _createAsOwner(OTHER, 20 ether, 0, uint64(block.timestamp));

        vm.warp(vault.activeUntil());
        vm.prank(OWNER);
        vault.cancelCommitment(id);

        uint256 secondId = _createAsOwner(OTHER, 20 ether, 0, uint64(block.timestamp));
        vm.warp(vault.activeUntil() + 1);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.cancelCommitment(secondId);
    }

    function testRandomCallerExecutesOneTimeUsingStoredAuthority() public {
        _depositAs(OWNER, 100 ether);
        uint256 id = _createAsOwner(OTHER, 30 ether, 0, uint64(block.timestamp));

        vm.expectEmit(true, true, false, true);
        emit CommitmentExecuted(id, OTHER, 30 ether, block.timestamp);
        vm.prank(NEW_OWNER);
        vault.executeCommitment(id);

        _eq(token.balanceOf(OTHER), 30 ether);
        _eq(token.balanceOf(NEW_OWNER), 0);
        _eq(token.balanceOf(address(vault)), 70 ether);
        _eq(vault.protectedBalance(), 0);
        _eq(vault.availableBalance(), 70 ether);
        _eq(vault.owner(), OWNER);
        ContinuityVault.Commitment memory commitment = vault.getCommitment(id);
        _eq(commitment.amount, 30 ether);
        _eq(commitment.nextDue, uint64(block.timestamp));
        _false(commitment.active);
    }

    function testExecutionRejectsUnknownInactiveAndEarlyCommitments() public {
        _depositAs(OWNER, 50 ether);
        uint256 id = _createAsOwner(OTHER, 20 ether, 0, uint64(block.timestamp + 1));

        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(
                ContinuityVault.CommitmentNotDue.selector, id, block.timestamp + 1
            )
        );
        vault.executeCommitment(id);

        vm.warp(block.timestamp + 1);
        vm.prank(OTHER);
        vault.executeCommitment(id);

        vm.expectRevert(abi.encodeWithSelector(ContinuityVault.CommitmentInactive.selector, id));
        vault.executeCommitment(id);
        vm.expectRevert(abi.encodeWithSelector(ContinuityVault.InvalidCommitment.selector, 2));
        vault.executeCommitment(2);
    }

    function testOneTimeExecutionTransferFailureRestoresState() public {
        _depositAs(OWNER, 50 ether);
        uint256 id = _createAsOwner(OTHER, 20 ether, 0, uint64(block.timestamp));
        token.setFailTransfer(true);

        vm.expectRevert(
            abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(token))
        );
        vault.executeCommitment(id);

        ContinuityVault.Commitment memory commitment = vault.getCommitment(id);
        _eq(commitment.amount, 20 ether);
        _true(commitment.active);
        _eq(vault.protectedBalance(), 20 ether);
        _eq(token.balanceOf(address(vault)), 50 ether);
        _eq(token.balanceOf(OTHER), 0);
    }

    function testRecurringExecutionRollsReservationAndNoCatchUp() public {
        _depositAs(OWNER, 100 ether);
        uint64 interval = 1 days;
        uint256 id = _createAsOwner(OTHER, 30 ether, interval, uint64(block.timestamp));

        vm.warp(block.timestamp + 10 days);
        uint256 executionTimestamp = block.timestamp;
        vm.expectEmit(true, true, false, true);
        emit CommitmentExecuted(id, OTHER, 30 ether, executionTimestamp + uint256(interval));
        vm.prank(NEW_OWNER);
        vault.executeCommitment(id);

        ContinuityVault.Commitment memory commitment = vault.getCommitment(id);
        _eq(commitment.amount, 30 ether);
        _eq(commitment.interval, interval);
        _eq(commitment.nextDue, executionTimestamp + uint256(interval));
        _true(commitment.active);
        _eq(vault.protectedBalance(), 30 ether);
        _eq(token.balanceOf(OTHER), 30 ether);
        _eq(token.balanceOf(address(vault)), 70 ether);
        _eq(vault.availableBalance(), 40 ether);
    }

    function testRecurringSameOccurrenceCannotExecuteTwiceAndRunsAgainLater() public {
        _depositAs(OWNER, 100 ether);
        uint64 interval = 1 days;
        uint256 id = _createAsOwner(OTHER, 30 ether, interval, uint64(block.timestamp));

        vault.executeCommitment(id);
        vm.expectRevert(
            abi.encodeWithSelector(
                ContinuityVault.CommitmentNotDue.selector, id, block.timestamp + interval
            )
        );
        vault.executeCommitment(id);

        vm.warp(block.timestamp + interval);
        vault.executeCommitment(id);
        _eq(token.balanceOf(OTHER), 60 ether);
        _eq(vault.protectedBalance(), 30 ether);
    }

    function testRecurringTransferFailureRestoresNextDue() public {
        _depositAs(OWNER, 50 ether);
        uint64 interval = 1 days;
        uint64 due = uint64(block.timestamp);
        uint256 id = _createAsOwner(OTHER, 20 ether, interval, due);
        token.setFailTransfer(true);

        vm.warp(block.timestamp + 3 days);
        vm.expectRevert(
            abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(token))
        );
        vault.executeCommitment(id);

        ContinuityVault.Commitment memory commitment = vault.getCommitment(id);
        _eq(commitment.nextDue, due);
        _true(commitment.active);
        _eq(vault.protectedBalance(), 20 ether);
    }

    function testRecurringExecutionIsPermissionlessInCaution() public {
        _depositAs(OWNER, 50 ether);
        uint256 id = _createAsOwner(OTHER, 20 ether, 1, uint64(block.timestamp));
        vm.warp(vault.activeUntil() + 1);

        vm.prank(NEW_OWNER);
        vault.executeCommitment(id);
        _eq(token.balanceOf(OTHER), 20 ether);
    }

    function testRecurringNextDueOverflowRevertsWithoutNarrowing() public {
        _depositAs(OWNER, 20 ether);
        uint256 id = _createAsOwner(OTHER, 10 ether, 1, uint64(block.timestamp));
        uint64 originalDue = uint64(block.timestamp);
        vm.warp(type(uint64).max);

        vm.expectRevert(ContinuityVault.TimestampOverflow.selector);
        vault.executeCommitment(id);

        ContinuityVault.Commitment memory commitment = vault.getCommitment(id);
        _eq(commitment.nextDue, originalDue);
        _true(commitment.active);
    }

    function testProtectedCapitalCannotBeWithdrawn() public {
        _depositAs(OWNER, 100 ether);
        _createAsOwner(OTHER, 30 ether, 0, uint64(block.timestamp));
        _eq(vault.availableBalance(), 70 ether);

        vm.prank(OWNER);
        vault.withdrawAvailable(NEW_OWNER, 70 ether);
        _eq(token.balanceOf(address(vault)), 30 ether);
        _eq(vault.protectedBalance(), 30 ether);

        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(ContinuityVault.InsufficientAvailableBalance.selector, 1, 0)
        );
        vault.withdrawAvailable(NEW_OWNER, 1);

        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(ContinuityVault.InsufficientAvailableBalance.selector, 71, 0)
        );
        vault.withdrawAvailable(NEW_OWNER, 71);
    }

    function testOneTimeAndRecurringReservationAccounting() public {
        _depositAs(OWNER, 100 ether);
        uint256 oneTimeId = _createAsOwner(OTHER, 20 ether, 0, uint64(block.timestamp));
        uint256 recurringId = _createAsOwner(NEW_OWNER, 30 ether, 1, uint64(block.timestamp));
        _eq(vault.protectedBalance(), 50 ether);
        _eq(vault.availableBalance(), 50 ether);

        vault.executeCommitment(oneTimeId);
        _eq(vault.protectedBalance(), 30 ether);
        _eq(vault.availableBalance(), 50 ether);
        vault.executeCommitment(recurringId);
        _eq(vault.protectedBalance(), 30 ether);
        _eq(vault.availableBalance(), 20 ether);
    }

    function testUnderfundingSaturatesAvailableAndDepositRestoresFunding() public {
        _depositAs(OWNER, 100 ether);
        uint256 id = _createAsOwner(OTHER, 30 ether, 1, uint64(block.timestamp));

        for (uint256 i = 0; i < 3; ++i) {
            vault.executeCommitment(id);
            vm.warp(block.timestamp + 1);
        }

        _eq(token.balanceOf(address(vault)), 10 ether);
        _eq(vault.protectedBalance(), 30 ether);
        _eq(vault.availableBalance(), 0);
        _false(vault.isFunded());

        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(ContinuityVault.InsufficientAvailableBalance.selector, 1, 0)
        );
        vault.withdrawAvailable(OWNER, 1);

        _depositAs(OWNER, 20 ether);
        _true(vault.isFunded());
        _eq(vault.availableBalance(), 0);
    }

    function testUnderfundedDueCommitmentCanExecuteIfIndividuallyFunded() public {
        _depositAs(OWNER, 60 ether);
        uint256 firstId = _createAsOwner(OTHER, 30 ether, 1, uint64(block.timestamp));
        uint256 secondId = _createAsOwner(NEW_OWNER, 30 ether, 1, uint64(block.timestamp));

        vault.executeCommitment(firstId);
        _false(vault.isFunded());
        _eq(token.balanceOf(address(vault)), 30 ether);

        vault.executeCommitment(secondId);
        _eq(token.balanceOf(address(vault)), 0);
        _eq(vault.protectedBalance(), 60 ether);
    }

    function testUnderfundedDueCommitmentBelowAmountReverts() public {
        _depositAs(OWNER, 50 ether);
        uint256 id = _createAsOwner(OTHER, 30 ether, 1, uint64(block.timestamp));
        vault.executeCommitment(id);
        vm.warp(block.timestamp + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ContinuityVault.InsufficientVaultBalance.selector, 30 ether, 20 ether
            )
        );
        vault.executeCommitment(id);
    }

    function testOwnerCheckInRefreshesActiveDeadlinesAndPreservesState() public {
        _depositAs(OWNER, 50 ether);
        uint256 id = _createAsOwner(OTHER, 20 ether, 1, uint64(block.timestamp));
        vm.warp(deployedAt + 1);
        uint256 checkInTimestamp = block.timestamp;

        vm.expectEmit(false, false, false, true);
        emit Heartbeat(checkInTimestamp);
        vm.prank(OWNER);
        vault.checkIn();

        _eq(vault.lastHeartbeat(), checkInTimestamp);
        _eq(vault.activeUntil(), checkInTimestamp + HEARTBEAT);
        _eq(vault.continuityEligibleAt(), checkInTimestamp + HEARTBEAT + GRACE);
        _eq(vault.protectedBalance(), 20 ether);
        _eq(vault.commitmentCount(), 1);
        ContinuityVault.Commitment memory commitment = vault.getCommitment(id);
        _true(commitment.active);
        _false(vault.continuityActivated());
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
    }

    function testOwnerCheckInRefreshesFromCaution() public {
        vm.warp(vault.activeUntil() + 1);
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CAUTION));
        uint256 checkInTimestamp = block.timestamp;

        vm.prank(OWNER);
        vault.checkIn();

        _eq(vault.lastHeartbeat(), checkInTimestamp);
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
        _eq(vault.activeUntil(), checkInTimestamp + HEARTBEAT);
        _eq(vault.continuityEligibleAt(), checkInTimestamp + HEARTBEAT + GRACE);
    }

    function testDepositRemainsPermissionlessInCaution() public {
        vm.warp(vault.activeUntil() + 1);
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CAUTION));
        _depositAs(OTHER, 10 ether);

        _eq(token.balanceOf(address(vault)), 10 ether);
        _eq(vault.availableBalance(), 10 ether);
    }

    function testOwnerCanCheckInAtAndAfterOldEligibilityBeforeActivation() public {
        uint256 oldEligibleAt = vault.continuityEligibleAt();
        vm.warp(oldEligibleAt + 1);
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CAUTION));
        vm.prank(OWNER);
        vault.checkIn();
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
        _false(vault.continuityActivated());
    }

    function testNonOwnerCannotCheckInInActiveOrCaution() public {
        uint64 initialHeartbeat = vault.lastHeartbeat();
        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.checkIn();
        _eq(vault.lastHeartbeat(), initialHeartbeat);

        vm.warp(vault.activeUntil() + 1);
        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.checkIn();
        _eq(vault.lastHeartbeat(), initialHeartbeat);
    }

    function testCheckInTimestampBoundaryAndOverflowSafety() public {
        vm.warp(type(uint64).max);
        vm.prank(OWNER);
        vault.checkIn();
        _eq(vault.lastHeartbeat(), type(uint64).max);

        vm.warp(uint256(type(uint64).max) + 1);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.TimestampOverflow.selector);
        vault.checkIn();
        _eq(vault.lastHeartbeat(), type(uint64).max);
    }

    function testActivationRejectsBeforeEligibilityAndSucceedsAtExactEligibility() public {
        uint256 activeUntil = vault.activeUntil();
        uint256 eligibleAt = vault.continuityEligibleAt();

        vm.warp(activeUntil);
        vm.expectRevert(
            abi.encodeWithSelector(ContinuityVault.ContinuityNotEligible.selector, eligibleAt)
        );
        vault.activateContinuity();

        vm.warp(eligibleAt - 1);
        vm.expectRevert(
            abi.encodeWithSelector(ContinuityVault.ContinuityNotEligible.selector, eligibleAt)
        );
        vault.activateContinuity();
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CAUTION));

        vm.warp(eligibleAt);
        vm.expectEmit(true, false, false, true);
        emit ContinuityActivated(OTHER, eligibleAt);
        vm.prank(OTHER);
        vault.activateContinuity();

        _true(vault.continuityActivated());
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CONTINUITY));
    }

    function testActivationSucceedsAfterEligibilityAndLatches() public {
        uint256 eligibleAt = vault.continuityEligibleAt();
        vm.warp(eligibleAt + 1);
        vm.prank(NEW_OWNER);
        vault.activateContinuity();

        _true(vault.continuityActivated());
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CONTINUITY));
        vm.warp(type(uint64).max);
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CONTINUITY));

        vm.expectRevert(ContinuityVault.ContinuityAlreadyActive.selector);
        vault.activateContinuity();
    }

    function testContinuityActivationPreservesFinancialAndHeartbeatState() public {
        _depositAs(OWNER, 50 ether);
        uint256 id = _createAsOwner(OTHER, 20 ether, 1, uint64(block.timestamp));
        uint64 heartbeat = vault.lastHeartbeat();
        uint256 protectedAmount = vault.protectedBalance();

        vm.warp(vault.continuityEligibleAt());
        vault.activateContinuity();

        _eq(vault.lastHeartbeat(), heartbeat);
        _eq(vault.protectedBalance(), protectedAmount);
        _eq(vault.commitmentCount(), 1);
        ContinuityVault.Commitment memory commitment = vault.getCommitment(id);
        _eq(commitment.amount, 20 ether);
        _true(commitment.active);
    }

    function testEligibilityRaceCheckInFirstInvalidatesOldThreshold() public {
        uint256 oldEligibleAt = vault.continuityEligibleAt();
        vm.warp(oldEligibleAt);
        vm.prank(OWNER);
        vault.checkIn();
        uint256 refreshedEligibleAt = vault.continuityEligibleAt();

        vm.expectRevert(
            abi.encodeWithSelector(
                ContinuityVault.ContinuityNotEligible.selector, refreshedEligibleAt
            )
        );
        vault.activateContinuity();
        _false(vault.continuityActivated());
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
    }

    function testEligibilityRaceActivationFirstBlocksLaterCheckIn() public {
        uint256 eligibleAt = vault.continuityEligibleAt();
        vm.warp(eligibleAt);
        vault.activateContinuity();
        uint64 heartbeat = vault.lastHeartbeat();

        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.checkIn();
        _eq(vault.lastHeartbeat(), heartbeat);
    }

    function testContinuityFinancialBehaviorPreservesExecutionAndDeposit() public {
        _depositAs(OWNER, 100 ether);
        uint256 oneTimeId = _createAsOwner(OTHER, 30 ether, 0, uint64(block.timestamp));
        uint256 recurringId = _createAsOwner(NEW_OWNER, 20 ether, 1, uint64(block.timestamp));

        vm.warp(vault.continuityEligibleAt());
        vault.activateContinuity();
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CONTINUITY));

        _depositAs(OTHER, 10 ether);
        vm.prank(NEW_OWNER);
        vault.executeCommitment(oneTimeId);
        vm.prank(OTHER);
        vault.executeCommitment(recurringId);

        _eq(token.balanceOf(OTHER), 30 ether);
        _eq(token.balanceOf(NEW_OWNER), 20 ether);
        _eq(token.balanceOf(address(vault)), 60 ether);
        _eq(vault.protectedBalance(), 20 ether);
        _eq(vault.availableBalance(), 40 ether);

        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.withdrawAvailable(OWNER, 1);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.createCommitment(OWNER, 1, 0, uint64(block.timestamp));
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.cancelCommitment(recurringId);
    }

    function testRequestRecoveryStoresTimestampAndEmitsDeadline() public {
        _activateContinuity();
        uint256 requestedAt = block.timestamp;
        uint256 executableAt = requestedAt + RECOVERY_DELAY;

        vm.expectEmit(false, false, false, true);
        emit RecoveryRequested(requestedAt, executableAt);
        vm.prank(OWNER);
        vault.requestRecovery();

        _eq(vault.recoveryRequestedAt(), requestedAt);
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CONTINUITY));
    }

    function testRecoveryRequestRequiresContinuityOwnerAndIsSinglePendingRequest() public {
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.requestRecovery();

        _activateContinuity();
        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.requestRecovery();

        vm.prank(OWNER);
        vault.requestRecovery();
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.RecoveryAlreadyRequested.selector);
        vault.requestRecovery();
    }

    function testCancelRecoveryClearsOnlyRequestAndAllowsFreshRequest() public {
        _depositAs(OWNER, 50 ether);
        _createAsOwner(OTHER, 20 ether, 1, uint64(block.timestamp));
        _activateContinuity();
        uint64 heartbeat = vault.lastHeartbeat();
        uint256 protectedAmount = vault.protectedBalance();
        uint256 commitmentTotal = vault.commitmentCount();
        uint256 balance = token.balanceOf(address(vault));

        vm.prank(OWNER);
        vault.requestRecovery();
        uint256 firstRequest = vault.recoveryRequestedAt();

        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.cancelRecovery();

        vm.prank(OWNER);
        vault.cancelRecovery();
        vm.expectRevert(ContinuityVault.RecoveryNotRequested.selector);
        vm.prank(OWNER);
        vault.cancelRecovery();
        _eq(vault.recoveryRequestedAt(), 0);
        _true(vault.continuityActivated());
        _eq(vault.lastHeartbeat(), heartbeat);
        _eq(vault.protectedBalance(), protectedAmount);
        _eq(vault.commitmentCount(), commitmentTotal);
        _eq(token.balanceOf(address(vault)), balance);

        vm.warp(firstRequest + 1);
        vm.prank(OWNER);
        vault.requestRecovery();
        _eq(vault.recoveryRequestedAt(), firstRequest + 1);
    }

    function testCompleteRecoveryRequiresRequestAndExactDelay() public {
        _activateContinuity();
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.RecoveryNotRequested.selector);
        vault.completeRecovery();

        vm.prank(OWNER);
        vault.requestRecovery();
        uint256 executableAt = uint256(vault.recoveryRequestedAt()) + RECOVERY_DELAY;

        vm.warp(executableAt - 1);
        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(ContinuityVault.RecoveryDelayNotElapsed.selector, executableAt)
        );
        vault.completeRecovery();

        vm.warp(executableAt);
        vm.prank(OWNER);
        vault.completeRecovery();
        _false(vault.continuityActivated());
        _eq(vault.recoveryRequestedAt(), 0);
        _eq(vault.lastHeartbeat(), executableAt);
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
        _eq(vault.activeUntil(), executableAt + HEARTBEAT);
        _eq(vault.continuityEligibleAt(), executableAt + HEARTBEAT + GRACE);
    }

    function testCompleteRecoveryAfterDelayAndNonOwnerCannotComplete() public {
        _activateContinuity();
        vm.prank(OWNER);
        vault.requestRecovery();
        uint256 executableAt = uint256(vault.recoveryRequestedAt()) + RECOVERY_DELAY;

        vm.warp(executableAt);
        vm.prank(OTHER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OTHER)
        );
        vault.completeRecovery();
        _true(vault.continuityActivated());
        _eq(vault.recoveryRequestedAt(), executableAt - RECOVERY_DELAY);

        vm.warp(executableAt + 1);
        vm.prank(OWNER);
        vault.completeRecovery();
        _false(vault.continuityActivated());
    }

    function testRecoveryDelayDoesNotExpandContinuityAuthority() public {
        _depositAs(OWNER, 50 ether);
        uint256 id = _createAsOwner(OTHER, 20 ether, 1, uint64(block.timestamp));
        _activateContinuity();
        vm.prank(OWNER);
        vault.requestRecovery();

        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.withdrawAvailable(OWNER, 1);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.createCommitment(OWNER, 1, 0, uint64(block.timestamp));
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.cancelCommitment(id);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.checkIn();
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.NotActiveMode.selector);
        vault.transferOwnership(NEW_OWNER);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.OwnershipRenunciationDisabled.selector);
        vault.renounceOwnership();

        _depositAs(OTHER, 10 ether);
        vm.prank(OTHER);
        vault.executeCommitment(id);
        _eq(token.balanceOf(OTHER), 20 ether);
    }

    function testRecoveryPreservesFinancialStateAndActiveCommitment() public {
        _depositAs(OWNER, 100 ether);
        uint256 id = _createAsOwner(OTHER, 30 ether, 1, uint64(block.timestamp + 1));
        uint256 balance = token.balanceOf(address(vault));
        uint256 protectedAmount = vault.protectedBalance();
        uint256 commitmentTotal = vault.commitmentCount();
        ContinuityVault.Commitment memory beforeRecovery = vault.getCommitment(id);

        _activateContinuity();
        vm.prank(OWNER);
        vault.requestRecovery();
        vm.warp(uint256(vault.recoveryRequestedAt()) + RECOVERY_DELAY);
        vm.prank(OWNER);
        vault.completeRecovery();

        _eq(token.balanceOf(address(vault)), balance);
        _eq(vault.protectedBalance(), protectedAmount);
        _eq(vault.commitmentCount(), commitmentTotal);
        ContinuityVault.Commitment memory afterRecovery = vault.getCommitment(id);
        _eq(afterRecovery.recipient, beforeRecovery.recipient);
        _eq(afterRecovery.amount, beforeRecovery.amount);
        _eq(afterRecovery.interval, beforeRecovery.interval);
        _eq(afterRecovery.nextDue, beforeRecovery.nextDue);
        _true(afterRecovery.active);
    }

    function testPendingOwnerCanControlRecoveryAfterAcceptance() public {
        vm.prank(OWNER);
        vault.transferOwnership(NEW_OWNER);
        _activateContinuity();
        vm.prank(NEW_OWNER);
        vault.acceptOwnership();

        vm.prank(NEW_OWNER);
        vault.requestRecovery();
        uint256 requestedAt = vault.recoveryRequestedAt();
        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OWNER)
        );
        vault.completeRecovery();

        vm.warp(requestedAt + RECOVERY_DELAY);
        vm.prank(NEW_OWNER);
        vault.completeRecovery();
        _eq(vault.owner(), NEW_OWNER);
        _eq(vault.lastHeartbeat(), requestedAt + RECOVERY_DELAY);
    }

    function testOwnershipAcceptanceDuringRecoveryTransfersRecoveryControl() public {
        vm.prank(OWNER);
        vault.transferOwnership(NEW_OWNER);
        _activateContinuity();
        vm.prank(OWNER);
        vault.requestRecovery();
        uint256 requestedAt = vault.recoveryRequestedAt();

        vm.prank(NEW_OWNER);
        vault.acceptOwnership();
        _eq(vault.recoveryRequestedAt(), requestedAt);

        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OWNER)
        );
        vault.cancelRecovery();

        vm.warp(requestedAt + RECOVERY_DELAY);
        vm.prank(NEW_OWNER);
        vault.completeRecovery();
        _eq(vault.owner(), NEW_OWNER);
        _eq(vault.lastHeartbeat(), requestedAt + RECOVERY_DELAY);
    }

    function testRecoverySupportsTwoCompleteCyclesWithoutStaleState() public {
        _activateContinuity();
        vm.prank(OWNER);
        vault.requestRecovery();
        vm.warp(uint256(vault.recoveryRequestedAt()) + RECOVERY_DELAY);
        vm.prank(OWNER);
        vault.completeRecovery();
        uint256 firstHeartbeat = vault.lastHeartbeat();

        vm.warp(vault.continuityEligibleAt());
        vault.activateContinuity();
        vm.prank(OWNER);
        vault.requestRecovery();
        vm.warp(uint256(vault.recoveryRequestedAt()) + RECOVERY_DELAY);
        vm.prank(OWNER);
        vault.completeRecovery();

        _false(vault.continuityActivated());
        _eq(vault.recoveryRequestedAt(), 0);
        _true(vault.lastHeartbeat() > firstHeartbeat);
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
    }

    function testUnderfundedVaultCanRecover() public {
        _depositAs(OWNER, 50 ether);
        uint256 id = _createAsOwner(OTHER, 30 ether, 1, uint64(block.timestamp));
        vault.executeCommitment(id);
        _false(vault.isFunded());
        _activateContinuity();

        vm.prank(OWNER);
        vault.requestRecovery();
        vm.warp(uint256(vault.recoveryRequestedAt()) + RECOVERY_DELAY);
        vm.prank(OWNER);
        vault.completeRecovery();
        _false(vault.isFunded());
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
    }

    function testRecoveryTimestampNarrowingIsProtected() public {
        vm.warp(type(uint64).max);
        vault.activateContinuity();
        vm.prank(OWNER);
        vault.requestRecovery();
        _eq(vault.recoveryRequestedAt(), type(uint64).max);

        vm.warp(uint256(type(uint64).max) + RECOVERY_DELAY);
        vm.prank(OWNER);
        vm.expectRevert(ContinuityVault.TimestampOverflow.selector);
        vault.completeRecovery();
        _true(vault.continuityActivated());
        _eq(vault.recoveryRequestedAt(), type(uint64).max);
    }

    function testRecoveryRequiresNewHeartbeatGraceCycleBeforeReactivation() public {
        _activateContinuity();
        vm.prank(OWNER);
        vault.requestRecovery();
        vm.warp(uint256(vault.recoveryRequestedAt()) + RECOVERY_DELAY);
        vm.prank(OWNER);
        vault.completeRecovery();

        vm.expectRevert(
            abi.encodeWithSelector(
                ContinuityVault.ContinuityNotEligible.selector, vault.continuityEligibleAt()
            )
        );
        vault.activateContinuity();

        vm.warp(vault.continuityEligibleAt());
        vault.activateContinuity();
        _true(vault.continuityActivated());
    }

    function testModeBoundariesIncludeContinuity() public {
        vm.warp(vault.activeUntil());
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
        vm.warp(vault.activeUntil() + 1);
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CAUTION));
        vm.warp(vault.continuityEligibleAt());
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CAUTION));
        vault.activateContinuity();
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CONTINUITY));
    }

    function testUnknownCommitmentRejectedAndCountEmpty() public {
        _eq(vault.commitmentCount(), 0);
        vm.expectRevert(abi.encodeWithSelector(ContinuityVault.InvalidCommitment.selector, 1));
        vault.getCommitment(1);
    }

    function _eq(uint256 actual, uint256 expected) private pure {
        require(actual == expected);
    }

    function _eq(address actual, address expected) private pure {
        require(actual == expected);
    }

    function _true(bool value) private pure {
        require(value);
    }

    function _false(bool value) private pure {
        require(!value);
    }

    function _depositAs(address depositor, uint256 amount) private {
        token.mint(depositor, amount);
        vm.startPrank(depositor);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();
    }

    function _createAsOwner(address recipient, uint128 amount, uint64 interval, uint64 firstDue)
        private
        returns (uint256 id)
    {
        vm.prank(OWNER);
        id = vault.createCommitment(recipient, amount, interval, firstDue);
    }

    function _activateContinuity() private {
        vm.warp(vault.continuityEligibleAt());
        vault.activateContinuity();
    }
}
