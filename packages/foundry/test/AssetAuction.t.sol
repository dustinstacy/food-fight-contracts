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
event AuctionCancelled(uint256 auctionId);

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

    function test_createAuction_RevertWhen_InsufficientAssets() public { }

    function test_createAuction_RevertWhen_AssetsDepositedWithoutApproval() public { }
}

contract AssetAustionCancelAuctionTest is AssetAuctionCreateAuctionHelper {
    function test_cancelAuction() public { }

    function test_cancelAuction_EmitEvent() public { }

    function test_cancelAuction_RevertWhen_StatusNotOpen() public { }

    function test_cancelAuction_RevertWhen_DeadlinePassed() public { }

    function test_cancelAuction_RevertWhen_NotSeller() public { }
}

contract AssetAuctionCompleteAuctionTest is AssetAuctionCreateAuctionHelper {
    function test_completeAuctionWhenReserveMet() public { }

    function test_completeAuctionWhenReserveNotMet() public { }

    function test_completeAuction_EmitEvent() public { }

    function test_completeAuction_RevertWhen_StatusNotOpen() public { }

    function test_completeAuction_RevertWhen_NotSeller() public { }

    function test_completeAuction_RevertWhen_DeadlineNotPassed() public { }
}

///////////////////////////////////////////////////////////
///              BIDDER FUNCTION TESTS                  ///
///////////////////////////////////////////////////////////

contract AssetAuctionPlaceBidTest is AssetAuctionSetupHelper {
    function test_placeBid() public { }

    function test_placeBid_EmitEvent() public { }

    function test_placeBid_RevertWhen_StatusNotOpen() public { }

    function test_placeBid_RevertWhen_DeadlinePassed() public { }

    function test_placeBid_RevertWhen_BidLessThanHighestBid() public { }
}

contract AssetAuctionClaimAssetTest is AssetAuctionSetupHelper {
    function test_claimAsset() public { }

    function test_claimAsset_EmitEvent() public { }

    function test_claimAsset_RevertWhen_StatusNotEnded() public { }

    function test_claimAsset_RevertWhen_NotWinningBidder() public { }

    function test_claimAsset_RevertWhen_AssetAlreadyClaimed() public { }

    function test_claimAsset_RevertWhen_NotEnoughIGC() public { }
}

///////////////////////////////////////////////////////////
///              DEPOSIT FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetAuctionDepositAssetsTest is AssetAuctionSetupHelper {
    function test_depositAssets() public { }

    function test_depositMultipleAssets() public { }

    function test_depositAssets_EmitEvent() public { }

    function test_depositAssets_RevertWhen_ArraysNotSameLength() public { }

    function test_depositAssets_RevertWhen_InsufficientBalance() public { }
}

contract AssetAuctionDepositIGCTest is AssetAuctionSetupHelper {
    function test_depositIGC() public { }

    function test_depositIGC_EmitEvent() public { }

    function test_depositIGC_RevertWhen_InsufficientBalance() public { }
}

///////////////////////////////////////////////////////////
///              WITHDRAW FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetAuctionWithdrawAssetsTest is AssetAuctionSetupHelper {
    function test_withdrawAssetsAfterDepositing() public { }

    function test_withdrawMultipleAssetsAfterDepositing() public { }

    function test_withdrawAssetsAfterCancelingAuction() public { }

    function test_withdrawAssetsAfterClaimingAsset() public { }

    function test_withdrawAssets_EmitEvent() public { }

    function test_withdrawAssets_RevertWhen_ArraysNotSameLength() public { }

    function test_withdrawAssets_RevertWhen_InsufficientBalance() public { }
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
