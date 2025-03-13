//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { AssetAuction } from "@contracts/AssetAuction.sol";
import { AssetFactorySetAssetsHelper } from "./AssetFactory.t.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

///////////////////////////////////////////////////////////
///                     EVENTS                          ///
///////////////////////////////////////////////////////////

// Emitted when an auction is created
event AuctionCreated(
    address seller,
    uint256 auctionId,
    uint256 assetTokenId,
    uint256 reservePrice,
    uint256 deadline,
    AssetAuction.Style style
);

// Emitted when a bid is placed
event BidPlaced(address bidder, uint256 auctionId, uint256 amount);

// Emitted when an auction is ended
event AuctionEnded(uint256 auctionId, address winningBidder, uint256 winningBid);

// Emitted when an auction is cancelled
event AuctionCanceled(uint256 auctionId);

// Emitted when the reserve price is not met
event AuctionReserveNotMet(uint256 auctionId, uint256 reservePrice, uint256 highestBid);

// Emitted when an asset is claimed
event AssetClaimed(address winningBidder, uint256 auctionId, uint256 assetClaimedTokenId, uint256 winningBid);

// Emitted when assets are withdrawn
event AssetsWithdrawn(address to, uint256[] tokenIds, uint256[] amounts);

// Emitted when IGC is withdrawn
event IGCWithdrawn(address to, uint256 amount);

// Emitted when assets are deposited
event AssetsDeposited(address from, uint256[] tokenIds, uint256[] amounts);

// Emitted when IGC is deposited
event IGCDeposited(address from, uint256 amount);

///////////////////////////////////////////////////////////
///                      HELPERS                        ///
///////////////////////////////////////////////////////////

contract AssetAuctionSetupHelper is AssetFactorySetAssetsHelper {
    AssetAuction auction;
    address public user1;
    address public user2;
    address public user3;

    uint256 openStatus = uint256(AssetAuction.AuctionStatus.Open);
    uint256 canceledStatus = uint256(AssetAuction.AuctionStatus.Canceled);
    uint256 endedStatus = uint256(AssetAuction.AuctionStatus.Ended);
    uint256 reserveNotMetStatus = uint256(AssetAuction.AuctionStatus.ReserveNotMet);

    uint256 englishStyle = uint256(AssetAuction.Style.English);
    uint256 dutchStyle = uint256(AssetAuction.Style.Dutch);
    uint256 blindStyle = uint256(AssetAuction.Style.Blind);
    uint256 candleStyle = uint256(AssetAuction.Style.Candle);

    uint256 constant DEPOSIT_ONE = 1;
    uint256 constant DEPOSIT_FIVE = 5;
    uint256 constant DEPOSIT_TEN = 10;
    uint256 constant ONE_HOUR = 3600;

    function setUp() public virtual override {
        super.setUp();
        auction = new AssetAuction(address(factory));
        user1 = user;
        user2 = address(3);
        user3 = address(4);
        setUpAssets();
        mintInitialIGC(user1, MINT_1000000);
        mintInitialIGC(user2, MINT_1000000);
        mintInitialIGC(user3, MINT_1000000);
        vm.prank(user1);
        factory.mintAsset(user1, ASSET_ONE_ID, MINT_10, "");

        uint256 totalPrice = (MINT_10 * ASSET_ONE_PRICE);

        // Validate starting asset balances
        assertEq(MINT_10, factory.balanceOf(user1, ASSET_ONE_ID));
        assertEq(0, factory.balanceOf(user2, ASSET_ONE_ID));
        assertEq(0, factory.balanceOf(user3, ASSET_ONE_ID));
        assertEq(0, factory.balanceOf(user1, ASSET_TWO_ID));
        assertEq(0, factory.balanceOf(user2, ASSET_TWO_ID));
        assertEq(0, factory.balanceOf(user3, ASSET_TWO_ID));
        assertEq(0, factory.balanceOf(user1, ASSET_THREE_ID));
        assertEq(0, factory.balanceOf(user2, ASSET_THREE_ID));
        assertEq(0, factory.balanceOf(user3, ASSET_THREE_ID));

        // Validate starting IGC balances
        assertEq(MINT_1000000 - totalPrice, factory.balanceOf(user1, IGC_TOKEN_ID));
        assertEq(MINT_1000000, factory.balanceOf(user2, IGC_TOKEN_ID));
        assertEq(MINT_1000000, factory.balanceOf(user3, IGC_TOKEN_ID));

        // Validate addresses
        assertEq(user1, address(2));
        assertEq(user2, address(3));
        assertEq(user3, address(4));
    }
}

