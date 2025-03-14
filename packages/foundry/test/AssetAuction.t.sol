//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { AssetAuction } from "@contracts/AssetAuction.sol";
import { AssetAuctionHelper } from "./helpers/AssetAuctionHelper.sol";

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetAuctionConstructorTest is AssetAuctionHelper {
    function test_constructor() public view {
        address expectedAddress = address(factory);
        address actualAddress = auction.getAssetsContract();

        // Check that the assets contract is set correctly
        assertEq(expectedAddress, actualAddress);
        // Check the auction count is 0
        assertEq(0, auction.getAuctionCount());
    }
}

///////////////////////////////////////////////////////////
///              SELLER FUNCTION TESTS                  ///
///////////////////////////////////////////////////////////

contract AssetAuctionCreateAuctionTest is AssetAuctionHelper {
    function test_createAuction_WithAssetsDeposited() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.depositAssets(asset1Single, amountSingle);

        uint256 user1Asset1AuctionBalance = auction.getAssetBalance(user1, ASSET_ONE_ID);

        // Check that the user has deposited the correct amount of assets
        assertEq(ONE, user1Asset1AuctionBalance);

        auction.createAuction(ASSET_ONE_ID, TEN, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();

        uint256 expectedAuctionCount = ONE;
        uint256 auctionCount = auction.getAuctionCount();

        // Check that the auction count is correct
        assertEq(expectedAuctionCount, auctionCount);

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);

        // Check that the auction data is correct
        assertEq(user1, auctionData.seller);
        assertEq(ASSET_ONE_ID, auctionData.assetTokenId);
        assertEq(TEN, auctionData.reservePrice);
        assertEq(ONE_HOUR, auctionData.deadline);
        assertEq(englishStyle, uint256(auctionData.style));
        assertEq(0, auctionData.highestBid);
        assertEq(address(0), auctionData.highestBidder);
        assertEq(0, auctionData.winningBid);
        assertEq(address(0), auctionData.winningBidder);
        assertEq(openStatus, uint256(auctionData.status));

        uint256 user1Asset1AuctionBalanceAfter = auction.getAssetBalance(user1, ASSET_ONE_ID);

        // Check that the user has the correct amount of assets after the auction
        assertEq(user1Asset1AuctionBalance - ONE, user1Asset1AuctionBalanceAfter);
    }

    function test_createAuction_WithoutAssetsDeposited() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.createAuction(ASSET_ONE_ID, TEN, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();

        uint256 expectedAuctionCount = ONE;
        uint256 auctionCount = auction.getAuctionCount();

        // Check that the auction count is correct
        assertEq(expectedAuctionCount, auctionCount);

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);

        // Check that the auction data is correct
        assertEq(user1, auctionData.seller);
        assertEq(ASSET_ONE_ID, auctionData.assetTokenId);
        assertEq(TEN, auctionData.reservePrice);
        assertEq(ONE_HOUR, auctionData.deadline);
        assertEq(englishStyle, uint256(auctionData.style));
        assertEq(0, auctionData.highestBid);
        assertEq(address(0), auctionData.highestBidder);
        assertEq(0, auctionData.winningBid);
        assertEq(address(0), auctionData.winningBidder);
        assertEq(openStatus, uint256(auctionData.status));

        uint256 user1Asset1AuctionBalanceAfter = auction.getAssetBalance(user1, ASSET_ONE_ID);

        // Check that the user has the correct amount of assets after the auction
        assertEq(0, user1Asset1AuctionBalanceAfter);
    }

    function test_createAuction_EmitsEvent() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);

        // Check that the AuctionCreated event is emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.AuctionCreated(user1, ONE, ASSET_ONE_ID, TEN, ONE_HOUR, AssetAuction.Style.English);
        auction.createAuction(ASSET_ONE_ID, TEN, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();
    }

    function test_createAuction_RevertsIf_InsufficientBalance() public {
        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, user2, 0, ONE, ASSET_ONE_ID)
        );
        auction.createAuction(ASSET_ONE_ID, TEN, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();
    }

    function test_createAuction_RevertsIf_MissingApprovalForAll() public {
        vm.prank(user1);

        // Check that the function reverts with the ERC1155MissingApproval error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, address(auction), user1)
        );

        auction.createAuction(ASSET_ONE_ID, TEN, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();
    }
}

