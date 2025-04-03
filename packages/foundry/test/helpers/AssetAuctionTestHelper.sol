//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AssetAuction } from "@contracts/AssetAuction.sol";
import { AssetFactoryTestHelper } from "./AssetFactoryTestHelper.sol";
import { AssetVaultTestHelper } from "./AssetVaultTestHelper.sol";

/// @dev Helper contract for interacting with the AssetAuction contract.
/// Inheritance Tree:
/// AssetAuctionTestHelper -> AssetVaultTestHelper -> AssetFactoryTestHelper -> TestingVariables & Test
contract AssetAuctionTestHelper is AssetFactoryTestHelper, AssetVaultTestHelper {
    ////////////////////////////////////////////////
    /// Contract Instance                        ///
    ////////////////////////////////////////////////

    /// @dev Instance of the AssetAuction contract
    AssetAuction auction = new AssetAuction(address(factory), address(vault));

    ////////////////////////////////////////////////
    /// Enums                                    ///
    ////////////////////////////////////////////////

    /// @dev Convert the auction status enum to integers for testing
    uint256 openStatus = uint256(AssetAuction.AuctionStatus.Open);
    uint256 canceledStatus = uint256(AssetAuction.AuctionStatus.Canceled);
    uint256 endedStatus = uint256(AssetAuction.AuctionStatus.Ended);
    uint256 reserveNotMetStatus = uint256(AssetAuction.AuctionStatus.ReserveNotMet);

    ////////////////////////////////////////////////
    /// Setup Function                           ///
    ////////////////////////////////////////////////

    /// @dev Set up the initial state for the AssetAuction contract
    // Sets the asset data, mints IGC and assets for userA, userB, & UserC, deposits assets into the vault for auction interaction,
    // approves the AssetAuction contract to lock and unlock assets in the vault, and stores the starting balances for userA & userB.
    function setUp() public virtual override {
        // Calls the setup function from the parent class
        super.setUp();
        mintIGCTestHelper(userB, ONE_MILLION);
        mintIGCTestHelper(userC, ONE_MILLION);
        depositAssetsTestHelper(userA, asset1Single, amountSingle);
        depositIGCTestHelper(userB, ONE_MILLION);
        depositIGCTestHelper(userC, ONE_MILLION);

        // Approve the AssetAuction contract to lock and unlock assets in the vault
        vm.prank(owner);
        vault.approveCaller(address(auction));

        // Update the starting vault balances for userA & userB
        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        userBStartingVaultAssetOneBalance = vault.balanceOf(userB, ASSET_ONE_ID);
        userAStartingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        userBStartingVaultIGCBalance = vault.balanceOf(userB, IGC_TOKEN_ID);
    }

    ////////////////////////////////////////////////
    /// Contract Call Helpers                    ///
    ////////////////////////////////////////////////

    //!! Update this to accept a user, assetId, price, and duration
    /// @dev Create an auction for user A
    function createAuctionHelper() public {
        vm.prank(userA);
        auction.createAuction(ASSET_ONE_ID, 10, ONE_HOUR);
    }

    //!! Update to accept a user and assetId
    /// @dev Cancel an auction
    function cancelAuctionHelper() public {
        vm.prank(userA);
        auction.cancelAuction(ASSET_ONE_ID);
    }

    /// @dev Place a bid on an auction
    function placeBidHelper(address user, uint256 auctionId, uint256 amount) public {
        vm.prank(user);
        auction.placeBid(auctionId, amount);
    }

    //!! Update to accept a user and assetId
    /// @dev Complete an auction
    function completeAuctionHelper() public {
        vm.prank(userA);
        auction.completeAuction(ASSET_ONE_ID);
    }
}
