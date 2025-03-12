//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
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
    address public user1;
    address public user2;

    uint256 constant DEPOSIT_1 = 1;
    uint256 constant DEPOSIT_5 = 5;
    uint256 constant DEPOSIT_10 = 10;

    uint256 pendingStatus = uint256(AssetSwap.ProposalStatus.Pending);
    uint256 approvedStatus = uint256(AssetSwap.ProposalStatus.Approved);
    uint256 rejectedStatus = uint256(AssetSwap.ProposalStatus.Rejected);
    uint256 canceledStatus = uint256(AssetSwap.ProposalStatus.Canceled);

    function setUp() public virtual override {
        super.setUp();
        swap = new AssetSwap(address(factory));
        user1 = user;
        user2 = address(3);
        setUpAssets();
        mintInitialIGC(user1, MINT_1000000);
        mintInitialIGC(user2, MINT_1000000);
        mintInitialAssets(user1, MINT_10);
        mintInitialAssets(user2, MINT_10);

        uint256 totalPrice = (MINT_10 * ASSET_ONE_PRICE) + (MINT_10 * ASSET_TWO_PRICE) + (MINT_10 * ASSET_THREE_PRICE);

        assertEq(MINT_10, factory.balanceOf(user1, ASSET_ONE_ID));
        assertEq(MINT_10, factory.balanceOf(user2, ASSET_ONE_ID));
        assertEq(MINT_10, factory.balanceOf(user1, ASSET_TWO_ID));
        assertEq(MINT_10, factory.balanceOf(user2, ASSET_TWO_ID));
        assertEq(MINT_10, factory.balanceOf(user1, ASSET_THREE_ID));
        assertEq(MINT_10, factory.balanceOf(user2, ASSET_THREE_ID));
        assertEq(MINT_1000000 - totalPrice, factory.balanceOf(user1, IGC_TOKEN_ID));
        assertEq(MINT_1000000 - totalPrice, factory.balanceOf(user2, IGC_TOKEN_ID));
        assertEq(user1, address(2));
        assertEq(user2, address(3));
    }
}

contract AssetSwapCreateProposalHelper is AssetSwapSetupHelper {
    function setUp() public override {
        super.setUp();
        depositAssets();
        createProposal();
    }

    function depositAssets() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_1;

        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);
        swap.depositAssets(tokenIds, amounts);
        vm.stopPrank();

        // Check that the user has deposited the correct amount of assets
        uint256 user1AssetBalance = swap.getBalance(user1, ASSET_ONE_ID);
        assertEq(user1AssetBalance, DEPOSIT_1);
    }

    function createProposal() public {
        vm.startPrank(user1);
        swap.createProposal(user2, ASSET_ONE_ID, ASSET_TWO_ID);

        // Ensure validity of data for inheriting tests
        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        assertEq(user1, proposal.user1);
        assertEq(user2, proposal.user2);
        assertEq(ASSET_ONE_ID, proposal.asset1TokenId);
        assertEq(ASSET_TWO_ID, proposal.asset2TokenId);
        uint256 proposalStatus = uint256(proposal.status);
        assertEq(proposalStatus, pendingStatus);
    }
}

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetSwapConstructorTest is AssetSwapSetupHelper {
    function test_constructor() public view {
        address expectedAddress = address(factory);
        address actualAddress = swap.getAssetsContract();

        // Check that the assets contract is set correctly
        assertEq(expectedAddress, actualAddress);
        // Check the proposal count is 0
        assertEq(0, swap.getProposalCount());
    }
}

///////////////////////////////////////////////////////////
///                    USER 1 TESTS                     ///
///////////////////////////////////////////////////////////

