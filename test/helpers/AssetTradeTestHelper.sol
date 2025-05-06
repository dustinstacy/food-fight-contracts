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

    /// @dev Instance of the AssetTrade contract.
    AssetTrade tradeContract = new AssetTrade(address(vault));

    ////////////////////////////////////////////////
    /// Enums                                    ///
    ////////////////////////////////////////////////

    /// @dev Convert the proposal status enum to integers for testing.
    uint256 pendingStatus = uint256(AssetTrade.ProposalStatus.Pending);
    uint256 approvedStatus = uint256(AssetTrade.ProposalStatus.Accepted);
    uint256 rejectedStatus = uint256(AssetTrade.ProposalStatus.Rejected);
    uint256 canceledStatus = uint256(AssetTrade.ProposalStatus.Canceled);

    ////////////////////////////////////////////////
    /// Setup Function                           ///
    ////////////////////////////////////////////////

    /// @dev Set up the initial state for the AssetTrade contract.
    // Sets the asset data, mints IGC and assets for userA & userB, deposits single assets into the vault for trade,
    // approves the AssetTrade contract to lock and unlock assets in the vault, and stores the starting balances for userA & userB.
    function setUp() public virtual override {
        // Calls the setup function from the parent class
        super.setUp();
        mintIGCTestHelper(userB, ONE_MILLION);
        mintAssetTestHelper(userB, assetIds, all);
        depositAssetsTestHelper(userA, asset1Single, amountSingle);
        depositAssetsTestHelper(userB, asset2Single, amountSingle);

        // Approve the AssetTrade contract to lock and unlock assets in the vault
        vm.prank(owner);
        vault.approveCaller(address(tradeContract));

        // Update the starting vault balances for userA & userB
        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        userAStartingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        userBStartingVaultAssetOneBalance = vault.balanceOf(userB, ASSET_ONE_ID);
        userBStartingVaultAssetTwoBalance = vault.balanceOf(userB, ASSET_TWO_ID);
    }

    ////////////////////////////////////////////////
    /// Contract Call Helpers                    ///
    ////////////////////////////////////////////////

    /// @dev Create a proposal
    /// @param proposer The address of the user creating the proposal.
    /// @param receiver The address of the user receiving the proposal.
    /// @param assetToTradeId The ID of the asset to trade.
    /// @param assetToReceiveId The ID of the asset to receive.
    function createProposalHelper(address proposer, address receiver, uint256 assetToTradeId, uint256 assetToReceiveId)
        public
    {
        vm.prank(proposer);
        tradeContract.createProposal(receiver, assetToTradeId, assetToReceiveId);
    }

    /// @dev Cancel a proposal
    /// @param proposer The address of the user who created the proposal.
    /// @param proposalId The ID of the proposal to cancel.
    function cancelProposalHelper(address proposer, uint256 proposalId) public {
        vm.prank(proposer);
        tradeContract.cancelProposal(proposalId);
    }
}
