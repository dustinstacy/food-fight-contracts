//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { AssetVault } from "@contracts/AssetVault.sol";
import { AssetRental } from "@contracts/AssetRental.sol";
import { AssetRentalTestHelper } from "./helpers/AssetRentalTestHelper.sol";

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetAuctionConstructorTest is AssetRentalTestHelper {
    function test_constructor() public view {
        // Check that the vault address is set correctly
        address expectedAddress = address(vault);
        address actualAddress = rentalContract.getAssetVaultAddress();
        assertEq(expectedAddress, actualAddress);

        // Check the rental asset count is 0
        assertEq(0, rentalContract.getRentalAssetCount());
    }
}

///////////////////////////////////////////////////////////
///                RENTAL OWNER TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetRentalCreateRentalTest is AssetRentalTestHelper {
    function test_createRental() public {
        vm.prank(userA);

        // Check that the RentalAssetPosted event was emitted
        vm.expectEmit(false, false, false, false, address(rentalContract));
        emit AssetRental.RentalAssetPosted(userA, 1);
        rentalContract.createRental(ASSET_ONE_ID, 10, ONE_HOUR_IN_BLOCKS);

        // Check that the rental asset count was incremented
        uint256 rentalAssetCount = rentalContract.getRentalAssetCount();
        assertEq(rentalAssetCount, 1);

        AssetRental.RentalAsset memory rentalAsset = rentalContract.getRentalAsset(1);
        address owner = rentalAsset.owner;
        address renter = rentalAsset.renter;
        uint256 assetId = rentalAsset.assetId;
        uint256 rentalPrice = rentalAsset.price;
        uint256 blocksDuration = rentalAsset.blocksDuration;
        uint256 expiration = rentalAsset.expiration;
        uint256 rentalStatus = uint256(rentalAsset.status);

        // Check that the rental asset was created correctly
        assertEq(owner, userA);
        assertEq(renter, address(0));
        assertEq(assetId, ASSET_ONE_ID);
        assertEq(rentalPrice, 10);
        assertEq(blocksDuration, ONE_HOUR_IN_BLOCKS);
        assertEq(expiration, 0);
        assertEq(rentalStatus, availableStatus);

        // Check that userA's vault balance was updated correctly
        uint256 userAVaultBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAVaultBalance, userAStartingVaultAssetOneBalance - 1);
    }

    function test_createRental_RevertsIf_InsufficientBalance() public {
        vm.prank(userB);

        // Check that the function reverts with the AssetVaultInsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(AssetVault.AssetVaultInsufficientBalance.selector, userB, 0, 1, ASSET_ONE_ID)
        );
        rentalContract.createRental(ASSET_ONE_ID, 10, ONE_HOUR_IN_BLOCKS);
    }
}

contract AssetRentalUnlistRentalTest is AssetRentalTestHelper {
    function setUp() public override {
        super.setUp();

        // Create a rental for userA
        createRentalHelper(userA, ASSET_ONE_ID, 10, ONE_HOUR_IN_BLOCKS);
    }

    function test_unlistRental() public {
        vm.prank(userA);

        // Check that the RentalAssetUnlisted event was emitted
        vm.expectEmit(false, false, false, false, address(rentalContract));
        emit AssetRental.RentalAssetUnlisted(userA, 1);
        rentalContract.unlistRental(1);

        // Check that the rental status was updated correctly
        uint256 status = uint256(rentalContract.getRentalAsset(1).status);
        assertEq(status, unavailableStatus);

        // Check that userA's vault balance was updated correctly
        uint256 userAVaultBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAVaultBalance, userAStartingVaultAssetOneBalance + 1);
    }

    function test_unlistRental_RevertsIf_RentalNotExpired() public {
        rentAssetHelper(userB, 1);

        vm.prank(userA);

        // Check that the function reverts with the AssetRentalRentalNotAvailable error
        vm.expectRevert(abi.encodeWithSelector(AssetRental.AssetRentalNotAvailable.selector, rentedStatus));
        rentalContract.unlistRental(1);
    }

    function test_unlistRental_RevertsIf_NotTheRentalOwner() public {
        vm.prank(userB);

        // Check that the function reverts with the AssetRentalNotTheOwner error
        vm.expectRevert(abi.encodeWithSelector(AssetRental.AssetRentalNotTheOwner.selector, userB, userA));
        rentalContract.unlistRental(1);
    }

    function test_unlistRental_RevertsIf_AlreadyUnlisted() public {
        unlistRentalHelper(userA, 1);

        // Check that the function reverts with the AssetRentalRentalNotAvailable error
        vm.expectRevert(abi.encodeWithSelector(AssetRental.AssetRentalNotAvailable.selector, unavailableStatus));
        rentalContract.unlistRental(1);
    }
}