contract AssetAuctionCreateAuctionHelper is AssetAuctionSetupHelper {
    function setUp() public virtual override {
        super.setUp();
        createAuction();
    }

    function createAuction() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.createAuction(ASSET_ONE_ID, MINT_10, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();

        // Validate auction data and balances
        uint256 user1Asset1BalanceAfter = auction.getAssetBalance(user1, ASSET_ONE_ID);
        assertEq(0, user1Asset1BalanceAfter);

        uint256 expectedAuctionCount = 1;
        uint256 auctionCount = auction.getAuctionCount();
        assertEq(expectedAuctionCount, auctionCount);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        assertEq(user1, auctionData.seller);
        assertEq(ASSET_ONE_ID, auctionData.assetTokenId);
        assertEq(MINT_10, auctionData.reservePrice);
        assertEq(ONE_HOUR, auctionData.deadline);
        assertEq(englishStyle, uint256(auctionData.style));
        assertEq(0, auctionData.highestBid);
        assertEq(address(0), auctionData.highestBidder);
        assertEq(0, auctionData.winningBid);
        assertEq(address(0), auctionData.winningBidder);
        assertEq(openStatus, uint256(auctionData.status));
    }
}

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetAuctionConstructorTest is AssetAuctionSetupHelper {
    function test_constructor() public view {
        assertEq(address(factory), auction.getAssetsContract());
    }
}

///////////////////////////////////////////////////////////
///              SELLER FUNCTION TESTS                  ///
///////////////////////////////////////////////////////////

contract AssetAuctionCreateAuctionTest is AssetAuctionSetupHelper {
    function test_createAuctionWithAssetsDeposited() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_ONE;

        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.depositAssets(tokenIds, amounts);

        uint256 user1Asset1Balance = auction.getAssetBalance(user1, ASSET_ONE_ID);
        assertEq(DEPOSIT_ONE, user1Asset1Balance);

        auction.createAuction(ASSET_ONE_ID, MINT_10, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();

        uint256 expectedAuctionCount = 1;
        uint256 auctionCount = auction.getAuctionCount();
        assertEq(expectedAuctionCount, auctionCount);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        assertEq(user1, auctionData.seller);
        assertEq(ASSET_ONE_ID, auctionData.assetTokenId);
        assertEq(MINT_10, auctionData.reservePrice);
        assertEq(ONE_HOUR, auctionData.deadline);
        assertEq(englishStyle, uint256(auctionData.style));
        assertEq(0, auctionData.highestBid);
        assertEq(address(0), auctionData.highestBidder);
        assertEq(0, auctionData.winningBid);
        assertEq(address(0), auctionData.winningBidder);
        assertEq(openStatus, uint256(auctionData.status));

        uint256 user1Asset1BalanceAfter = auction.getAssetBalance(user1, ASSET_ONE_ID);
        assertEq(user1Asset1Balance - DEPOSIT_ONE, user1Asset1BalanceAfter);
    }

    function test_createAuctionWithoutAssetsDeposited() public {
        uint256 user1Asset1Balance = auction.getAssetBalance(user1, ASSET_ONE_ID);
        assertEq(0, user1Asset1Balance);

        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.createAuction(ASSET_ONE_ID, MINT_10, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();

        uint256 expectedAuctionCount = 1;
        uint256 auctionCount = auction.getAuctionCount();
        assertEq(expectedAuctionCount, auctionCount);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        assertEq(user1, auctionData.seller);
        assertEq(ASSET_ONE_ID, auctionData.assetTokenId);
        assertEq(MINT_10, auctionData.reservePrice);
        assertEq(ONE_HOUR, auctionData.deadline);
        assertEq(englishStyle, uint256(auctionData.style));
        assertEq(0, auctionData.highestBid);
        assertEq(address(0), auctionData.highestBidder);
        assertEq(0, auctionData.winningBid);
        assertEq(address(0), auctionData.winningBidder);
        assertEq(openStatus, uint256(auctionData.status));

        uint256 user1Asset1BalanceAfter = auction.getAssetBalance(user1, ASSET_ONE_ID);
        assertEq(0, user1Asset1BalanceAfter);
    }

    function test_createAuction_EmitEvent() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);

        vm.expectEmit(false, false, false, false, address(auction));
        emit AuctionCreated(user1, 1, ASSET_ONE_ID, MINT_10, ONE_HOUR, AssetAuction.Style.English);
        auction.createAuction(ASSET_ONE_ID, MINT_10, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();
    }

    function test_createAuction_RevertWhen_InsufficientAssets() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user1, 0, DEPOSIT_ONE, ASSET_TWO_ID
            )
        );
        auction.createAuction(ASSET_TWO_ID, MINT_10, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();
    }

    function test_createAuction_RevertWhen_AssetsDepositedWithoutApproval() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, address(auction), user1)
        );

        auction.createAuction(ASSET_ONE_ID, MINT_10, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();
    }
}

