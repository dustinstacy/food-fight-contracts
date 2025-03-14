//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AssetSwap } from "@contracts/AssetSwap.sol";
import { AssetFactoryHelper } from "./AssetFactoryHelper.sol";

contract AssetSwapHelper is AssetFactoryHelper {
    // Create and instance of the AssetSwap contract that all tests will use
    AssetSwap swap = new AssetSwap(address(factory));

    // Create uint256 conversion of ProposalStatus enum
    uint256 pendingStatus = uint256(AssetSwap.ProposalStatus.Pending);
    uint256 approvedStatus = uint256(AssetSwap.ProposalStatus.Approved);
    uint256 rejectedStatus = uint256(AssetSwap.ProposalStatus.Rejected);
    uint256 canceledStatus = uint256(AssetSwap.ProposalStatus.Canceled);

    // Set up the testing environment using the AssetFactoryHelper functions
    function setUp() public virtual {
        setAssetsHelper();
        mintIGCHelper(user1, ONE_MILLION);
        mintIGCHelper(user2, ONE_MILLION);
        mintAssetHelper(user1, all);
        mintAssetHelper(user2, all);
    }

    // Create a proposal for the swap of two assets
    function createProposalHelper() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);
        swap.createProposal(user2, ASSET_ONE_ID, ASSET_TWO_ID);
        vm.stopPrank();
    }

    // Cancel a proposal
    function cancelProposalHelper() public {
        vm.prank(user1);
        swap.cancelProposal(ONE);
    }
}