contract AssetAustionCancelAuctionTest is AssetAuctionHelper {
    function setUp() public override {
        super.setUp();
        createAuctionHelper();
    }

    function test_cancelAuction() public {
        vm.prank(user1);
        auction.cancelAuction(ONE);

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);

        // Check that the auction status is set to canceled
        assertEq(canceledStatus, uint256(auctionData.status));

        uint256 expectedUser1Asset1Balance = ONE;
        uint256 user1Asset1Balance = auction.getAssetBalance(user1, ASSET_ONE_ID);

        // Check that the user has the correct amount of assets after the auction is canceled
        assertEq(expectedUser1Asset1Balance, user1Asset1Balance);
    }

    function test_cancelAuction_EmitsEvent() public {
        vm.prank(user1);

        // Check that the AuctionCanceled event is emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.AuctionCanceled(ONE);
        auction.cancelAuction(ONE);
    }

    function test_cancelAuction_RevertsIf_NotOpenStatus() public {
        vm.startPrank(user1);
        auction.cancelAuction(ONE);

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);
        uint256 status = uint256(auctionData.status);

        // Check that the function reverts with the AssetAuctionAuctionIsNotOpen error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionAuctionNotOpen.selector, status));
        auction.cancelAuction(ONE);
        vm.stopPrank();
    }

    function test_cancelAuction_RevertsIf_DeadlinePassed() public {
        vm.warp(ONE_HOUR + ONE);

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);
        uint256 deadline = auctionData.deadline;

        vm.startPrank(user1);

        // Check that the function reverts with the AssetAuctionDeadlineHasPassed error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionDeadlineHasPassed.selector, deadline));
        auction.cancelAuction(ONE);
    }

    function test_cancelAuction_RevertsIf_NotTheSeller() public {
        vm.startPrank(user2);

        // Check that the function reverts with the AssetAuctionNotTheSeller error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotTheSeller.selector, user2, user1));
        auction.cancelAuction(ONE);
    }
}

contract AssetAuctionCompleteAuctionTest is AssetAuctionHelper {
    function setUp() public override {
        super.setUp();
        createAuctionHelper();
    }

    function test_completeAuction_WhenReserveMet() public {
        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        vm.warp(ONE_HOUR + ONE);

        completeAuctionHelper();

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);

        // Check that the auction status is set to Ended
        assertEq(endedStatus, uint256(auctionData.status));
    }

    function test_completeAuction_WhenReserveNotMet() public {
        placeBidHelper(user2, ASSET_ONE_ID, ONE);

        vm.warp(ONE_HOUR + ONE);

        completeAuctionHelper();

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);

        // Check that the auction status is set to ReserveNotMet
        assertEq(reserveNotMetStatus, uint256(auctionData.status));
    }

    function test_completeAuction_EmitsEvent() public {
        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        vm.warp(ONE_HOUR + ONE);

        vm.prank(user1);

        // Check that the AuctionEnded event is emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.AuctionEnded(ONE, user2, TEN);
        auction.completeAuction(ONE);
    }

    function test_completeAuction_RevertsIf_NotOpenStatus() public {
        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        vm.warp(ONE_HOUR + ONE);

        vm.startPrank(user1);
        auction.completeAuction(ONE);

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);
        uint256 status = uint256(auctionData.status);

        // Check that the function reverts with the AssetAuctionAuctionNotOpen error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionAuctionNotOpen.selector, status));
        auction.completeAuction(ONE);
        vm.stopPrank();
    }

    function test_completeAuction_RevertsIf_DeadlineNotPassed() public {
        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);
        uint256 deadline = auctionData.deadline;

        vm.prank(user1);

        // Check that the function reverts with the AssetAuctionDeadlineNotPassed error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionDeadlineNotPassed.selector, deadline));
        auction.completeAuction(ONE);
    }

    function test_completeAuction_RevertsIf_NotTheSeller() public {
        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        vm.warp(ONE_HOUR + ONE);

        vm.prank(user2);

        // Check that the function reverts with the AssetAuctionNotTheSeller error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotTheSeller.selector, user2, user1));
        auction.completeAuction(ONE);
    }
}

