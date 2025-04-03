//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";
import { AssetTrade } from "@contracts/AssetTrade.sol";
import { AssetFactoryTestHelper } from "./AssetFactoryTestHelper.sol";
import { AssetVaultTestHelper } from "./AssetVaultTestHelper.sol";

/// @dev Helper contract for interacting with the AssetTrade contract.
/// Inheritance Tree:
/// AssetTradeTestHelper -> AssetVaultTestHelper -> AssetFactoryTestHelper -> TestingVariables & Test
contract AssetTradeTestHelper is AssetVaultTestHelper {
    ////////////////////////////////////////////////
    /// Contract Instance                        ///
    ////////////////////////////////////////////////

    /// @dev Instance of the AssetTrade contract
    AssetTrade trade = new AssetTrade(address(factory), address(vault));

    ////////////////////////////////////////////////
    /// Enums                                    ///
    ////////////////////////////////////////////////

    /// @dev Convert the proposal status enum to integers for testing
    uint256 pendingStatus = uint256(AssetTrade.ProposalStatus.Pending);
    uint256 approvedStatus = uint256(AssetTrade.ProposalStatus.Accepted);
    uint256 rejectedStatus = uint256(AssetTrade.ProposalStatus.Rejected);
    uint256 canceledStatus = uint256(AssetTrade.ProposalStatus.Canceled);

    ////////////////////////////////////////////////
    /// Setup Function                           ///
    ////////////////////////////////////////////////

    /// @dev Set up the initial state for the AssetTrade contract
    // Sets the asset data, mints IGC and assets for userA & userB, deposits single assets into the vault for trade,
    // and stores the starting balances for userA & userB.
    function setUp() public virtual override {
        // Calls the setup function from the parent class
        super.setUp();
        mintIGCTestHelper(userB, ONE_MILLION);
        mintAssetTestHelper(userB, all);
        depositAssetsTestHelper(userA, asset1Single, amountSingle);
        depositAssetsTestHelper(userB, asset2Single, amountSingle);

        // Approve the AssetTrade contract to lock and unlock assets in the vault
        vm.prank(owner);
        vault.approveCaller(address(trade));

        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        userAStartingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        userBStartingVaultAssetOneBalance = vault.balanceOf(userB, ASSET_ONE_ID);
        userBStartingVaultAssetTwoBalance = vault.balanceOf(userB, ASSET_TWO_ID);
    }

    ////////////////////////////////////////////////
    /// Contract Call Helpers                    ///
    ////////////////////////////////////////////////

    //!! Update this to be accept a receiver, assetToTrade, and assetToReceive
    /// @dev Create a proposal for user A to trade asset one for asset two with user B
    function createProposalHelper() public {
        vm.prank(userA);
        trade.createProposal(userB, ASSET_ONE_ID, ASSET_TWO_ID);
    }

    //!! Update to accept a user and proposalId
    /// @dev Cancel the proposal for user A
    function cancelProposalHelper() public {
        vm.prank(userA);
        trade.cancelProposal(1);
    }
}