contract AssetAustionCancelAuctionTest is AssetAuctionCreateAuctionHelper {
    function test_cancelAuction() public {
        vm.prank(user1);
        auction.cancelAuction(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        assertEq(canceledStatus, uint256(auctionData.status));

        uint256 expectedUser1Asset1Balance = DEPOSIT_ONE;
        uint256 user1Asset1Balance = auction.getAssetBalance(user1, ASSET_ONE_ID);
        assertEq(expectedUser1Asset1Balance, user1Asset1Balance);
    }

    function test_cancelAuction_EmitEvent() public {
        vm.startPrank(user1);
        vm.expectEmit(false, false, false, false, address(auction));
        emit AuctionCanceled(1);
        auction.cancelAuction(1);
        vm.stopPrank();
    }

    function test_cancelAuction_RevertWhen_StatusNotOpen() public {
        vm.startPrank(user1);
        auction.cancelAuction(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 status = uint256(auctionData.status);

        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionAuctionIsNotOpen.selector, status));
        auction.cancelAuction(1);
        vm.stopPrank();
    }

    function test_cancelAuction_RevertWhen_DeadlinePassed() public {
        vm.warp(ONE_HOUR + 1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 deadline = auctionData.deadline;

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionDeadlineHasPassed.selector, deadline));
        auction.cancelAuction(1);
    }

    function test_cancelAuction_RevertWhen_NotSeller() public {
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotTheSeller.selector, user2, user1));
        auction.cancelAuction(1);
    }
}

contract AssetAuctionCompleteAuctionTest is AssetAuctionCreateAuctionHelper {
    function test_completeAuctionWhenReserveMet() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        vm.warp(ONE_HOUR + 1);

        vm.prank(user1);
        auction.completeAuction(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        assertEq(endedStatus, uint256(auctionData.status));
    }

    function test_completeAuctionWhenReserveNotMet() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_1);

        vm.warp(ONE_HOUR + 1);

        vm.prank(user1);
        auction.completeAuction(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        assertEq(reserveNotMetStatus, uint256(auctionData.status));
    }

    function test_completeAuction_EmitEvent() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        vm.warp(ONE_HOUR + 1);

        vm.startPrank(user1);
        vm.expectEmit(false, false, false, false, address(auction));
        emit AuctionEnded(1, user2, MINT_10);
        auction.completeAuction(1);
        vm.stopPrank();
    }

    function test_completeAuction_RevertWhen_StatusNotOpen() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        vm.warp(ONE_HOUR + 1);

        vm.startPrank(user1);
        auction.completeAuction(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 status = uint256(auctionData.status);

        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionAuctionIsNotOpen.selector, status));
        auction.completeAuction(1);
        vm.stopPrank();
    }

    function test_completeAuction_RevertWhen_DeadlineNotPassed() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 deadline = auctionData.deadline;

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionDeadlineNotPassed.selector, deadline));
        auction.completeAuction(1);
    }

    function test_completeAuction_RevertWhen_NotSeller() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        vm.warp(ONE_HOUR + 1);

        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotTheSeller.selector, user2, user1));
        auction.completeAuction(1);
    }
}

