//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { AssetSwap } from "@contracts/AssetSwap.sol";
import { AssetFactorySetAssetsHelper } from "./AssetFactory.t.sol";

///////////////////////////////////////////////////////////
///                    EVENTS                           ///
///////////////////////////////////////////////////////////

// Emitted when a new proposal is created
event ProposalCreated(uint256 proposalId);

// Emitted when a proposal is approved
event ProposalApproved(uint256 proposalId);

// Emitted when a proposal is rejected
event ProposalRejected(uint256 proposalId);

// Emitted when a proposal is canceled
event ProposalCanceled(uint256 proposalId);

// Emitted when assets are withdrawn from the contract.
event AssetsWithdrawn(address to, uint256[] tokenIds, uint256[] amounts);

// Emitted when assets are deposited into the contract.
event AssetsDeposited(address from, uint256[] tokenIds, uint256[] amounts);

///////////////////////////////////////////////////////////
///                      HELPERS                        ///
///////////////////////////////////////////////////////////

contract AssetSwapSetupHelper is AssetFactorySetAssetsHelper {
    AssetSwap public swap;

    function setUp() public override {
        super.setUp();
        swap = new AssetSwap(address(factory));
    }
}

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetSwapConstructorTest is AssetSwapSetupHelper {
    function test_constructor() public {
        address expectedAddress = address(factory);
        address actualAddress = swap.getAssetsContract();

        // Check that the assets contract is set correctly
        assertEq(expectedAddress, actualAddress);
    }
}

///////////////////////////////////////////////////////////
///                    OWNER 1 TESTS                    ///
///////////////////////////////////////////////////////////

contract AssetSwapOwner1Test is AssetSwapSetupHelper {
    function test_createProposal() public { }

    function test_cancelProposal() public { }
}

///////////////////////////////////////////////////////////
///                     OWNER 2 TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetSwapOwner2Test is AssetSwapSetupHelper {
    function test_approveProposal() public { }

    function test_rejectProposal() public { }
}

///////////////////////////////////////////////////////////
///                    ASSETS TESTS                     ///
///////////////////////////////////////////////////////////

contract AssetSwapAssetsTest is AssetSwapSetupHelper {
    function test_withdrawAssets() public { }

    function test_depositAssets() public { }
}

///////////////////////////////////////////////////////////
///                  VIEW FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetSwapViewFunctionsTest is AssetSwapSetupHelper {
    function test_getProposal() public { }

    function test_getProposalOwner1() public { }

    function test_getProposalOwner2() public { }

    function test_getProposalAsset1TokenId() public { }

    function test_getProposalAsset2TokenId() public { }

    function test_getProposalStatus() public { }

    function test_getBalance() public { }

    function test_getProposalCount() public { }
}
