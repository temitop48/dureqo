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
}