///////////////////////////////////////////////////////////
///              BIDDER FUNCTION TESTS                  ///
///////////////////////////////////////////////////////////

contract AssetAuctionPlaceBidTest is AssetAuctionCreateAuctionHelper {
    function test_placeBid() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        assertEq(MINT_10, auctionData.highestBid);
        assertEq(user2, auctionData.highestBidder);
    }

    function test_placeBid_EmitEvent() public {
        vm.startPrank(user2);
        vm.expectEmit(false, false, false, false, address(auction));
        emit BidPlaced(user2, 1, MINT_10);
        auction.placeBid(1, MINT_10);
        vm.stopPrank();
    }

    function test_placeBid_RevertWhen_StatusNotOpen() public {
        vm.prank(user1);
        auction.cancelAuction(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        uint256 status = uint256(auctionData.status);

        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionAuctionIsNotOpen.selector, status));
        auction.placeBid(1, MINT_10);
    }

    function test_placeBid_RevertWhen_DeadlinePassed() public {
        vm.warp(ONE_HOUR + 1);

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionDeadlineHasPassed.selector, ONE_HOUR));
        auction.placeBid(1, MINT_10);
    }

    function test_placeBid_RevertWhen_BidLessThanHighestBid() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        vm.prank(user3);
        vm.expectRevert(
            abi.encodeWithSelector(AssetAuction.AssetAuctionBidNotHigherThanHighestBid.selector, MINT_1, MINT_10)
        );
        auction.placeBid(1, MINT_1);
    }
}

contract AssetAuctionClaimAssetTest is AssetAuctionCreateAuctionHelper {
    function test_claimAsset() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        vm.warp(ONE_HOUR + 1);

        vm.prank(user1);
        auction.completeAuction(1);

        uint256 startingUser1IGCBalance = auction.getIGCBalance(user1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        assertEq(endedStatus, uint256(auctionData.status));

        address winningBidder = auctionData.winningBidder;
        assertEq(user2, winningBidder);

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);
        auction.claimAsset(1);
        vm.stopPrank();

        uint256 user2Asset1Balance = auction.getAssetBalance(user2, ASSET_ONE_ID);
        assertEq(DEPOSIT_ONE, user2Asset1Balance);

        uint256 endingUser1IGCBalance = auction.getIGCBalance(user1);
        assertEq(startingUser1IGCBalance + MINT_10, endingUser1IGCBalance);
    }

    function test_claimAsset_EmitEvent() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        vm.warp(ONE_HOUR + 1);

        vm.prank(user1);
        auction.completeAuction(1);

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetClaimed(user2, 1, ASSET_ONE_ID, MINT_10);
        auction.claimAsset(1);
        vm.stopPrank();
    }

    function test_claimAsset_RevertWhen_StatusNotEnded() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionAuctionHasNotEnded.selector, openStatus));
        auction.claimAsset(1);
    }

    function test_claimAsset_RevertWhen_NotWinningBidder() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        vm.prank(user3);
        auction.placeBid(1, MINT_10 + 1);

        vm.warp(ONE_HOUR + 1);

        vm.prank(user1);
        auction.completeAuction(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        assertEq(endedStatus, uint256(auctionData.status));

        address winningBidder = auctionData.winningBidder;
        assertEq(user3, winningBidder);

        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionNotTheWinningBidder.selector, user2, user3));
        auction.claimAsset(1);
    }

    function test_claimAsset_RevertWhen_AssetAlreadyClaimed() public {
        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        vm.warp(ONE_HOUR + 1);

        vm.prank(user1);
        auction.completeAuction(1);

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);
        auction.claimAsset(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);

        vm.expectRevert(
            abi.encodeWithSelector(AssetAuction.AssetAuctionAssetAlreadyClaimed.selector, auctionData.status)
        );
        auction.claimAsset(1);
    }

    function test_claimAsset_RevertWhen_NotEnoughIGC() public {
        vm.prank(user2);
        auction.placeBid(1, 10 ** 18);

        vm.warp(ONE_HOUR + 1);

        vm.prank(user1);
        auction.completeAuction(1);

        AssetAuction.Auction memory auctionData = auction.getAuction(1);
        assertEq(endedStatus, uint256(auctionData.status));

        address winningBidder = auctionData.winningBidder;
        assertEq(user2, winningBidder);

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user2, MINT_1000000, 10 ** 18, IGC_TOKEN_ID
            )
        );
        auction.claimAsset(1);
        vm.stopPrank();
    }
}