///////////////////////////////////////////////////////////
///              BIDDER FUNCTION TESTS                  ///
///////////////////////////////////////////////////////////

contract AssetAuctionPlaceBidTest is AssetAuctionHelper {
    function setUp() public override {
        super.setUp();
        createAuctionHelper();
    }

    function test_placeBid() public {
        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);

        // Check that the highest bid and bidder are set correctly
        assertEq(TEN, auctionData.highestBid);
        assertEq(user2, auctionData.highestBidder);
    }

    function test_placeBid_EmistEvent() public {
        vm.prank(user2);

        // Check that the BidPlaced event is emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.BidPlaced(user2, 1, TEN);
        auction.placeBid(ONE, TEN);
    }

    function test_placeBid_RevertsIf_NotOpenStatus() public {
        vm.prank(user1);
        auction.cancelAuction(ONE);

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);
        uint256 status = uint256(auctionData.status);

        // Check that the function reverts with the AssetAuctionAuctionNotOpen error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionAuctionNotOpen.selector, status));
        auction.placeBid(ONE, TEN);
    }

    function test_placeBid_RevertsIf_DeadlinePassed() public {
        vm.warp(ONE_HOUR + ONE);

        vm.prank(user2);

        // Check that the function reverts with the AssetAuctionDeadlineHasPassed error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionDeadlineHasPassed.selector, ONE_HOUR));
        auction.placeBid(ONE, TEN);
    }

    function test_placeBid_RevertsIf_BidNotHigherThanHighestBid() public {
        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        vm.prank(user3);
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionBidNotHigherThanHighestBid.selector, ONE, TEN));
        auction.placeBid(ONE, ONE);
    }
}