contract AssetRentalUpdateRentalTest is AssetRentalTestHelper {
    uint256 newRentalPrice = 20;
    uint256 newRentalDuration = 2 * ONE_HOUR_IN_BLOCKS;

    function setUp() public override {
        super.setUp();

        // Create a rental for userA
        createRentalHelper(userA, ASSET_ONE_ID, 10, ONE_HOUR_IN_BLOCKS);
    }

    function test_updateRental() public {
        vm.prank(userA);

        // Check that the RentalAssetUpdated event was emitted
        vm.expectEmit(false, false, false, false, address(rentalContract));
        emit AssetRental.RentalAssetUpdated(userA, 1);
        rentalContract.updateRental(1, 20, 2 * ONE_HOUR_IN_BLOCKS);

        // Check that the rental asset price was updated correctly
        uint256 price = rentalContract.getRentalAsset(1).price;
        assertEq(price, newRentalPrice);

        // Check that the rental asset duration was updated correctly
        uint256 duration = rentalContract.getRentalAsset(1).blocksDuration;
        assertEq(duration, newRentalDuration);
    }

    function test_updateRental_RevertsIf_RentalNotExpired() public {
        rentAssetHelper(userB, 1);

        vm.prank(userA);

        // Check that the function reverts with the AssetRentalRentalNotAvailable error
        vm.expectRevert(abi.encodeWithSelector(AssetRental.AssetRentalNotAvailable.selector, rentedStatus));
        rentalContract.updateRental(1, newRentalPrice, newRentalDuration);
    }

    function test_updateRental_RevertsIf_NotTheRentalOwner() public {
        vm.prank(userB);

        // Check that the function reverts with the AssetRentalNotTheOwner error
        vm.expectRevert(abi.encodeWithSelector(AssetRental.AssetRentalNotTheOwner.selector, userB, userA));
        rentalContract.updateRental(1, newRentalPrice, newRentalDuration);
    }

    function test_updateRental_RevertsIf_NotListed() public {
        unlistRentalHelper(userA, 1);

        // Check that the function reverts with the AssetRentalRentalNotAvailable error
        vm.expectRevert(abi.encodeWithSelector(AssetRental.AssetRentalNotAvailable.selector, unavailableStatus));
        rentalContract.updateRental(1, newRentalPrice, newRentalDuration);
    }
}

///////////////////////////////////////////////////////////
///                  RENTER TESTS                       ///
///////////////////////////////////////////////////////////

contract AssetRentalRentAssetTest is AssetRentalTestHelper {
    function setUp() public override {
        super.setUp();

        // Create a rental for userA
        createRentalHelper(userA, ASSET_ONE_ID, 10, ONE_HOUR_IN_BLOCKS);
    }

    function test_rentAsset() public {
        vm.prank(userB);

        // Check that the RentalAssetRented event was emitted
        vm.expectEmit(false, false, false, false, address(rentalContract));
        emit AssetRental.RentalAssetRented(userB, 1, block.timestamp);
        rentalContract.rentAsset(1);

        // Check that userB's vault balance was updated correctly
        uint256 userBEndingVaultIGCBalance = vault.balanceOf(userB, IGC_TOKEN_ID);
        assertEq(userBEndingVaultIGCBalance, userBStartingVaultIGCBalance - 10);

        // Check that userA's vault balance was updated correctly
        uint256 userAEndingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAEndingVaultIGCBalance, userAStartingVaultIGCBalance + 10);

        // Check that the rental asset status was updated correctly
        uint256 status = uint256(rentalContract.getRentalAsset(1).status);
        assertEq(status, rentedStatus);

        // Check that the rental asset renter was updated correctly
        address renter = rentalContract.getRentalAsset(1).renter;
        assertEq(renter, userB);

        // Check that the rental asset expiration was updated correctly
        uint256 expiration = rentalContract.getRentalAsset(1).expiration;
        assertEq(expiration, block.timestamp + ONE_HOUR_IN_BLOCKS);

        // Check that userB's rented asset's were updated correctly
        uint256 rentedAssetCount = rentalContract.getRentedAssetBalance(userB, rentalContract.getRentalAsset(1).assetId);
        assertEq(rentedAssetCount, 1);
    }

    function test_rentAsset_RevertsIf_AlreadyRented() public {
        rentAssetHelper(userB, 1);

        vm.prank(userC);

        // Check that the function reverts with the AssetRentalRentalNotAvailable error
        vm.expectRevert(abi.encodeWithSelector(AssetRental.AssetRentalNotAvailable.selector, rentedStatus));
        rentalContract.rentAsset(1);
    }

    function test_rentAsset_RevertsIf_NotListed() public {
        unlistRentalHelper(userA, 1);

        vm.prank(userB);

        // Check that the function reverts with the AssetRentalRentalNotAvailable error
        vm.expectRevert(abi.encodeWithSelector(AssetRental.AssetRentalNotAvailable.selector, unavailableStatus));
        rentalContract.rentAsset(1);
    }

    function test_rentAsset_RevertsIf_InsufficientBalance() public {
        createRentalHelper(userA, ASSET_TWO_ID, ONE_MILLION + 1, ONE_HOUR_IN_BLOCKS);

        vm.prank(userB);

        // Check that the function reverts with the AssetVaultInsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetVault.AssetVaultInsufficientBalance.selector, userB, ONE_MILLION, ONE_MILLION + 1, IGC_TOKEN_ID
            )
        );
        rentalContract.rentAsset(2);
    }
}