///////////////////////////////////////////////////////////
///              DEPOSIT FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetAuctionDepositAssetsTest is AssetAuctionSetupHelper {
    function test_depositAssets() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_ONE;

        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.depositAssets(tokenIds, amounts);
        vm.stopPrank();

        // Check that the user has deposited the correct amount of assets
        uint256 user1AssetBalance = auction.getAssetBalance(user1, ASSET_ONE_ID);
        assertEq(user1AssetBalance, DEPOSIT_ONE);
    }

    function test_depositMultipleAssets() public {
        vm.startPrank(user1);
        factory.mintAsset(user1, ASSET_TWO_ID, DEPOSIT_FIVE, "");
        factory.mintAsset(user1, ASSET_THREE_ID, MINT_10, "");

        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        tokenIds[0] = ASSET_ONE_ID;
        tokenIds[1] = ASSET_TWO_ID;
        tokenIds[2] = ASSET_THREE_ID;

        amounts[0] = DEPOSIT_ONE;
        amounts[1] = DEPOSIT_FIVE;
        amounts[2] = DEPOSIT_TEN;

        factory.setApprovalForAll(address(auction), true);
        auction.depositAssets(tokenIds, amounts);
        vm.stopPrank();

        // Check that the user has deposited the correct amount of assets
        uint256 user1Asset1Balance = auction.getAssetBalance(user1, ASSET_ONE_ID);
        uint256 user1Asset2Balance = auction.getAssetBalance(user1, ASSET_TWO_ID);
        uint256 user1Asset3Balance = auction.getAssetBalance(user1, ASSET_THREE_ID);

        assertEq(user1Asset1Balance, DEPOSIT_ONE);
        assertEq(user1Asset2Balance, DEPOSIT_FIVE);
        assertEq(user1Asset3Balance, DEPOSIT_TEN);
    }

    function test_depositAssets_EmitEvent() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_ONE;

        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetsDeposited(user1, tokenIds, amounts);
        auction.depositAssets(tokenIds, amounts);
        vm.stopPrank();
    }

    function test_depositAssets_RevertWhen_ArraysNotSameLength() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](2);

        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_ONE;
        amounts[1] = DEPOSIT_ONE;

        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionArraysLengthMismatch.selector, 1, 2));
        auction.depositAssets(tokenIds, amounts);
        vm.stopPrank();
    }

    function test_depositAssets_RevertWhen_InsufficientBalance() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_ONE;

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user2, 0, DEPOSIT_ONE, ASSET_ONE_ID
            )
        );
        auction.depositAssets(tokenIds, amounts);
        vm.stopPrank();
    }
}

contract AssetAuctionDepositIGCTest is AssetAuctionSetupHelper {
    function test_depositIGC() public {
        uint256 startingUser1AuctionIGCBalance = auction.getIGCBalance(user1);
        uint256 startingUser1IGCBalance = factory.balanceOf(user1, IGC_TOKEN_ID);

        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.depositIGC(MINT_10);
        vm.stopPrank();

        uint256 endingUser1AuctionIGCBalance = auction.getIGCBalance(user1);
        uint256 endingUser1IGCBalance = factory.balanceOf(user1, IGC_TOKEN_ID);
        assertEq(startingUser1AuctionIGCBalance + MINT_10, endingUser1AuctionIGCBalance);
        assertEq(startingUser1IGCBalance - MINT_10, endingUser1IGCBalance);
    }

    function test_depositIGC_EmitEvent() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        vm.expectEmit(false, false, false, false, address(auction));
        emit IGCDeposited(user1, MINT_10);
        auction.depositIGC(MINT_10);
        vm.stopPrank();
    }

    function test_depositIGC_RevertWhen_InsufficientBalance() public {
        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user2, MINT_1000000, 10 ** 18, IGC_TOKEN_ID
            )
        );
        auction.depositIGC(10 ** 18);
        vm.stopPrank();
    }
}