contract AssetAuctionClaimAssetTest is AssetAuctionHelper {
    function setUp() public override {
        super.setUp();
        createAuctionHelper();
    }

    function test_claimAsset() public {
        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        vm.warp(ONE_HOUR + ONE);

        completeAuctionHelper();

        uint256 startingUser1IGCBalance = auction.getIGCBalance(user1);
        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);

        // Check that the auction status is set to Ended
        assertEq(endedStatus, uint256(auctionData.status));

        address winningBidder = auctionData.winningBidder;

        // Check that the winning bidder is correct
        assertEq(user2, winningBidder);

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);
        auction.claimAsset(ONE);
        vm.stopPrank();

        uint256 user2Asset1Balance = auction.getAssetBalance(user2, ASSET_ONE_ID);

        // Check that the winning bidder has the asset
        assertEq(ONE, user2Asset1Balance);

        uint256 endingUser1IGCBalance = auction.getIGCBalance(user1);

        // Check that the seller's IGC balance was updated correctly
        assertEq(startingUser1IGCBalance + TEN, endingUser1IGCBalance);
    }

    function test_claimAsset_EmitsEvent() public {
        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        vm.warp(ONE_HOUR + ONE);

        completeAuctionHelper();

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);

        // Check that the AssetClaimed event is emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.AssetClaimed(user2, 1, ASSET_ONE_ID, TEN);
        auction.claimAsset(ONE);
        vm.stopPrank();
    }

    function test_claimAsset_RevertsIf_NotEndedStatus() public {
        vm.startPrank(user2);
        auction.placeBid(ONE, TEN);

        // Check that the function reverts with the AssetAuctionAuctionHasNotEnded error
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionAuctionHasNotEnded.selector, openStatus));
        auction.claimAsset(ONE);
    }

    function test_claimAsset_RevertWhen_NotWinningBidder() public {
        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        vm.prank(user3);
        auction.placeBid(ONE, TEN + ONE);

        vm.warp(ONE_HOUR + ONE);

        completeAuctionHelper();

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);
        assertEq(endedStatus, uint256(auctionData.status));

        address winningBidder = auctionData.winningBidder;
        assertEq(user3, winningBidder);

        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotTheWinningBidder.selector, user2, user3));
        auction.claimAsset(ONE);
    }

    function test_claimAsset_RevertsIf_AssetAlreadyClaimed() public {
        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        vm.warp(ONE_HOUR + ONE);

        completeAuctionHelper();

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);
        auction.claimAsset(ONE);

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);

        // Check that the function reverts with the AssetAuctionAssetAlreadyClaimed error
        vm.expectRevert(
            abi.encodeWithSelector(AssetAuction.AssetAuctionAssetAlreadyClaimed.selector, auctionData.status)
        );
        auction.claimAsset(ONE);
    }

    function test_claimAsset_RevertsIf_NotEnoughIGC() public {
        vm.prank(user2);
        auction.placeBid(ONE, ONE_MILLION + ONE);

        vm.warp(ONE_HOUR + ONE);

        completeAuctionHelper();

        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);

        // Check that the auction status is set to Ended
        assertEq(endedStatus, uint256(auctionData.status));

        address winningBidder = auctionData.winningBidder;

        // Check that the winning bidder is correct
        assertEq(user2, winningBidder);

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user2, ONE_MILLION, ONE_MILLION + ONE, IGC_TOKEN_ID
            )
        );
        auction.claimAsset(ONE);
        vm.stopPrank();
    }
}

///////////////////////////////////////////////////////////
///                DEPOSIT FUNCTION TESTS               ///
///////////////////////////////////////////////////////////

contract AssetAuctionDepositAssetsTest is AssetAuctionHelper {
    function test_depositAssets() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.depositAssets(asset1Single, amountSingle);
        vm.stopPrank();

        uint256 user1AssetBalance = auction.getAssetBalance(user1, ASSET_ONE_ID);

        // Check that the user has deposited the correct amount of assets
        assertEq(user1AssetBalance, ONE);
    }

    function test_depositAssets_Multiple() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.depositAssets(assetIds, all);
        vm.stopPrank();

        uint256 user1Asset1Balance = auction.getAssetBalance(user1, ASSET_ONE_ID);
        uint256 user1Asset2Balance = auction.getAssetBalance(user1, ASSET_TWO_ID);
        uint256 user1Asset3Balance = auction.getAssetBalance(user1, ASSET_THREE_ID);

        // Check that the user has deposited the correct amount of assets
        assertEq(user1Asset1Balance, TEN);
        assertEq(user1Asset2Balance, TEN);
        assertEq(user1Asset3Balance, TEN);
    }

    function test_depositAssets_EmitsEvent() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);

        // Check that the AssetsDeposited event was emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.AssetsDeposited(user1, asset1Single, amountSingle);
        auction.depositAssets(asset1Single, amountSingle);
        vm.stopPrank();
    }

    function test_depositAssets_RevertsIf_ArraysLengthMismatch() public {
        vm.prank(user1);

        // Check that the function reverts with the AssetAuctionArraysLengthMismatch error
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetAuction.AssetAuctionArraysLengthMismatch.selector, assetIds.length, invalid.length
            )
        );
        auction.depositAssets(assetIds, invalid);
    }

    function test_depositAssets_RevertsIf_InsufficientBalance() public {
        amountSingle[0] = ONE_MILLION;

        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user1, TEN, ONE_MILLION, ASSET_ONE_ID
            )
        );
        auction.depositAssets(asset1Single, amountSingle);
        vm.stopPrank();
    }
}

