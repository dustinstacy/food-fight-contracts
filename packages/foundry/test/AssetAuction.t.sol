//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { AssetVault } from "@contracts/AssetVault.sol";
import { AssetAuction } from "@contracts/AssetAuction.sol";
import { AssetAuctionTestHelper } from "./helpers/AssetAuctionTestHelper.sol";

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetAuctionConstructorTest is AssetAuctionTestHelper {
    function test_constructor() public view {
        // Check that the factory address is correct
        address expectedFactoryAddress = address(factory);
        address actualFactoryAddress = auction.getAssetFactoryAddress();
        assertEq(expectedFactoryAddress, actualFactoryAddress);

        // Check that the vault address is correct
        address expectedVaultAddress = address(vault);
        address actualVaultAddress = auction.getAssetVaultAddress();
        assertEq(expectedVaultAddress, actualVaultAddress);

        // Check that the auction count is 0
        assertEq(0, auction.getAuctionCount());
    }
}

///////////////////////////////////////////////////////////
///              SELLER FUNCTION TESTS                  ///
///////////////////////////////////////////////////////////

contract AssetAuctionCreateAuctionTest is AssetAuctionTestHelper {
    function test_createAuction() public {
        vm.prank(userA);
        auction.createAuction(ASSET_ONE_ID, 10, ONE_HOUR);

        // Destructure the Auction struct to get all it's values
        // Note: The auction ID is 1 because it is the first auction created
        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        (
            address seller,
            address highestBidder,
            address winningBidder,
            uint256 assetId,
            uint256 reservePrice,
            uint256 deadline,
            uint256 highestBid,
            uint256 winningBid,
            uint256 status
        ) = (
            auctionData.seller,
            auctionData.highestBidder,
            auctionData.winningBidder,
            auctionData.assetId,
            auctionData.reservePrice,
            auctionData.deadline,
            auctionData.highestBid,
            auctionData.winningBid,
            uint256(auctionData.status)
        );

        // Check that the auction was created correctly
        assertEq(userA, seller);
        assertEq(ASSET_ONE_ID, assetId);
        assertEq(10, reservePrice);
        assertEq(ONE_HOUR, deadline);
        assertEq(0, highestBid);
        assertEq(address(0), highestBidder);
        assertEq(0, winningBid);
        assertEq(address(0), winningBidder);
        assertEq(openStatus, status);
    }

    function test_createAuction_AuctionCountIncremented() public {
        createAuctionHelper();

        // Check that the auction count was incremented
        uint256 auctionCount = auction.getAuctionCount();
        assertEq(1, auctionCount);
    }

    function test_createAuction_AssetLocked() public {
        createAuctionHelper();

        // Check that userA's vault balance was updated
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAEndingVaultAssetOneBalance, userAStartingVaultAssetOneBalance - 1);
    }

    function test_createAuction_EventEmitted() public {
        vm.prank(userA);

        // Check that the AuctionCreated event was emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.AuctionCreated(userA, 1, ASSET_ONE_ID, 10, ONE_HOUR);
        auction.createAuction(ASSET_ONE_ID, 10, ONE_HOUR);
    }

    function test_createAuction_RevertsIf_InsufficientBalance() public {
        vm.prank(userA);

        // Check that the function reverts with the AssetVaultInsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(AssetVault.AssetVaultInsufficientBalance.selector, userA, 0, 1, ASSET_THREE_ID)
        );
        auction.createAuction(ASSET_THREE_ID, 10, ONE_HOUR);
    }
}

contract AssetAustionCancelAuctionTest is AssetAuctionTestHelper {
    function setUp() public override {
        super.setUp();
        createAuctionHelper();

        // Update the starting vault balance for userA
        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
    }

    function test_cancelAuction() public {
        vm.prank(userA);
        auction.cancelAuction(1);

        // Check that the auction status was updated
        uint256 status = uint256(auction.getAuction(1).status);
        assertEq(canceledStatus, status);

        // Check that userA's vault balance was updated
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAEndingVaultAssetOneBalance, userAStartingVaultAssetOneBalance + 1);
    }

    function test_cancelAuction_EventEmitted() public {
        vm.prank(userA);

        // Check that the AuctionCanceled event is emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.AuctionCanceled(1);
        auction.cancelAuction(1);
    }

    function test_cancelAuction_RevertsIf_NotOpenStatus() public {
        vm.startPrank(userA);
        // Note: The auction status is now canceled after the first call
        auction.cancelAuction(1);

        // Check that the function reverts with the AssetAuctionNotOpen error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotOpen.selector, canceledStatus));
        auction.cancelAuction(1);
        vm.stopPrank();
    }

    function test_cancelAuction_RevertsIf_DeadlinePassed() public {
        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 deadline = auctionData.deadline;

        vm.warp(ONE_HOUR + 1);
        vm.prank(userA);

        // Check that the function reverts with the AssetAuctionDeadlineHasPassed error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionDeadlineHasPassed.selector, deadline));
        auction.cancelAuction(1);
    }

    function test_cancelAuction_RevertsIf_NotTheSeller() public {
        vm.startPrank(userB);

        // Check that the function reverts with the AssetAuctionNotTheSeller error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotTheSeller.selector, userB, userA));
        auction.cancelAuction(1);
    }
}

