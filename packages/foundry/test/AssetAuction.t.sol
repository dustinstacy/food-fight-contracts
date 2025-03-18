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
        address expectedFactoryAddress = address(factory);
        address expectedVaultAddress = address(vault);
        address actualFactoryAddress = auction.getAssetFactoryAddress();
        address actualVaultAddress = auction.getAssetVaultAddress();

        // Check that the factory and vault addresses are correct
        assertEq(expectedFactoryAddress, actualFactoryAddress);
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

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        address seller = auctionData.seller;
        uint256 assetId = auctionData.assetId;
        uint256 reservePrice = auctionData.reservePrice;
        uint256 deadline = auctionData.deadline;
        uint256 highestBid = auctionData.highestBid;
        address highestBidder = auctionData.highestBidder;
        uint256 winningBid = auctionData.winningBid;
        address winningBidder = auctionData.winningBidder;
        uint256 status = uint256(auctionData.status);

        // Check that the auction data is correct
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

        uint256 auctionCount = auction.getAuctionCount();

        // Check that the auction count was incremented
        assertEq(1, auctionCount);
    }

    function test_createAuction_AssetLocked() public {
        createAuctionHelper();

        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);

        // Check that userA's asset balance was updated
        assertEq(userAEndingVaultAssetOneBalance, userAStartingVaultAssetOneBalance - 1);
    }

    function test_createAuction_EventEmitted() public {
        vm.prank(userA);

        // Check that the AuctionCreated event is emitted
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

        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
    }

    function test_cancelAuction() public {
        vm.prank(userA);
        auction.cancelAuction(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 status = uint256(auctionData.status);
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);

        // Check that the auction status was updated
        assertEq(canceledStatus, status);
        // Check that userA's asset balance was updated
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
        cancelAuctionHelper();

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 status = uint256(auctionData.status);

        vm.prank(userA);

        // Check that the function reverts with the AssetAuctionNotOpen error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotOpen.selector, status));
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

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        address highestBidder = auctionData.highestBidder;
        uint256 highestBid = auctionData.highestBid;

        // Check that the highest bidder was updated
        assertEq(userB, highestBidder);
        // Check that the highest bid was updated
        assertEq(10, highestBid);
    }

    function test_placedBid_AssetLocked() public {
        vm.prank(userB);
        auction.placeBid(1, 10);

        uint256 userBEndingVaultIGCBalance = vault.balanceOf(userB, IGC_TOKEN_ID);

        // Check that userB's IGC balance was updated
        assertEq(userBEndingVaultIGCBalance, userBStartingVaultIGCBalance - 10);
    }

    function test_placeBId_AssetUnlockedWhenOutbid() public {
        placeBidHelper(userB, ASSET_ONE_ID, 10);
        placeBidHelper(userC, ASSET_ONE_ID, 11);

        uint256 userBEndingVaultIGCBalance = vault.balanceOf(userB, IGC_TOKEN_ID);

        // Check that userB's IGC balance was updated to return the locked assets
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

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 status = uint256(auctionData.status);

        vm.prank(userB);

        // Check that the function reverts with the AssetAuctionNotOpen error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotOpen.selector, status));
        auction.placeBid(1, 10);
    }

    function test_placeBid_RevertsIf_BidNotHigherThanHighestBid() public {
        placeBidHelper(userB, ASSET_ONE_ID, 10);

        vm.prank(userC);
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionBidNotHigherThanHighestBid.selector, 1, 10));
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

        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
    }

    function test_completeAuction() public {
        placeBidHelper(userB, ASSET_ONE_ID, 10);
        vm.warp(ONE_HOUR + 1);
        vm.prank(userA);
        auction.completeAuction(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 winningBid = auctionData.winningBid;
        address winningBidder = auctionData.winningBidder;
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        uint256 userAEndingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        uint256 userBEndingVaultAssetOneBalance = vault.balanceOf(userB, ASSET_ONE_ID);
        uint256 userBEndingVaultIGCBalance = vault.balanceOf(userB, IGC_TOKEN_ID);

        // Check that the winning bid and bidder were updated
        assertEq(10, winningBid);
        assertEq(userB, winningBidder);

        // Check that both user's balances were updated
        assertEq(userAEndingVaultAssetOneBalance, userAStartingVaultAssetOneBalance);
        assertEq(userAEndingVaultIGCBalance, userAStartingVaultIGCBalance + winningBid);
        assertEq(userBEndingVaultAssetOneBalance, userBStartingVaultAssetOneBalance + 1);
        assertEq(userBEndingVaultIGCBalance, userBStartingVaultIGCBalance - winningBid);
    }

    function test_completeAuction_WhenReserveNotMet() public {
        vm.warp(ONE_HOUR + 1);
        vm.prank(userA);
        auction.completeAuction(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 status = uint256(auctionData.status);
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);

        // Check that the auction status was updated
        assertEq(reserveNotMetStatus, status);
        // Check that userA's asset balance was updated
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

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 status = uint256(auctionData.status);

        // Check that the function reverts with the AssetAuctionNotOpen error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotOpen.selector, status));
        auction.completeAuction(1);
        vm.stopPrank();
    }

    function test_completeAuction_RevertsIf_DeadlineNotPassed() public {
        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 deadline = auctionData.deadline;

        placeBidHelper(userB, ASSET_ONE_ID, 10);
        vm.prank(userA);

        // Check that the function reverts with the AssetAuctionDeadlineNotPassed error
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
        address seller = auctionData.seller;
        address highestBidder = auctionData.highestBidder;
        address winningBidder = auctionData.winningBidder;
        uint256 assetId = auctionData.assetId;
        uint256 reservePrice = auctionData.reservePrice;
        uint256 deadline = auctionData.deadline;
        uint256 highestBid = auctionData.highestBid;
        uint256 winningBid = auctionData.winningBid;
        uint256 status = uint256(auctionData.status);

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

    function test_getAuctionSeller() public view {
        address seller = auction.getAuctionSeller(1);

        // Check that the seller is correct
        assertEq(userA, seller);
    }

    function test_getAuctionHighestBidder() public view {
        address highestBidder = auction.getAuctionHighestBidder(1);

        // Check that the highest bidder is correct
        assertEq(address(0), highestBidder);
    }

    function test_getAuctionWinningBidder() public view {
        address winningBidder = auction.getAuctionWinningBidder(1);

        // Check that the winning bidder is correct
        assertEq(address(0), winningBidder);
    }

    function test_getAuctionAssetId() public view {
        uint256 assetId = auction.getAuctionAssetId(1);

        // Check that the asset token ID is correct
        assertEq(ASSET_ONE_ID, assetId);
    }

    function test_getAuctionReservePrice() public view {
        uint256 reservePrice = auction.getAuctionReservePrice(1);

        // Check that the reserve price is correct
        assertEq(10, reservePrice);
    }

    function test_getAuctionDeadline() public view {
        uint256 deadline = auction.getAuctionDeadline(1);

        // Check that the deadline is correct
        assertEq(ONE_HOUR, deadline);
    }

    function test_getAuctionHighestBid() public view {
        uint256 highestBid = auction.getAuctionHighestBid(1);

        // Check that the highest bid is correct
        assertEq(0, highestBid);
    }

    function test_getAuctionWinningBid() public view {
        uint256 winningBid = auction.getAuctionWinningBid(1);

        // Check that the winning bid is correct
        assertEq(0, winningBid);
    }

    function test_getAuctionStatus() public view {
        uint256 status = uint256(auction.getAuctionStatus(1));

        // Check that the status is correct
        assertEq(openStatus, status);
    }

    function test_getAuctionCount() public view {
        uint256 auctionCount = auction.getAuctionCount();

        // Check that there is one auction
        assertEq(1, auctionCount);
    }

    function test_getIGCTokenId() public view {
        uint256 igcTokenId = auction.getIGCTokenId();

        // Check that the IGC token ID is correct
        assertEq(IGC_TOKEN_ID, igcTokenId);
    }

    function test_getFactoryAddress() public view {
        address factory = auction.getAssetFactoryAddress();

        // Check that the assets contract is correct
        assertEq(address(factory), factory);
    }

    function test_getVaultAddress() public view {
        address vault = auction.getAssetVaultAddress();

        // Check that the vault contract is correct
        assertEq(address(vault), vault);
    }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetAuctionERC1155ReceiverTest is AssetAuctionTestHelper {
    function test_onERC1155Received() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        bytes4 returnedSelector = auction.onERC1155Received(address(0), address(0), 0, 0, "");

        // Check that the correct selector was returned
        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        bytes4 returnedSelector =
            auction.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");

        // Check that the correct selector was returned
        assertEq(returnedSelector, expectedSelector);
    }
}

///////////////////////////////////////////////////////////
///               IERC165 INTERFACE TESTS               ///
///////////////////////////////////////////////////////////

contract AssetAuctionERC165Test is AssetAuctionTestHelper {
    function test_supportsInterfaceIdIERC165() public view {
        bytes4 expectedSelector = 0x01ffc9a7;
        bool returnedSelector = auction.supportsInterface(expectedSelector);

        // Check that the contract supports the IERC165 interface
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceIdIERC1155Receiver() public view {
        bytes4 expectedSelector = 0x4e2312e0;
        bool returnedSelector = auction.supportsInterface(expectedSelector);

        // Check that the contract supports the IERC1155Receiver interface
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceBadSelector() public view {
        bytes4 badSelector = bytes4(keccak256("badSelector"));
        bool returnedSelector = auction.supportsInterface(badSelector);

        // Check that the contract throws false for an unsupported interface
        assertEq(returnedSelector, false);
    }
}