contract AssetAuctionDepositIGCTest is AssetAuctionHelper {
    function test_depositIGC() public {
        uint256 startingUser1AuctionIGCBalance = auction.getIGCBalance(user1);
        uint256 startingUser1IGCBalance = factory.balanceOf(user1, IGC_TOKEN_ID);

        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.depositIGC(TEN);
        vm.stopPrank();

        uint256 endingUser1AuctionIGCBalance = auction.getIGCBalance(user1);
        uint256 endingUser1IGCBalance = factory.balanceOf(user1, IGC_TOKEN_ID);

        // Check that the user's balances were updated correctly
        assertEq(startingUser1AuctionIGCBalance + TEN, endingUser1AuctionIGCBalance);
        assertEq(startingUser1IGCBalance - TEN, endingUser1IGCBalance);
    }

    function test_depositIGC_EmitEvent() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);

        // Check that the IGCDeposited event was emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.IGCDeposited(user1, TEN);
        auction.depositIGC(TEN);
        vm.stopPrank();
    }

    function test_depositIGC_RevertWhen_InsufficientBalance() public {
        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user2, ONE_MILLION, ONE_MILLION + ONE, IGC_TOKEN_ID
            )
        );
        auction.depositIGC(ONE_MILLION + ONE);
        vm.stopPrank();
    }
}

///////////////////////////////////////////////////////////
///               WITHDRAW FUNCTION TESTS               ///
///////////////////////////////////////////////////////////