///////////////////////////////////////////////////////////
///              BIDDER FUNCTION TESTS                  ///
///////////////////////////////////////////////////////////

contract AssetAuctionPlaceBidTest is AssetAuctionTestHelper {
    function setUp() public override {
        super.setUp();
        createAuctionHelper();
    }

    function test_placeBid() public {
        vm.prank(userB);
        auction.placeBid(1, 10);

        // Check that the highest bidder was updated
        address highestBidder = auction.getAuction(1).highestBidder;
        assertEq(userB, highestBidder);

        // Check that the highest bid was updated
        // Note: The highest bid is 10 as userB placed a bid of 10
        uint256 highestBid = auction.getAuction(1).highestBid;
        assertEq(10, highestBid);
    }

    function test_placedBid_AssetLocked() public {
        vm.prank(userB);
        auction.placeBid(1, 10);

        // Check that userB's IGC balance was updated
        uint256 userBEndingVaultIGCBalance = vault.balanceOf(userB, IGC_TOKEN_ID);
        assertEq(userBEndingVaultIGCBalance, userBStartingVaultIGCBalance - 10);
    }

    function test_placeBId_AssetUnlockedWhenOutbid() public {
        placeBidHelper(userB, ASSET_ONE_ID, 10);
        placeBidHelper(userC, ASSET_ONE_ID, 11);

        // Check that userB's IGC balance was updated to return the locked assets
        uint256 userBEndingVaultIGCBalance = vault.balanceOf(userB, IGC_TOKEN_ID);
        assertEq(userBEndingVaultIGCBalance, userBStartingVaultIGCBalance);
    }

    function test_placeBid_EventEmitted() public {
        vm.prank(userB);

        // Check that the BidPlaced event is emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.BidPlaced(userB, 1, 10);
        auction.placeBid(1, 10);
    }

    function test_placeBid_RevertsIf_NotOpenStatus() public {
        cancelAuctionHelper();

        vm.prank(userB);

        // Check that the function reverts with the AssetAuctionNotOpen error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotOpen.selector, canceledStatus));
        auction.placeBid(1, 10);
    }

    function test_placeBid_RevertsIf_BidNotHigherThanHighestBid() public {
        placeBidHelper(userB, ASSET_ONE_ID, 10);

        vm.prank(userC);

        // Check that the function reverts with the AssetAuctionBidBelowHighestBid error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionBidBelowHighestBid.selector, 1, 10));
        auction.placeBid(1, 1);
    }

    function test_placeBid_RevertsIf_DeadlinePassed() public {
        vm.warp(ONE_HOUR + 1);
        vm.prank(userB);

        // Check that the function reverts with the AssetAuctionDeadlineHasPassed error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionDeadlineHasPassed.selector, ONE_HOUR));
        auction.placeBid(1, 10);
    }

    function test_placeBid_RevertsIf_InsufficientBalance() public {
        vm.prank(userB);

        // Check that the function reverts with the AssetVaultInsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetVault.AssetVaultInsufficientBalance.selector, userB, ONE_MILLION, ONE_MILLION + 1, IGC_TOKEN_ID
            )
        );
        auction.placeBid(1, ONE_MILLION + 1);
    }
}

///////////////////////////////////////////////////////////
///            AUCTION OVER FUNCTION TESTS              ///
///////////////////////////////////////////////////////////

