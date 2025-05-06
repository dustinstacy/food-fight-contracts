//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AssetRental } from "@contracts/AssetRental.sol";
import { AssetVaultTestHelper } from "./AssetVaultTestHelper.sol";

/// @dev Helper contract for interacting with the AssetRental contract.
/// Inheritance Tree:
/// AssetRentalTestHelper -> AssetVaultTestHelper -> AssetFactoryTestHelper -> TestingVariables & Test
contract AssetRentalTestHelper is AssetVaultTestHelper {
    ////////////////////////////////////////////////
    /// Contract Instance                        ///
    ////////////////////////////////////////////////

    /// @dev Instance of the AssetRental contract.
    AssetRental rentalContract = new AssetRental(address(vault));

    ////////////////////////////////////////////////
    /// Enums                                    ///
    ////////////////////////////////////////////////

    /// @dev Convert the rental status enum to integers for testing.
    uint256 availableStatus = uint256(AssetRental.RentalStatus.Available);
    uint256 rentedStatus = uint256(AssetRental.RentalStatus.Rented);
    uint256 unavailableStatus = uint256(AssetRental.RentalStatus.Unavailable);

    ////////////////////////////////////////////////
    /// Setup Function                           ///
    ////////////////////////////////////////////////

    /// @dev Set up the initial state for the AssetRental contract.
    // Sets the asset data, mints IGC and assets for userA, userB, & userC. deposits assets into the vault for rental interaction,
    // approves the AssetRental contract to lock and unlock assets in the vault, and stores the starting balances for userA & userB.
    function setUp() public virtual override {
        // Calls the setup function from the parent class
        super.setUp();
        mintIGCTestHelper(userB, ONE_MILLION);
        mintIGCTestHelper(userC, ONE_MILLION);
        depositAssetsTestHelper(userA, asset1Single, amountSingle);
        depositAssetsTestHelper(userA, asset2Single, amountSingle);
        depositIGCTestHelper(userB, ONE_MILLION);
        depositIGCTestHelper(userC, ONE_MILLION);

        // Approve the AssetRental contract to lock and unlock assets in the vault
        vm.prank(owner);
        vault.approveCaller(address(rentalContract));

        // Update the starting vault balances for userA & userB
        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        userBStartingVaultAssetOneBalance = vault.balanceOf(userB, ASSET_ONE_ID);
        userAStartingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        userAStartingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        userBStartingVaultIGCBalance = vault.balanceOf(userB, IGC_TOKEN_ID);
        userCStartingVaultIGCBalance = vault.balanceOf(userC, IGC_TOKEN_ID);
    }

    ////////////////////////////////////////////////
    /// Contract Call Helpers                    ///
    ////////////////////////////////////////////////

    /// @dev Create a rental for an asset.
    /// @param user The address of the user creating the rental.
    /// @param assetId The ID of the asset to be rented.
    /// @param price The price of the rental.
    /// @param duration The duration of the rental in seconds.
    function createRentalHelper(address user, uint256 assetId, uint256 price, uint256 duration) public {
        vm.startPrank(user);
        factory.setApprovalForAll(address(rentalContract), true);
        rentalContract.createRental(assetId, price, duration);
        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        vm.stopPrank();
    }

    /// @dev Unlist a rental.
    /// @param user The address of the user unlisting the rental.
    /// @param rentalId The ID of the rental to be unlisted.
    function unlistRentalHelper(address user, uint256 rentalId) public {
        vm.prank(user);
        rentalContract.unlistRental(rentalId);
    }

    /// @dev Update a rental.
    /// @param user The address of the user updating the rental.
    /// @param rentalId The ID of the rental to be updated.
    /// @param newPrice The new price of the rental.
    /// @param newDuration The new duration of the rental in seconds.
    function updateRentalHelper(address user, uint256 rentalId, uint256 newPrice, uint256 newDuration) public {
        vm.prank(user);
        rentalContract.updateRental(rentalId, newPrice, newDuration);
    }

    /// @dev Rent an asset
    /// @param user The address of the user renting the asset.
    /// @param rentalId The ID of the rental.
    function rentAssetHelper(address user, uint256 rentalId) public {
        vm.prank(user);
        rentalContract.rentAsset(rentalId);
    }
}