contract AssetAuctionWithdrawAssetsTest is AssetAuctionHelper {
    function setUp() public override {
        super.setUp();
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.depositAssets(assetIds, all);
        vm.stopPrank();
    }

    function test_withdrawAssets() public {
        vm.prank(user1);
        auction.withdrawAssets(asset1Single, amountSingle);

        uint256 expectedUser1Asset1AuctionBalance = TEN - ONE;
        uint256 actualUser1Asset1AuctionBalance = auction.getAssetBalance(user1, ASSET_ONE_ID);

        // Check that the user's asset balance was updated
        assertEq(expectedUser1Asset1AuctionBalance, actualUser1Asset1AuctionBalance);

        uint256 expectedUser1Asset1FactoryBalance = ONE;
        uint256 actualUser1Asset1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);

        // Check the asset contract balance to ensure the assets were withdrawn
        assertEq(expectedUser1Asset1FactoryBalance, actualUser1Asset1FactoryBalance);
    }

    function test_withdrawAssets_Multiple() public {
        vm.prank(user1);
        auction.withdrawAssets(assetIds, all);

        uint256 expectedUser1Asset1AuctionBalance = 0;
        uint256 expectedUser1Asset2AuctionBalance = 0;
        uint256 expectedUser1Asset3AuctionBalance = 0;
        uint256 actualUser1Asset1AuctionBalance = auction.getAssetBalance(user1, ASSET_ONE_ID);
        uint256 actualUser1Asset2AuctionBalance = auction.getAssetBalance(user1, ASSET_TWO_ID);
        uint256 actualUser1Asset3AuctionBalance = auction.getAssetBalance(user1, ASSET_THREE_ID);

        // Check that the user's asset balance was updated
        assertEq(expectedUser1Asset1AuctionBalance, actualUser1Asset1AuctionBalance);
        assertEq(expectedUser1Asset2AuctionBalance, actualUser1Asset2AuctionBalance);
        assertEq(expectedUser1Asset3AuctionBalance, actualUser1Asset3AuctionBalance);

        uint256 expectedUser1Asset1FactoryBalance = TEN;
        uint256 expectedUser1Asset2FactoryBalance = TEN;
        uint256 expectedUser1Asset3FactoryBalance = TEN;
        uint256 actualUser1Asset1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);
        uint256 actualUser1Asset2FactoryBalance = factory.balanceOf(user1, ASSET_TWO_ID);
        uint256 actualUser1Asset3FactoryBalance = factory.balanceOf(user1, ASSET_THREE_ID);

        // Check the asset contract balance to ensure the assets were withdrawn
        assertEq(expectedUser1Asset1FactoryBalance, actualUser1Asset1FactoryBalance);
        assertEq(expectedUser1Asset2FactoryBalance, actualUser1Asset2FactoryBalance);
        assertEq(expectedUser1Asset3FactoryBalance, actualUser1Asset3FactoryBalance);
    }

    function test_withdrawAssets_AfterCancelingAuction() public {
        createAuctionHelper();
        vm.startPrank(user1);
        auction.cancelAuction(ONE);
        auction.withdrawAssets(asset1Single, amountSingle);

        uint256 expectedUser1AuctionBalance = TEN - ONE;
        uint256 actualUser1AuctionBalance = auction.getAssetBalance(user1, ASSET_ONE_ID);

        // Check that the user's asset balance was updated
        assertEq(expectedUser1AuctionBalance, actualUser1AuctionBalance);

        uint256 expectedUser1FactoryBalance = ONE;
        uint256 actualUser1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);

        // Check the asset contract balance to ensure the assets were withdrawn
        assertEq(expectedUser1FactoryBalance, actualUser1FactoryBalance);
    }

    function test_withdrawAssets_AfterClaiming() public {
        createAuctionHelper();

        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        vm.warp(ONE_HOUR + ONE);

        completeAuctionHelper();

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);
        auction.claimAsset(ONE);
        auction.withdrawAssets(asset1Single, amountSingle);
        vm.stopPrank();

        uint256 expectedUser1AuctionBalance = TEN - ONE;
        uint256 actualUser1AuctionBalance = auction.getAssetBalance(user1, ASSET_ONE_ID);

        // Check that the user1's auction contract balances are correct
        assertEq(expectedUser1AuctionBalance, actualUser1AuctionBalance);

        uint256 expectedUser2AuctionBalance = 0;
        uint256 actualUser2AuctionBalance = auction.getAssetBalance(user2, ASSET_ONE_ID);

        // Check that the user2's auction contract balances are correct
        assertEq(expectedUser2AuctionBalance, actualUser2AuctionBalance);

        uint256 expectedUser1FactoryBalance = 0;
        uint256 actualUser1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);

        // Check that the user1's asset contract balances are correct
        assertEq(expectedUser1FactoryBalance, actualUser1FactoryBalance);

        uint256 expectedUser2FactoryBalance = ONE;
        uint256 actualUser2FactoryBalance = factory.balanceOf(user2, ASSET_ONE_ID);

        // Check that the user2's asset contract balances are correct
        assertEq(expectedUser2FactoryBalance, actualUser2FactoryBalance);
    }

    function test_withdrawAssets_EmitsEvent() public {
        vm.prank(user1);

        // Check that the AssetsWithdrawn event was emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.AssetsWithdrawn(user1, asset1Single, amountSingle);
        auction.withdrawAssets(asset1Single, amountSingle);
    }

    function test_withdrawAssets_RevertsIf_ArrayLengthMismatch() public {
        vm.prank(user1);

        // Check that the function reverts with the AssetAuctionArraysLengthMismatch error
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetAuction.AssetAuctionArraysLengthMismatch.selector, assetIds.length, invalid.length
            )
        );
        auction.withdrawAssets(assetIds, invalid);
        vm.stopPrank();
    }

    function test_withdrawAssets_RevertsIf_InsufficientBalance() public {
        amountSingle[0] = ONE_MILLION;

        vm.prank(user1);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetAuction.AssetAuctionInsufficientBalance.selector, user1, 0, ONE_MILLION, ASSET_ONE_ID
            )
        );
        auction.withdrawAssets(asset1Single, amountSingle);
    }
}