contract AssetAuctionCompleteAuctionTest is AssetAuctionTestHelper {
    function setUp() public override {
        super.setUp();
        createAuctionHelper();

        // Update the starting vault balance for userA
        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
    }

    function test_completeAuction() public {
        placeBidHelper(userB, ASSET_ONE_ID, 10);
        vm.warp(ONE_HOUR + 1);
        vm.prank(userA);
        auction.completeAuction(1);

        // Check that the auction status was updated
        uint256 status = uint256(auction.getAuction(1).status);
        assertEq(endedStatus, status);

        // Check that the winning bid was updated
        uint256 winningBid = auction.getAuction(1).winningBid;
        assertEq(10, winningBid);

        // Check that the winning bidder was updated
        address winningBidder = auction.getAuction(1).winningBidder;
        assertEq(userB, winningBidder);

        // Check that userA's vault balances were updated
        // Note: userA's asset one balance should be the same because it was previously locked
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAEndingVaultAssetOneBalance, userAStartingVaultAssetOneBalance);

        uint256 userAEndingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAEndingVaultIGCBalance, userAStartingVaultIGCBalance + winningBid);

        // Check that userB's vault balances were updated
        uint256 userBEndingVaultAssetOneBalance = vault.balanceOf(userB, ASSET_ONE_ID);
        assertEq(userBEndingVaultAssetOneBalance, userBStartingVaultAssetOneBalance + 1);

        uint256 userBEndingVaultIGCBalance = vault.balanceOf(userB, IGC_TOKEN_ID);
        assertEq(userBEndingVaultIGCBalance, userBStartingVaultIGCBalance - winningBid);
    }

    function test_completeAuction_WhenReserveNotMet() public {
        vm.warp(ONE_HOUR + 1);
        vm.prank(userA);
        auction.completeAuction(1);

        // Check that the auction status was updated
        uint256 status = uint256(auction.getAuction(1).status);
        assertEq(reserveNotMetStatus, status);

        // Check that userA's vault balance was updated
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAEndingVaultAssetOneBalance, userAStartingVaultAssetOneBalance + 1);
    }

    function test_completeAuction_EventEmitted() public {
        placeBidHelper(userB, ASSET_ONE_ID, 10);
        vm.warp(ONE_HOUR + 1);
        vm.prank(userA);

        // Check that the AuctionEnded event is emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.AuctionEnded(1, userB, 10);
        auction.completeAuction(1);
    }

    function test_completeAuction_RevertsIf_NotOpenStatus() public {
        placeBidHelper(userB, ASSET_ONE_ID, 10);
        vm.warp(ONE_HOUR + 1);
        vm.startPrank(userA);
        auction.completeAuction(1);

        // Check that the function reverts with the AssetAuctionNotOpen error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotOpen.selector, endedStatus));
        auction.completeAuction(1);
        vm.stopPrank();
    }

    function test_completeAuction_RevertsIf_DeadlineNotPassed() public {
        placeBidHelper(userB, ASSET_ONE_ID, 10);

        vm.prank(userA);

        // Check that the function reverts with the AssetAuctionDeadlineNotPassed error
        uint256 deadline = auction.getAuction(1).deadline;
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionDeadlineNotPassed.selector, deadline));
        auction.completeAuction(1);
    }
}

///////////////////////////////////////////////////////////
///                VIEW FUNCTION TESTS                  ///
///////////////////////////////////////////////////////////

contract AssetAuctionViewFunctionsTest is AssetAuctionTestHelper {
    function setUp() public override {
        super.setUp();
        createAuctionHelper();
    }

    function test_getAuction() public view {
        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        (
            address seller,
            address highestBidder,
            address winningBidder,
            uint256 assetId,
            uint256 reservePrice,
            uint256 deadline,
            uint256 highestBid,
            uint256 winningBid,
            uint256 status
        ) = (
            auctionData.seller,
            auctionData.highestBidder,
            auctionData.winningBidder,
            auctionData.assetId,
            auctionData.reservePrice,
            auctionData.deadline,
            auctionData.highestBid,
            auctionData.winningBid,
            uint256(auctionData.status)
        );

        // Check that the auction was retrieved correctly
        assertEq(userA, seller);
        assertEq(address(0), highestBidder);
        assertEq(address(0), winningBidder);
        assertEq(ASSET_ONE_ID, assetId);
        assertEq(10, reservePrice);
        assertEq(ONE_HOUR, deadline);
        assertEq(0, highestBid);
        assertEq(0, winningBid);
        assertEq(openStatus, status);
    }

    function test_getAuctionCount() public view {
        // Check that the auction count is correct
        uint256 auctionCount = auction.getAuctionCount();
        assertEq(1, auctionCount);
    }

    function test_getIGCTokenId() public view {
        // Check that the IGC token ID is correct
        uint256 igcTokenId = auction.getIGCTokenId();
        assertEq(IGC_TOKEN_ID, igcTokenId);
    }

    function test_getFactoryAddress() public view {
        // Check that the factory contract address is correct
        address factory = auction.getAssetFactoryAddress();
        assertEq(address(factory), factory);
    }

    function test_getVaultAddress() public view {
        // Check that the vault contract address is correct
        address vault = auction.getAssetVaultAddress();
        assertEq(address(vault), vault);
    }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetAuctionERC1155ReceiverTest is AssetAuctionTestHelper {
    function test_onERC1155Received() public view {
        // Check that the correct selector was returned
        bytes4 expectedSelector = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        bytes4 returnedSelector = auction.onERC1155Received(address(0), address(0), 0, 0, "");
        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        // Check that the correct selector was returned
        bytes4 expectedSelector = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        bytes4 returnedSelector =
            auction.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");
        assertEq(returnedSelector, expectedSelector);
    }
}

///////////////////////////////////////////////////////////
///               IERC165 INTERFACE TESTS               ///
///////////////////////////////////////////////////////////

contract AssetAuctionERC165Test is AssetAuctionTestHelper {
    function test_supportsInterfaceIdIERC165() public view {
        // Check that the contract supports the IERC165 interface
        bytes4 expectedSelector = 0x01ffc9a7;
        bool returnedSelector = auction.supportsInterface(expectedSelector);
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceIdIERC1155Receiver() public view {
        // Check that the contract supports the IERC1155Receiver interface
        bytes4 expectedSelector = 0x4e2312e0;
        bool returnedSelector = auction.supportsInterface(expectedSelector);
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceBadSelector() public view {
        // Check that the contract throws false for an unsupported interface
        bytes4 badSelector = bytes4(keccak256("badSelector"));
        bool returnedSelector = auction.supportsInterface(badSelector);
        assertEq(returnedSelector, false);
    }
}