contract AssetRentalCheckRentalStatus is AssetRentalTestHelper {
    function setUp() public override {
        super.setUp();

        // Create a rental for userA
        createRentalHelper(userA, ASSET_ONE_ID, 10, ONE_HOUR_IN_BLOCKS);

        // Rent the asset for userB
        rentAssetHelper(userB, 1);
    }

    function test_checkRentalStatus() public {
        // Check that the rental status is true
        bool rentalStatus = rentalContract.checkRentalStatus(1);
        assertEq(rentalStatus, true);
    }

    function test_checkRentalStatus_WhenExpried() public {
        vm.roll(block.timestamp + ONE_HOUR_IN_BLOCKS + 1);

        // Check that the RentalAssetReleased event was emitted
        vm.expectEmit(false, false, false, false, address(rentalContract));
        emit AssetRental.RentalAssetRelisted(userB, 1);
        bool rentalStatus = rentalContract.checkRentalStatus(1);

        // Check that the rental status is false
        assertEq(rentalStatus, false);

        // Check that userB's rented asset's were updated correctly
        uint256 rentedAssetCount = rentalContract.getRentedAssetBalance(userB, rentalContract.getRentalAsset(1).assetId);
        assertEq(rentedAssetCount, 0);

        // Check that the rental asset status was updated correctly
        uint256 status = uint256(rentalContract.getRentalAsset(1).status);
        assertEq(status, availableStatus);

        // Check that the rental asset renter was updated correctly
        address renter = rentalContract.getRentalAsset(1).renter;
        assertEq(renter, address(0));

        // Check that the rental asset expiration was updated correctly
        uint256 expiration = rentalContract.getRentalAsset(1).expiration;
        assertEq(expiration, 0);
    }
}

///////////////////////////////////////////////////////////
///                VIEW FUNCTION TESTS                  ///
///////////////////////////////////////////////////////////

contract AssetRentalViewFunctionsTest is AssetRentalTestHelper {
    function setUp() public override {
        super.setUp();

        // Create a rental for userA
        createRentalHelper(userA, ASSET_ONE_ID, 10, ONE_HOUR_IN_BLOCKS);

        // Rent the asset for userB
        rentAssetHelper(userB, 1);
    }

    function test_getRentalAsset() public view {
        AssetRental.RentalAsset memory rentalAsset = rentalContract.getRentalAsset(1);
        address owner = rentalAsset.owner;
        address renter = rentalAsset.renter;
        uint256 assetId = rentalAsset.assetId;
        uint256 rentalPrice = rentalAsset.price;
        uint256 blocksDuration = rentalAsset.blocksDuration;
        uint256 expiration = rentalAsset.expiration;
        uint256 rentalStatus = uint256(rentalAsset.status);

        // Check that the rental asset was created correctly
        assertEq(owner, userA);
        assertEq(renter, userB);
        assertEq(assetId, ASSET_ONE_ID);
        assertEq(rentalPrice, 10);
        assertEq(blocksDuration, ONE_HOUR_IN_BLOCKS);
        assertEq(expiration, block.timestamp + ONE_HOUR_IN_BLOCKS);
        assertEq(rentalStatus, rentedStatus);
    }

    function test_getRentedAsset() public view {
        // Check that the rented asset count is correct
        uint256 rentedAssetCount = rentalContract.getRentedAssetBalance(userB, ASSET_ONE_ID);
        assertEq(rentedAssetCount, 1);
    }

    function test_getVaultAddress() public view {
        // Check that the vault contract address is correct
        address vault = rentalContract.getAssetVaultAddress();
        assertEq(address(vault), vault);
    }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetRentalERC1155ReceiverTest is AssetRentalTestHelper {
    function test_onERC1155Received() public view {
        // Check that the correct selector was returned
        bytes4 expectedSelector = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        bytes4 returnedSelector = factory.onERC1155Received(address(0), address(0), 0, 0, "");
        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        // Check that the correct selector was returned
        bytes4 expectedSelector = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        bytes4 returnedSelector =
            factory.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");
        assertEq(returnedSelector, expectedSelector);
    }
}

///////////////////////////////////////////////////////////
///               IERC165 INTERFACE TESTS               ///
///////////////////////////////////////////////////////////

contract AssetRentalERC165Test is AssetRentalTestHelper {
    function test_supportsInterfaceIdIERC165() public view {
        // Check that the contract supports the IERC165 interface
        bytes4 expectedSelector = 0x01ffc9a7;
        bool returnedSelector = rentalContract.supportsInterface(expectedSelector);
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceIdIERC1155Receiver() public view {
        // Check that the contract supports the IERC1155Receiver interface
        bytes4 expectedSelector = 0x4e2312e0;
        bool returnedSelector = rentalContract.supportsInterface(expectedSelector);
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceBadSelector() public view {
        // Check that the contract throws false for an unsupported interface
        bytes4 badSelector = bytes4(keccak256("badSelector"));
        bool returnedSelector = rentalContract.supportsInterface(badSelector);
        assertEq(returnedSelector, false);
    }
}