contract AssetSwapUser1Test is AssetSwapSetupHelper {
    function test_createProposalWithAssetDeposited() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenIds[0] = ASSET_ONE_ID;
        amounts[0] = DEPOSIT_1;

        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);
        swap.depositAssets(tokenIds, amounts);

        // Check that the user has deposited the correct amount of assets
        uint256 user1AssetBalance = swap.getBalance(user1, ASSET_ONE_ID);
        assertEq(user1AssetBalance, DEPOSIT_1);

        swap.createProposal(user2, ASSET_ONE_ID, ASSET_TWO_ID);
        vm.stopPrank();

        // Check the proposal count was incremented
        uint256 expectedProposalCount = 1;
        uint256 actualProposalCount = swap.getProposalCount();
        assertEq(expectedProposalCount, actualProposalCount);

        // Check the proposal was created correctly
        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        assertEq(user1, proposal.user1);
        assertEq(user2, proposal.user2);
        assertEq(ASSET_ONE_ID, proposal.asset1TokenId);
        assertEq(ASSET_TWO_ID, proposal.asset2TokenId);

        // Convert the proposal status to an integer and check it was set correctly
        uint256 proposalStatus = uint256(proposal.status);
        assertEq(proposalStatus, pendingStatus);

        // Check that the user's asset balance was decremented
        uint256 expectedUser1AssetBalance = user1AssetBalance - DEPOSIT_1;
        uint256 actualUser1AssetBalance = swap.getBalance(user1, ASSET_ONE_ID);
        assertEq(expectedUser1AssetBalance, actualUser1AssetBalance);
    }

    function test_createProposalWithoutAssetDeposited() public {
        // Check the user has not deposited any of the asset
        uint256 user1AssetBalance = swap.getBalance(user1, ASSET_ONE_ID);
        assertEq(user1AssetBalance, 0);

        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);
        swap.createProposal(user2, ASSET_ONE_ID, ASSET_TWO_ID);
        vm.stopPrank();

        // Check the proposal count was incremented
        uint256 expectedProposalCount = 1;
        uint256 actualProposalCount = swap.getProposalCount();
        assertEq(expectedProposalCount, actualProposalCount);

        // Check the proposal was created correctly
        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        assertEq(user1, proposal.user1);
        assertEq(user2, proposal.user2);
        assertEq(ASSET_ONE_ID, proposal.asset1TokenId);
        assertEq(ASSET_TWO_ID, proposal.asset2TokenId);

        // Convert the proposal status to an integer and check it was set correctly
        uint256 proposalStatus = uint256(proposal.status);
        assertEq(proposalStatus, pendingStatus);

        // Check that the user's asset balance was not decremented
        uint256 expectedUser1AssetBalance = user1AssetBalance;
        uint256 actualUser1AssetBalance = swap.getBalance(user1, ASSET_ONE_ID);
        assertEq(expectedUser1AssetBalance, actualUser1AssetBalance);
    }

    function test_createProposal_EmitEvent() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);

        // Check that the ProposalCreated event was emitted
        vm.expectEmit(false, false, false, false, address(swap));
        emit ProposalCreated(1);
        swap.createProposal(user2, ASSET_ONE_ID, ASSET_TWO_ID);
        vm.stopPrank();
    }
}

contract AssetSwapUser1CancelProposalTest is AssetSwapCreateProposalHelper {
    function test_cancelProposal() public {
        vm.startPrank(user1);
        swap.cancelProposal(1);
        vm.stopPrank();

        AssetSwap.Proposal memory proposal = swap.getProposal(1);

        // Convert the proposal status to an integer and check it was set correctly
        uint256 status = uint256(proposal.status);
        assertEq(status, canceledStatus);

        // Check that user1's asset balance was updated
        uint256 expectedUser1AssetBalance = DEPOSIT_1;
        uint256 actualUser1AssetBalance = swap.getBalance(user1, ASSET_ONE_ID);
        assertEq(expectedUser1AssetBalance, actualUser1AssetBalance);
    }

    function test_cancelProposal_EmitEvent() public {
        vm.startPrank(user1);
        vm.expectEmit(false, false, false, false, address(swap));
        emit ProposalCanceled(1);
        swap.cancelProposal(1);
        vm.stopPrank();
    }

    function test_cancelProposal_RevertWhen_StatusNotPending() public {
        vm.startPrank(user1);
        swap.cancelProposal(1);

        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        uint256 status = uint256(proposal.status);

        // Check that the call reverts when the proposal status is not pending
        vm.expectRevert(abi.encodeWithSelector(AssetSwap.AssetSwapProposalNotPending.selector, status));
        swap.cancelProposal(1);
        vm.stopPrank();
    }

    function test_cancelProposal_RevertWhen_NotUser1() public {
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(AssetSwap.AssetSwapNotUser1.selector, user2, user1));
        swap.cancelProposal(1);
        vm.stopPrank();
    }
}

