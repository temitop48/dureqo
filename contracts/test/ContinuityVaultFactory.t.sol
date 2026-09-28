// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ContinuityVault } from "../src/ContinuityVault.sol";
import { ContinuityVaultFactory } from "../src/ContinuityVaultFactory.sol";
import { Test } from "../lib/openzeppelin-contracts/lib/forge-std/src/Test.sol";

interface FactoryVm {
    function prank(address) external;
    function expectRevert(bytes calldata) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData)
        external;
    function etch(address target, bytes calldata code) external;
}

contract FactoryTestToken {
    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }
}

contract ContinuityVaultFactoryInvariantHandler {
    FactoryVm private constant VM =
        FactoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant INITIAL_CREATOR = address(0xBEEF);

    ContinuityVaultFactory public immutable factory;
    mapping(address creator => address vault) public recordedVault;
    address[] public successfulCreators;

    constructor(ContinuityVaultFactory factory_) {
        factory = factory_;

        VM.prank(INITIAL_CREATOR);
        address vault = factory.createVault();
        recordedVault[INITIAL_CREATOR] = vault;
        successfulCreators.push(INITIAL_CREATOR);
    }

    function createVault(uint256 seed) external {
        address creator = _creatorFor(seed);
        if (factory.vaultCreatedBy(creator) != address(0)) return;

        VM.prank(creator);
        address vault = factory.createVault();
        recordedVault[creator] = vault;
        successfulCreators.push(creator);
    }

    function successfulCreatorCount() external view returns (uint256) {
        return successfulCreators.length;
    }

    function successfulCreator(uint256 index) external view returns (address) {
        return successfulCreators[index];
    }

    function _creatorFor(uint256 seed) private view returns (address creator) {
        creator = address(uint160(uint256(keccak256(abi.encode(address(this), seed % 32)))));
        if (creator == address(0)) creator = address(1);
        if (creator == address(factory)) creator = address(2);
    }
}

