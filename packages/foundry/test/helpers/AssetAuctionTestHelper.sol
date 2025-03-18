//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AssetAuction } from "@contracts/AssetAuction.sol";
import { AssetFactoryTestHelper } from "./AssetFactoryTestHelper.sol";
import { AssetVaultTestHelper } from "./AssetVaultTestHelper.sol";

/// @dev Helper contract to setup the environment for AssetAuction testing and functions to interact with AssetAuction contract
contract AssetAuctionTestHelper is AssetFactoryTestHelper, AssetVaultTestHelper {
    /// @dev Create an instance of the AssetAuction contract that all tests will use
    AssetAuction auction = new AssetAuction(address(factory), address(vault));

    /// @dev Convert the auction status enum to integers for testing
    uint256 openStatus = uint256(AssetAuction.AuctionStatus.Open);
    uint256 canceledStatus = uint256(AssetAuction.AuctionStatus.Canceled);
    uint256 endedStatus = uint256(AssetAuction.AuctionStatus.Ended);
    uint256 reserveNotMetStatus = uint256(AssetAuction.AuctionStatus.ReserveNotMet);

    /// @dev Set up the initial state for the AssetAuction contract
    // Mints IGC and Assets for user B and C, then deposits assets into the vault for user A and IGC for user B and C
    function setUp() public virtual override {
        super.setUp();
        mintIGCTestHelper(userB, ONE_MILLION);
        mintIGCTestHelper(userC, ONE_MILLION);
        depositAssetsTestHelper(userA, asset1Single, amountSingle);
        depositIGCTestHelper(userB, ONE_MILLION);
        depositIGCTestHelper(userC, ONE_MILLION);

        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        userBStartingVaultAssetOneBalance = vault.balanceOf(userB, ASSET_ONE_ID);
        userAStartingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        userBStartingVaultIGCBalance = vault.balanceOf(userB, IGC_TOKEN_ID);
    }

    /// @dev Create an auction for user A
    //!! Update this to accept a user, assetId, price, and duration
    function createAuctionHelper() public {
        vm.prank(userA);
        auction.createAuction(ASSET_ONE_ID, 10, ONE_HOUR);
    }

    /// @dev Cancel an auction
    //!! Update to accept a user and assetId
    function cancelAuctionHelper() public {
        vm.prank(userA);
        auction.cancelAuction(ASSET_ONE_ID);
    }

    /// @dev Place a bid on an auction
    function placeBidHelper(address user, uint256 auctionId, uint256 amount) public {
        vm.prank(user);
        auction.placeBid(auctionId, amount);
    }

    /// @dev Complete an auction
    //!! Update to accept a user and assetId
    function completeAuctionHelper() public {
        vm.prank(userA);
        auction.completeAuction(ASSET_ONE_ID);
    }
}