///////////////////////////////////////////////////////////
///              WITHDRAW FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetAuctionWithdrawAssetsTest is AssetAuctionSetupHelper {
    function test_withdrawAssetsAfterDepositing() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_ONE;

        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.depositAssets(tokenIds, amounts);

        uint256 user1AuctionAsset1Balance = auction.getAssetBalance(user1, ASSET_ONE_ID);
        assertEq(DEPOSIT_ONE, user1AuctionAsset1Balance);

        uint256 user1Asset1Balance = factory.balanceOf(user1, ASSET_ONE_ID);
        assertEq(MINT_10 - DEPOSIT_ONE, user1Asset1Balance);

        auction.withdrawAssets(tokenIds, amounts);
        vm.stopPrank();

        uint256 user1AuctionAsset1BalanceAfter = auction.getAssetBalance(user1, ASSET_ONE_ID);
        assertEq(0, user1AuctionAsset1BalanceAfter);

        uint256 user1Asset1BalanceAfter = factory.balanceOf(user1, ASSET_ONE_ID);
        assertEq(MINT_10, user1Asset1BalanceAfter);
    }

    function test_withdrawMultipleAssetsAfterDepositing() public {
        vm.startPrank(user1);
        factory.mintAsset(user1, ASSET_TWO_ID, DEPOSIT_FIVE, "");
        factory.mintAsset(user1, ASSET_THREE_ID, MINT_10, "");

        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        tokenIds[0] = ASSET_ONE_ID;
        tokenIds[1] = ASSET_TWO_ID;
        tokenIds[2] = ASSET_THREE_ID;

        amounts[0] = DEPOSIT_ONE;
        amounts[1] = DEPOSIT_FIVE;
        amounts[2] = DEPOSIT_TEN;

        factory.setApprovalForAll(address(auction), true);
        auction.depositAssets(tokenIds, amounts);
        vm.stopPrank();

        // Check that the user has deposited the correct amount of assets
        uint256 user1Asset1Balance = auction.getAssetBalance(user1, ASSET_ONE_ID);
        uint256 user1Asset2Balance = auction.getAssetBalance(user1, ASSET_TWO_ID);
        uint256 user1Asset3Balance = auction.getAssetBalance(user1, ASSET_THREE_ID);

        assertEq(user1Asset1Balance, DEPOSIT_ONE);
        assertEq(user1Asset2Balance, DEPOSIT_FIVE);
        assertEq(user1Asset3Balance, DEPOSIT_TEN);

        // Check that the user has the correct amount of assets in their account
        uint256 user1Asset1BalanceBefore = factory.balanceOf(user1, ASSET_ONE_ID);
        uint256 user1Asset2BalanceBefore = factory.balanceOf(user1, ASSET_TWO_ID);
        uint256 user1Asset3BalanceBefore = factory.balanceOf(user1, ASSET_THREE_ID);

        assertEq(user1Asset1BalanceBefore, MINT_10 - DEPOSIT_ONE);
        assertEq(user1Asset2BalanceBefore, DEPOSIT_FIVE);
        assertEq(user1Asset3BalanceBefore, MINT_10);
    }

    function test_withdrawAssetsAfterCancelingAuction() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.createAuction(ASSET_ONE_ID, MINT_10, ONE_HOUR, AssetAuction.Style.English);

        uint256 user1AuctionAsset1Balance = auction.getAssetBalance(user1, ASSET_ONE_ID);
        assertEq(0, user1AuctionAsset1Balance);

        uint256 user1Asset1Balance = factory.balanceOf(user1, ASSET_ONE_ID);
        assertEq(MINT_10 - DEPOSIT_ONE, user1Asset1Balance);

        auction.cancelAuction(1);

        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_ONE;

        auction.withdrawAssets(tokenIds, amounts);
        vm.stopPrank();

        uint256 user1AuctionAsset1BalanceAfter = auction.getAssetBalance(user1, ASSET_ONE_ID);
        assertEq(0, user1AuctionAsset1BalanceAfter);

        uint256 user1Asset1BalanceAfter = factory.balanceOf(user1, ASSET_ONE_ID);
        assertEq(MINT_10, user1Asset1BalanceAfter);
    }

    function test_withdrawAssetsAfterClaimingAsset() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.createAuction(ASSET_ONE_ID, MINT_10, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();

        vm.prank(user2);
        auction.placeBid(1, MINT_10);

        vm.warp(ONE_HOUR + 1);

        vm.prank(user1);
        auction.completeAuction(1);

        uint256 startingUser2Asset1Balance = factory.balanceOf(user2, ASSET_ONE_ID);
        assertEq(0, startingUser2Asset1Balance);

        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);
        auction.claimAsset(1);

        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_ONE;

        auction.withdrawAssets(tokenIds, amounts);
        vm.stopPrank();

        uint256 user2Asset1Balance = factory.balanceOf(user2, ASSET_ONE_ID);
        assertEq(startingUser2Asset1Balance + DEPOSIT_ONE, user2Asset1Balance);
    }

    function test_withdrawAssets_EmitEvent() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);

        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_ONE;

        auction.depositAssets(tokenIds, amounts);
        vm.expectEmit(false, false, false, false, address(auction));
        emit AssetsWithdrawn(user1, tokenIds, amounts);
        auction.withdrawAssets(tokenIds, amounts);
        vm.stopPrank();
    }

    function test_withdrawAssets_RevertWhen_ArraysNotSameLength() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);

        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](2);

        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_ONE;
        amounts[1] = DEPOSIT_ONE;

        vm.expectRevert(abi.encodeWithSelector(AssetAuction.AssetAuctionArraysLengthMismatch.selector, 1, 2));
        auction.withdrawAssets(tokenIds, amounts);
        vm.stopPrank();
    }

    function test_withdrawAssets_RevertWhen_InsufficientBalance() public {
        vm.startPrank(user2);
        factory.setApprovalForAll(address(auction), true);

        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_ONE;

        vm.expectRevert(
            abi.encodeWithSelector(
                AssetAuction.AssetAuctionInsufficientBalance.selector, user2, 0, DEPOSIT_ONE, ASSET_ONE_ID
            )
        );
        auction.withdrawAssets(tokenIds, amounts);
        vm.stopPrank();
    }
}