///////////////////////////////////////////////////////////
///                     USER 2 TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetSwapUser2Test is AssetSwapCreateProposalHelper {
    function test_approveProposalWithAssetDeposited() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenIds[0] = ASSET_TWO_ID;
        amounts[0] = DEPOSIT_1;

        vm.startPrank(user2);
        factory.setApprovalForAll(address(swap), true);
        swap.depositAssets(tokenIds, amounts);

        // Check that the user has deposited the correct amount of assets
        uint256 user2AssetBalance = swap.getBalance(user2, ASSET_TWO_ID);
        assertEq(user2AssetBalance, DEPOSIT_1);

        swap.approveProposal(1);
        vm.stopPrank();

        // Check the proposal status was updated
        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        uint256 status = uint256(proposal.status);
        assertEq(status, approvedStatus);

        uint256 user1Asset1Balance = swap.getBalance(user1, ASSET_ONE_ID);
        uint256 user1Asset2Balance = swap.getBalance(user1, ASSET_TWO_ID);
        uint256 user2Asset1Balance = swap.getBalance(user2, ASSET_ONE_ID);
        uint256 user2Asset2Balance = swap.getBalance(user2, ASSET_TWO_ID);

        // Check that the assets were swapped
        assertEq(user1Asset1Balance, 0);
        assertEq(user1Asset2Balance, DEPOSIT_1);
        assertEq(user2Asset1Balance, DEPOSIT_1);
        assertEq(user2Asset2Balance, 0);

        // Check the asset contract balances to ensure no extra assets were deposited
        assertEq(MINT_10 - DEPOSIT_1, factory.balanceOf(user1, ASSET_ONE_ID));
        assertEq(MINT_10 - DEPOSIT_1, factory.balanceOf(user2, ASSET_TWO_ID));
    }

    function test_approveProposalWithoutAssetDeposited() public {
        vm.startPrank(user2);
        factory.setApprovalForAll(address(swap), true);
        swap.approveProposal(1);
        vm.stopPrank();

        // Check the proposal status was updated
        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        uint256 status = uint256(proposal.status);
        assertEq(status, approvedStatus);

        uint256 user1Asset1Balance = swap.getBalance(user1, ASSET_ONE_ID);
        uint256 user1Asset2Balance = swap.getBalance(user1, ASSET_TWO_ID);
        uint256 user2Asset1Balance = swap.getBalance(user2, ASSET_ONE_ID);
        uint256 user2Asset2Balance = swap.getBalance(user2, ASSET_TWO_ID);

        // Check that the assets were swapped
        assertEq(user1Asset1Balance, 0);
        assertEq(user1Asset2Balance, DEPOSIT_1);
        assertEq(user2Asset1Balance, DEPOSIT_1);
        assertEq(user2Asset2Balance, 0);

        // Check the asset contract balances to ensure no extra assets were deposited
        assertEq(MINT_10 - DEPOSIT_1, factory.balanceOf(user1, ASSET_ONE_ID));
        assertEq(MINT_10 - DEPOSIT_1, factory.balanceOf(user2, ASSET_TWO_ID));
    }

    function test_approveProposal_EmitEvent() public {
        vm.startPrank(user2);
        factory.setApprovalForAll(address(swap), true);
        vm.expectEmit(false, false, false, false, address(swap));
        emit ProposalApproved(1);
        swap.approveProposal(1);
        vm.stopPrank();
    }

    function test_rejectProposal() public {
        vm.startPrank(user2);
        swap.rejectProposal(1);
        vm.stopPrank();

        // Check the proposal status was updated
        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        uint256 status = uint256(proposal.status);
        assertEq(status, rejectedStatus);

        // Check that the user's asset balance was not updated
        uint256 user1Asset1Balance = swap.getBalance(user1, ASSET_ONE_ID);
        uint256 user1Asset2Balance = swap.getBalance(user1, ASSET_TWO_ID);
        uint256 user2Asset1Balance = swap.getBalance(user2, ASSET_ONE_ID);
        uint256 user2Asset2Balance = swap.getBalance(user2, ASSET_TWO_ID);

        assertEq(user1Asset1Balance, DEPOSIT_1);
        assertEq(user1Asset2Balance, 0);
        assertEq(user2Asset1Balance, 0);
        assertEq(user2Asset2Balance, 0);
    }

    function test_rejectProposal_EmitEvent() public {
        vm.startPrank(user2);
        vm.expectEmit(false, false, false, false, address(swap));
        emit ProposalRejected(1);
        swap.rejectProposal(1);
        vm.stopPrank();
    }
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

    function test_getProposalUser1() public { }

    function test_getProposalUser2() public { }

    function test_getProposalAsset1TokenId() public { }

    function test_getProposalAsset2TokenId() public { }

    function test_getProposalStatus() public { }

    function test_getBalance() public { }

    function test_getProposalCount() public { }
}