contract AssetAuctionWithdrawIGCTest is AssetAuctionHelper {
    function test_withdrawIGCAfterDeposit() public {
        uint256 startingUser1AuctionIGCBalance = auction.getIGCBalance(user1);
        uint256 startingUser1IGCBalance = factory.balanceOf(user1, IGC_TOKEN_ID);

        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.depositIGC(TEN);

        uint256 afterDepositUser1AuctionIGCBalance = auction.getIGCBalance(user1);
        uint256 afterDepositUser1IGCBalance = factory.balanceOf(user1, IGC_TOKEN_ID);

        // Check that the user's balances were updated correctly
        assertEq(startingUser1AuctionIGCBalance + TEN, afterDepositUser1AuctionIGCBalance);
        assertEq(startingUser1IGCBalance - TEN, afterDepositUser1IGCBalance);

        auction.withdrawIGC(TEN);
        vm.stopPrank();

        uint256 endingUser1AuctionIGCBalance = auction.getIGCBalance(user1);
        uint256 endingUser1IGCBalance = factory.balanceOf(user1, IGC_TOKEN_ID);

        // Check that the user's balances were updated correctly
        assertEq(startingUser1AuctionIGCBalance, endingUser1AuctionIGCBalance);
        assertEq(startingUser1IGCBalance, endingUser1IGCBalance);
    }

    function test_withdrawIGCAfterAssetSold() public {
        createAuctionHelper();

        placeBidHelper(user2, ASSET_ONE_ID, TEN);

        vm.warp(ONE_HOUR + ONE);

        completeAuctionHelper();

        uint256 startingUser2IGCBalance = factory.balanceOf(user2, IGC_TOKEN_ID);

        // Check the bidders's IGC balance before withdrawing
        assertEq(ONE_MILLION, startingUser2IGCBalance);

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);
        auction.claimAsset(ONE);
        vm.stopPrank();

        uint256 user2IGCBalanceAfterClaim = factory.balanceOf(user2, IGC_TOKEN_ID);

        // Check the bidders's IGC balance after claiming the asset
        assertEq(ONE_MILLION - TEN, user2IGCBalanceAfterClaim);

        uint256 startingUser1IGCBalance = factory.balanceOf(user1, IGC_TOKEN_ID);

        vm.prank(user1);
        auction.withdrawIGC(TEN);

        uint256 endingUser1IGCBalance = factory.balanceOf(user1, IGC_TOKEN_ID);

        // Check the seller's IGC balance after withdrawing
        assertEq(startingUser1IGCBalance + TEN, endingUser1IGCBalance);
    }

    function test_withdrawIGC_EmitEvent() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.depositIGC(TEN);

        // Check that the IGCWithdrawn event was emitted
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetAuction.IGCWithdrawn(user1, TEN);
        auction.withdrawIGC(TEN);
        vm.stopPrank();
    }

    function test_withdrawIGC_RevertWhen_InsufficientBalance() public {
        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(AssetAuction.AssetAuctionInsufficientBalance.selector, user2, 0, ONE, IGC_TOKEN_ID)
        );
        auction.withdrawIGC(ONE);
        vm.stopPrank();
    }
}

///////////////////////////////////////////////////////////
///                VIEW FUNCTION TESTS                  ///
///////////////////////////////////////////////////////////