contract AssetAuctionWithdrawIGCTest is AssetAuctionSetupHelper {
    function test_withdrawIGC() public { }
}

///////////////////////////////////////////////////////////
///                VIEW FUNCTION TESTS                  ///
///////////////////////////////////////////////////////////

contract AssetAuctionViewFunctionsTest is AssetAuctionSetupHelper {
    function test_getAuction() public { }

    function test_getAuctionSeller() public { }

    function test_getAuctionHighestBidder() public { }

    function test_getAuctionWinningBidder() public { }

    function test_getAuctionAssetTokenId() public { }

    function test_getAuctionReservePrice() public { }

    function test_getAuctionDeadline() public { }

    function test_getAuctionHighestBid() public { }

    function test_getAuctionWinningBid() public { }

    function test_getAuctionStatus() public { }

    function test_getAuctionStyle() public { }

    function test_getAuctionBids() public { }

    function test_getAuctionBidCount() public { }

    function test_getAssetBalance() public { }

    function test_getIGCBalance() public { }

    function test_getAuctionCount() public { }

    function test_getIGCTokenId() public { }

    function test_getAssetsContract() public { }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetAuctionERC1155ReceiverTest is AssetAuctionSetupHelper {
    function test_onERC1155Received() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        bytes4 returnedSelector = factory.onERC1155Received(address(0), address(0), 0, 0, "");

        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        bytes4 returnedSelector =
            factory.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");

        assertEq(returnedSelector, expectedSelector);
    }
}

///////////////////////////////////////////////////////////
///               IERC165 INTERFACE TESTS               ///
///////////////////////////////////////////////////////////

contract AssetAuctionERC165Test is AssetAuctionSetupHelper {
    function test_supportsInterfaceIdIERC165() public view {
        bytes4 expectedSelector = 0x01ffc9a7;
        bool returnedSelector = auction.supportsInterface(expectedSelector);

        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceIdIERC1155Receiver() public view {
        bytes4 expectedSelector = 0x4e2312e0;
        bool returnedSelector = auction.supportsInterface(expectedSelector);

        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceBadSelector() public view {
        bytes4 badSelector = bytes4(keccak256("badSelector"));
        bool returnedSelector = auction.supportsInterface(badSelector);

        assertEq(returnedSelector, false);
    }
}