contract ContinuityVaultFactoryTest is Test {
    FactoryVm private constant factoryVm =
        FactoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant CREATOR = address(0x1001);
    address private constant SECOND_CREATOR = address(0x1002);
    address private constant NEW_OWNER = address(0x1003);
    address private constant ASSET = 0xFFC95faa3d63Cde504a05B567C600B78C0b41892;

    ContinuityVaultFactory private factory;
    ContinuityVaultFactoryInvariantHandler private handler;

    function setUp() public {
        factory = new ContinuityVaultFactory();
        handler = new ContinuityVaultFactoryInvariantHandler(factory);
        targetContract(address(handler));

        FactoryTestToken token = new FactoryTestToken();
        factoryVm.etch(ASSET, address(token).code);
    }

    function testCanonicalConfiguration() public view {
        _eq(factory.ASSET(), ASSET);
        _eq(factory.HEARTBEAT_INTERVAL(), 300);
        _eq(factory.GRACE_PERIOD(), 180);
        _eq(factory.RECOVERY_DELAY(), 180);
    }

    function testCreateVaultInitializesExpectedStateAndEmitsExactEvent() public {
        factoryVm.expectEmit(true, false, true, true);
        emit ContinuityVaultFactory.VaultCreated(CREATOR, address(0), ASSET, 300, 180, 180);

        factoryVm.prank(CREATOR);
        address vaultAddress = factory.createVault();
        ContinuityVault vault = ContinuityVault(vaultAddress);

        _true(vaultAddress.code.length > 0);
        _eq(vault.owner(), CREATOR);
        _false(vault.owner() == address(factory));
        _eq(address(vault.usdg()), ASSET);
        _eq(vault.heartbeatInterval(), 300);
        _eq(vault.gracePeriod(), 180);
        _eq(vault.recoveryDelay(), 180);
        _eq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
        _false(vault.continuityActivated());
        _eq(vault.recoveryRequestedAt(), 0);
        _eq(vault.protectedBalance(), 0);
        _eq(vault.commitmentCount(), 0);
        _eq(factory.vaultCreatedBy(CREATOR), vaultAddress);
    }

    function testDuplicateCreationRevertsWithExactError() public {
        factoryVm.prank(CREATOR);
        address vaultAddress = factory.createVault();

        factoryVm.prank(CREATOR);
        factoryVm.expectRevert(
            abi.encodeWithSelector(
                ContinuityVaultFactory.VaultAlreadyExists.selector, CREATOR, vaultAddress
            )
        );
        factory.createVault();

        _eq(factory.vaultCreatedBy(CREATOR), vaultAddress);
    }

    function testDistinctCreatorsReceiveDistinctVaults() public {
        factoryVm.prank(CREATOR);
        address firstVault = factory.createVault();
        factoryVm.prank(SECOND_CREATOR);
        address secondVault = factory.createVault();

        _true(firstVault != secondVault);
        _eq(factory.vaultCreatedBy(CREATOR), firstVault);
        _eq(factory.vaultCreatedBy(SECOND_CREATOR), secondVault);
    }

    function testCreationRequiresNoApprovalAndFactoryReceivesNoAsset() public {
        factoryVm.prank(CREATOR);
        address vaultAddress = factory.createVault();

        (bool success, bytes memory data) =
            ASSET.staticcall(abi.encodeWithSignature("balanceOf(address)", address(factory)));
        _true(success);
        _eq(abi.decode(data, (uint256)), 0);
        _true(vaultAddress.code.length > 0);
    }

    function testFactoryHasNoFinancialPrivilegeOverCreatedVault() public {
        factoryVm.prank(CREATOR);
        address vaultAddress = factory.createVault();
        ContinuityVault vault = ContinuityVault(vaultAddress);

        factoryVm.prank(address(factory));
        factoryVm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OwnableUnauthorizedAccount(address)")), address(factory)
            )
        );
        vault.withdrawAvailable(CREATOR, 1);
    }

    function testTwoStepOwnershipTransferLeavesCreatorProvenanceStable() public {
        factoryVm.prank(CREATOR);
        address vaultAddress = factory.createVault();
        ContinuityVault vault = ContinuityVault(vaultAddress);

        factoryVm.prank(CREATOR);
        vault.transferOwnership(NEW_OWNER);
        _eq(vault.pendingOwner(), NEW_OWNER);

        factoryVm.prank(NEW_OWNER);
        vault.acceptOwnership();

        _eq(vault.owner(), NEW_OWNER);
        _eq(factory.vaultCreatedBy(CREATOR), vaultAddress);
        _eq(factory.vaultCreatedBy(NEW_OWNER), address(0));
    }

    function testRejectedCreationCannotCreatePhantomMapping() public {
        factoryVm.prank(CREATOR);
        address firstVault = factory.createVault();

        factoryVm.prank(CREATOR);
        factoryVm.expectRevert(
            abi.encodeWithSelector(
                ContinuityVaultFactory.VaultAlreadyExists.selector, CREATOR, firstVault
            )
        );
        factory.createVault();

        _eq(factory.vaultCreatedBy(CREATOR), firstVault);
    }

    function testFuzzArbitraryCreatorBecomesOwner(address creator) public {
        if (creator == address(0)) creator = CREATOR;

        factoryVm.prank(creator);
        address vaultAddress = factory.createVault();

        _eq(ContinuityVault(vaultAddress).owner(), creator);
        _eq(factory.vaultCreatedBy(creator), vaultAddress);
        _true(vaultAddress != address(factory));
    }

    function testFuzzDuplicateCreationAlwaysReverts(address creator) public {
        if (creator == address(0)) creator = CREATOR;

        factoryVm.prank(creator);
        address vaultAddress = factory.createVault();

        factoryVm.prank(creator);
        factoryVm.expectRevert(
            abi.encodeWithSelector(
                ContinuityVaultFactory.VaultAlreadyExists.selector, creator, vaultAddress
            )
        );
        factory.createVault();
    }

    function testFuzzFactoryNeverBecomesOwner(address creator) public {
        if (creator == address(0) || creator == address(factory)) creator = CREATOR;

        factoryVm.prank(creator);
        address vaultAddress = factory.createVault();

        _true(ContinuityVault(vaultAddress).owner() != address(factory));
    }

    function invariant_mappedVaultsAreDeployedAndFactoryIsNotOwner() public view {
        uint256 creatorCount = handler.successfulCreatorCount();
        _true(creatorCount > 0);
        for (uint256 i; i < creatorCount; ++i) {
            address creator = handler.successfulCreator(i);
            address recordedVault = handler.recordedVault(creator);
            address mappedVault = factory.vaultCreatedBy(creator);

            _true(recordedVault != address(0));
            _eq(mappedVault, recordedVault);
            _true(recordedVault.code.length > 0);
            _true(ContinuityVault(recordedVault).owner() != address(factory));
            _eq(address(ContinuityVault(recordedVault).usdg()), ASSET);
        }

        (bool success, bytes memory data) =
            ASSET.staticcall(abi.encodeWithSignature("balanceOf(address)", address(factory)));
        _true(success);
        _eq(abi.decode(data, (uint256)), 0);
    }

    function invariant_creatorProvenanceIsNotOverwritten() public view {
        uint256 creatorCount = handler.successfulCreatorCount();
        for (uint256 i; i < creatorCount; ++i) {
            address creator = handler.successfulCreator(i);
            _eq(factory.vaultCreatedBy(creator), handler.recordedVault(creator));
        }
    }

    function _eq(address actual, address expected) private pure {
        require(actual == expected, "address mismatch");
    }

    function _eq(uint256 actual, uint256 expected) private pure {
        require(actual == expected, "uint mismatch");
    }

    function _true(bool value) private pure {
        require(value, "expected true");
    }

    function _false(bool value) private pure {
        require(!value, "expected false");
    }
}
