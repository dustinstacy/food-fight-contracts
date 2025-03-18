//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";
import { AssetTrade } from "@contracts/AssetTrade.sol";
import { AssetFactoryTestHelper } from "./AssetFactoryTestHelper.sol";
import { AssetVaultTestHelper } from "./AssetVaultTestHelper.sol";

/// @dev Helper contract to setup the environment for AssetTrade testing and functions to interact with AssetTrade contract
contract AssetTradeTestHelper is AssetFactoryTestHelper, AssetVaultTestHelper {
    /// @dev Create an instance of the AssetTrade contract that all tests will use
    AssetTrade trade = new AssetTrade(address(factory), address(vault));

    /// @dev Convert the proposal status enum to integers for testing
    uint256 pendingStatus = uint256(AssetTrade.ProposalStatus.Pending);
    uint256 approvedStatus = uint256(AssetTrade.ProposalStatus.Approved);
    uint256 rejectedStatus = uint256(AssetTrade.ProposalStatus.Rejected);
    uint256 canceledStatus = uint256(AssetTrade.ProposalStatus.Canceled);

    /// @dev Set up the initial state for the AssetTrade contract
    // Mints IGC and Assets for user B, then deposits assets into the vault for user A and user B
    // Also updates the starting vault balances for user A and user B
    function setUp() public virtual override {
        super.setUp();
        setAssetsTestHelper();
        mintIGCTestHelper(userB, ONE_MILLION);
        mintAssetTestHelper(userB, all);
        depositAssetsTestHelper(userA, asset1Single, amountSingle);
        depositAssetsTestHelper(userB, asset2Single, amountSingle);

        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        userAStartingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        userBStartingVaultAssetOneBalance = vault.balanceOf(userB, ASSET_ONE_ID);
        userBStartingVaultAssetTwoBalance = vault.balanceOf(userB, ASSET_TWO_ID);
    }

    /// @dev Create a proposal for user A to trade asset one for asset two with user B
    //!! Update this to be more modular
    function createProposalHelper() public {
        vm.prank(userA);
        trade.createProposal(userB, ASSET_ONE_ID, ASSET_TWO_ID);
    }

    /// @dev Cancel the proposal for user A
    //!! Update to accept a user and proposalId
    function cancelProposalHelper() public {
        vm.prank(userA);
        trade.cancelProposal(1);
    }
}