contract AssetAuctionViewFunctionsTest is AssetAuctionHelper {
    function setUp() public override {
        super.setUp();
        createAuctionHelper();
    }

    function test_getAuction() public view {
        AssetAuction.Auction memory auctionData = auction.getAuction(ONE);

        // Check that the auction data is correct
        assertEq(user1, auctionData.seller);
        assertEq(ASSET_ONE_ID, auctionData.assetTokenId);
        assertEq(TEN, auctionData.reservePrice);
        assertEq(ONE_HOUR, auctionData.deadline);
        assertEq(englishStyle, uint256(auctionData.style));
        assertEq(0, auctionData.highestBid);
        assertEq(address(0), auctionData.highestBidder);
        assertEq(0, auctionData.winningBid);
        assertEq(address(0), auctionData.winningBidder);
        assertEq(openStatus, uint256(auctionData.status));
    }

    function test_getAuctionSeller() public view {
        address seller = auction.getAuctionSeller(ONE);

        // Check that the seller is correct
        assertEq(user1, seller);
    }

    function test_getAuctionHighestBidder() public view {
        address highestBidder = auction.getAuctionHighestBidder(ONE);

        // Check that the highest bidder is correct
        assertEq(address(0), highestBidder);
    }

    function test_getAuctionWinningBidder() public view {
        address winningBidder = auction.getAuctionWinningBidder(ONE);

        // Check that the winning bidder is correct
        assertEq(address(0), winningBidder);
    }

    function test_getAuctionAssetTokenId() public view {
        uint256 assetTokenId = auction.getAuctionAssetTokenId(ONE);

        // Check that the asset token ID is correct
        assertEq(ASSET_ONE_ID, assetTokenId);
    }

    function test_getAuctionReservePrice() public view {
        uint256 reservePrice = auction.getAuctionReservePrice(ONE);

        // Check that the reserve price is correct
        assertEq(TEN, reservePrice);
    }

    function test_getAuctionDeadline() public view {
        uint256 deadline = auction.getAuctionDeadline(ONE);

        // Check that the deadline is correct
        assertEq(ONE_HOUR, deadline);
    }

    function test_getAuctionHighestBid() public view {
        uint256 highestBid = auction.getAuctionHighestBid(ONE);

        // Check that the highest bid is correct
        assertEq(0, highestBid);
    }

    function test_getAuctionWinningBid() public view {
        uint256 winningBid = auction.getAuctionWinningBid(ONE);

        // Check that the winning bid is correct
        assertEq(0, winningBid);
    }

    function test_getAuctionStatus() public view {
        uint256 status = uint256(auction.getAuctionStatus(ONE));

        // Check that the status is correct
        assertEq(openStatus, status);
    }

    function test_getAuctionStyle() public view {
        AssetAuction.Style style = auction.getAuctionStyle(ONE);

        // Check that the style is correct
        assertEq(englishStyle, uint256(style));
    }

    function test_getAuctionBids() public view {
        AssetAuction.Bid[] memory bids = auction.getAuctionBids(ONE);

        // Check that there are no bids
        assertEq(0, bids.length);
    }

    function test_getAuctionBidCount() public view {
        uint256 bidCount = auction.getAuctionBidCount(ONE);

        // Check that there are no bids
        assertEq(0, bidCount);
    }

    function test_getAssetBalance() public view {
        uint256 user1Asset1Balance = auction.getAssetBalance(user1, ASSET_ONE_ID);

        // Check that the user has no assets
        assertEq(0, user1Asset1Balance);
    }

    function test_getIGCBalance() public view {
        uint256 user1IGCBalance = auction.getIGCBalance(user1);

        // Check that the user has no IGC
        assertEq(0, user1IGCBalance);
    }

    function test_getAuctionCount() public view {
        uint256 auctionCount = auction.getAuctionCount();

        // Check that there is one auction
        assertEq(ONE, auctionCount);
    }

    function test_getIGCTokenId() public view {
        uint256 igcTokenId = auction.getIGCTokenId();

        // Check that the IGC token ID is correct
        assertEq(IGC_TOKEN_ID, igcTokenId);
    }

    function test_getAssetsContract() public view {
        address assetsContract = auction.getAssetsContract();

        // Check that the assets contract is correct
        assertEq(address(factory), assetsContract);
    }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetAuctionERC1155ReceiverTest is AssetAuctionHelper {
    function test_onERC1155Received() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        bytes4 returnedSelector = factory.onERC1155Received(address(0), address(0), 0, 0, "");

        // Check that the correct selector was returned
        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        bytes4 returnedSelector =
            factory.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");

        // Check that the correct selector was returned
        assertEq(returnedSelector, expectedSelector);
    }
}

///////////////////////////////////////////////////////////
///               IERC165 INTERFACE TESTS               ///
///////////////////////////////////////////////////////////

contract AssetAuctionERC165Test is AssetAuctionHelper {
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
