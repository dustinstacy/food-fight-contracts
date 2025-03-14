//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { AssetSwap } from "@contracts/AssetSwap.sol";
import { AssetSwapHelper } from "./helpers/AssetSwapHelper.sol";

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetSwapConstructorTest is AssetSwapHelper {
    function test_constructor() public view {
        address expectedAddress = address(factory);
        address actualAddress = swap.getAssetsContractAddress();

        // Check that the assets contract is set correctly
        assertEq(expectedAddress, actualAddress);
        // Check the proposal count is 0
        assertEq(0, swap.getProposalCount());
    }
}

///////////////////////////////////////////////////////////
///               USER 1 FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetSwapUser1CreateProposalTest is AssetSwapHelper {
    function test_createProposal_WithAssetDeposited() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);
        swap.depositAssets(asset1Single, amountSingle);

        uint256 user1SwapBalance = swap.getBalance(user1, ASSET_ONE_ID);

        // Check that the user has deposited the correct amount of assets
        assertEq(user1SwapBalance, ONE);

        swap.createProposal(user2, ASSET_ONE_ID, ASSET_TWO_ID);
        vm.stopPrank();

        uint256 expectedProposalCount = 1;
        uint256 actualProposalCount = swap.getProposalCount();

        // Check the proposal count was incremented
        assertEq(expectedProposalCount, actualProposalCount);

        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        uint256 proposalStatus = uint256(proposal.status);

        // Check the proposal was created correctly
        assertEq(user1, proposal.user1);
        assertEq(user2, proposal.user2);
        assertEq(ASSET_ONE_ID, proposal.asset1TokenId);
        assertEq(ASSET_TWO_ID, proposal.asset2TokenId);
        assertEq(proposalStatus, pendingStatus);

        uint256 expectedUser1SwapBalance = user1SwapBalance - ONE;
        uint256 actualUser1SwapBalance = swap.getBalance(user1, ASSET_ONE_ID);

        // Check that the user's swap contract balance was decreased
        assertEq(expectedUser1SwapBalance, actualUser1SwapBalance);

        uint256 expectedUser1FactoryBalance = TEN - ONE;
        uint256 actualUser1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);

        // Check that the user's assets contract balance was decreased
        assertEq(expectedUser1FactoryBalance, actualUser1FactoryBalance);
    }

    function test_createProposal_WithoutAssetDeposited() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);
        swap.createProposal(user2, ASSET_ONE_ID, ASSET_TWO_ID);
        vm.stopPrank();

        uint256 expectedProposalCount = ONE;
        uint256 actualProposalCount = swap.getProposalCount();

        // Check the proposal count was incremented
        assertEq(expectedProposalCount, actualProposalCount);

        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        uint256 proposalStatus = uint256(proposal.status);

        // Check the proposal was created correctly
        assertEq(user1, proposal.user1);
        assertEq(user2, proposal.user2);
        assertEq(ASSET_ONE_ID, proposal.asset1TokenId);
        assertEq(ASSET_TWO_ID, proposal.asset2TokenId);
        assertEq(proposalStatus, pendingStatus);

        uint256 expectedUser1SwapBalance = 0;
        uint256 actualUser1SwapBalance = swap.getBalance(user1, ASSET_ONE_ID);

        // Check that the user's swap asset balance has not changed
        assertEq(expectedUser1SwapBalance, actualUser1SwapBalance);

        uint256 expectedUser1FactoryBalance = TEN - ONE;
        uint256 actualUser1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);

        // Check that the user's assets contract balance was decreased
        assertEq(expectedUser1FactoryBalance, actualUser1FactoryBalance);
    }

    function test_createProposal_EmitsEvent() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);

        // Check that the ProposalCreated event was emitted
        vm.expectEmit(false, false, false, false, address(swap));
        emit AssetSwap.ProposalCreated(ONE);
        swap.createProposal(user2, ASSET_ONE_ID, ASSET_TWO_ID);
        vm.stopPrank();
    }

    function test_createProposal_RevertsIf_MissingApprovalForAll() public {
        vm.prank(user1);

        // Check that the function reverts with the ERC1155MissingApproval error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, address(swap), user1)
        );
        swap.createProposal(user2, ASSET_ONE_ID, ASSET_TWO_ID);
    }
}

contract AssetSwapUser1CancelProposalTest is AssetSwapHelper {
    function setUp() public override {
        super.setUp();
        createProposalHelper();
    }

    function test_cancelProposal() public {
        cancelProposalHelper();

        AssetSwap.Proposal memory proposal = swap.getProposal(ONE);
        uint256 status = uint256(proposal.status);

        // Convert the proposal status to an integer and check it was set correctly
        assertEq(status, canceledStatus);

        uint256 expectedUser1SwapBalance = ONE;
        uint256 actualUser1SwapBalance = swap.getBalance(user1, ASSET_ONE_ID);

        // Check that user1's asset balance was updated
        assertEq(expectedUser1SwapBalance, actualUser1SwapBalance);
    }

    function test_cancelProposal_EmitsEvent() public {
        vm.prank(user1);

        // Check that the ProposalCanceled event was emitted
        vm.expectEmit(false, false, false, false, address(swap));
        emit AssetSwap.ProposalCanceled(ONE);
        swap.cancelProposal(ONE);
    }

    function test_cancelProposal_RevertsIf_NotPendingStatus() public {
        vm.startPrank(user1);
        swap.cancelProposal(ONE);

        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        uint256 status = uint256(proposal.status);

        // Check that the call reverts when the proposal status is not pending
        vm.expectRevert(abi.encodeWithSelector(AssetSwap.AssetSwapProposalNotPending.selector, status));
        swap.cancelProposal(ONE);
        vm.stopPrank();
    }

    function test_cancelProposal_RevertsIf_NotUser1() public {
        vm.prank(user2);

        // Check that the call reverts when the user is not user1
        vm.expectRevert(abi.encodeWithSelector(AssetSwap.AssetSwapNotUser1.selector, user2, user1));
        swap.cancelProposal(ONE);
    }
}

///////////////////////////////////////////////////////////
///                 USER 2 FUNCTION TESTS               ///
///////////////////////////////////////////////////////////

contract AssetSwapUser2FunctionsTest is AssetSwapHelper {
    function setUp() public override {
        super.setUp();
        createProposalHelper();
    }

    function test_approveProposal_WithAssetDeposited() public {
        vm.startPrank(user2);
        factory.setApprovalForAll(address(swap), true);
        swap.depositAssets(asset2Single, amountSingle);

        uint256 user2SwapBalance = swap.getBalance(user2, ASSET_TWO_ID);

        // Check that the user has deposited the correct amount of assets
        assertEq(user2SwapBalance, ONE);

        swap.approveProposal(ONE);
        vm.stopPrank();

        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        uint256 status = uint256(proposal.status);

        // Check the proposal status was updated
        assertEq(status, approvedStatus);

        uint256 user1Asset1SwapBalance = swap.getBalance(user1, ASSET_ONE_ID);
        uint256 user1Asset2SwapBalance = swap.getBalance(user1, ASSET_TWO_ID);
        uint256 user2Asset1SwapBalance = swap.getBalance(user2, ASSET_ONE_ID);
        uint256 user2Asset2SwapBalance = swap.getBalance(user2, ASSET_TWO_ID);

        // Check that the assets were swapped
        assertEq(user1Asset1SwapBalance, 0);
        assertEq(user1Asset2SwapBalance, ONE);
        assertEq(user2Asset1SwapBalance, ONE);
        assertEq(user2Asset2SwapBalance, 0);

        uint256 expectedUser1Asset1FactoryBalance = TEN - ONE;
        uint256 actualUser1Asset1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);
        uint256 expectedUser2Asset2FactoryBalance = TEN - ONE;
        uint256 actualUser2Asset2FactoryBalance = factory.balanceOf(user2, ASSET_TWO_ID);

        // Check the asset contract balances are correct
        assertEq(expectedUser1Asset1FactoryBalance, actualUser1Asset1FactoryBalance);
        assertEq(expectedUser2Asset2FactoryBalance, actualUser2Asset2FactoryBalance);
    }

    function test_approveProposal_WithoutAssetDeposited() public {
        vm.startPrank(user2);
        factory.setApprovalForAll(address(swap), true);
        swap.approveProposal(ONE);
        vm.stopPrank();

        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        uint256 status = uint256(proposal.status);

        // Check the proposal status was updated
        assertEq(status, approvedStatus);

        uint256 user1Asset1SwapBalance = swap.getBalance(user1, ASSET_ONE_ID);
        uint256 user1Asset2SwapBalance = swap.getBalance(user1, ASSET_TWO_ID);
        uint256 user2Asset1SwapBalance = swap.getBalance(user2, ASSET_ONE_ID);
        uint256 user2Asset2SwapBalance = swap.getBalance(user2, ASSET_TWO_ID);

        // Check that the assets were swapped
        assertEq(user1Asset1SwapBalance, 0);
        assertEq(user1Asset2SwapBalance, ONE);
        assertEq(user2Asset1SwapBalance, ONE);
        assertEq(user2Asset2SwapBalance, 0);

        uint256 expectedUser1Asset1FactoryBalance = TEN - ONE;
        uint256 actualUser1Asset1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);
        uint256 expectedUser2Asset2FactoryBalance = TEN - ONE;
        uint256 actualUser2Asset2FactoryBalance = factory.balanceOf(user2, ASSET_TWO_ID);

        // Check the asset contract balances are correct
        assertEq(expectedUser1Asset1FactoryBalance, actualUser1Asset1FactoryBalance);
        assertEq(expectedUser2Asset2FactoryBalance, actualUser2Asset2FactoryBalance);
    }

    function test_approveProposal_EmitsEvent() public {
        vm.startPrank(user2);
        factory.setApprovalForAll(address(swap), true);

        // Check that the ProposalApproved event was emitted
        vm.expectEmit(false, false, false, false, address(swap));
        emit AssetSwap.ProposalApproved(ONE);
        swap.approveProposal(ONE);
        vm.stopPrank();
    }

    function test_approveProposal_RevertsIf_NotPendingStatus() public {
        cancelProposalHelper();

        vm.prank(user2);

        // Check that the call reverts when the proposal status is not pending
        vm.expectRevert(abi.encodeWithSelector(AssetSwap.AssetSwapProposalNotPending.selector, canceledStatus));
        swap.approveProposal(ONE);
    }

    function test_approveProposal_RevertsIf_NotUser2() public {
        vm.prank(user3);

        // Check that the call reverts when the user is not user2
        vm.expectRevert(abi.encodeWithSelector(AssetSwap.AssetSwapNotUser2.selector, user3, user2));
        swap.approveProposal(ONE);
    }

    function test_approveProposal_RevertsIf_MissingApprovalForAll() public {
        vm.prank(user2);

        // Check that the function reverts with the ERC1155MissingApproval error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, address(swap), user2)
        );
        swap.approveProposal(ONE);
    }

    function test_rejectProposal() public {
        vm.prank(user2);
        swap.rejectProposal(ONE);

        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        uint256 status = uint256(proposal.status);

        // Check the proposal status was updated
        assertEq(status, rejectedStatus);

        uint256 user1Asset1SwapBalance = swap.getBalance(user1, ASSET_ONE_ID);
        uint256 user1Asset2SwapBalance = swap.getBalance(user1, ASSET_TWO_ID);
        uint256 user2Asset1SwapBalance = swap.getBalance(user2, ASSET_ONE_ID);
        uint256 user2Asset2SwapBalance = swap.getBalance(user2, ASSET_TWO_ID);

        // Check that the user1's asset balance was updated
        assertEq(user1Asset1SwapBalance, ONE);
        assertEq(user1Asset2SwapBalance, 0);
        assertEq(user2Asset1SwapBalance, 0);
        assertEq(user2Asset2SwapBalance, 0);
    }

    function test_rejectProposal_EmitsEvent() public {
        vm.prank(user2);

        // Check that the ProposalRejected event was emitted
        vm.expectEmit(false, false, false, false, address(swap));
        emit AssetSwap.ProposalRejected(ONE);
        swap.rejectProposal(ONE);
    }

    function test_rejectProposal_RevertIf_NotPendingStatus() public {
        cancelProposalHelper();

        vm.prank(user2);

        // Check that the call reverts when the proposal status is not pending
        vm.expectRevert(abi.encodeWithSelector(AssetSwap.AssetSwapProposalNotPending.selector, canceledStatus));
        swap.rejectProposal(ONE);
    }

    function test_rejectProposal_RevertsIf_NotUser2() public {
        vm.prank(user3);

        // Check that the call reverts when the user is not user2
        vm.expectRevert(abi.encodeWithSelector(AssetSwap.AssetSwapNotUser2.selector, user3, user2));
        swap.rejectProposal(ONE);
    }
}

///////////////////////////////////////////////////////////
///                DEPOSIT FUNCTION TESTS               ///
///////////////////////////////////////////////////////////

contract AssetSwapDepositAssetsTest is AssetSwapHelper {
    function test_depositAssets() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);
        swap.depositAssets(asset1Single, amountSingle);
        vm.stopPrank();

        uint256 user1AssetBalance = swap.getBalance(user1, ASSET_ONE_ID);

        // Check that the user has deposited the correct amount of assets
        assertEq(user1AssetBalance, ONE);
    }

    function test_depositAssets_Multiple() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);
        swap.depositAssets(assetIds, all);
        vm.stopPrank();

        uint256 user1Asset1Balance = swap.getBalance(user1, ASSET_ONE_ID);
        uint256 user1Asset2Balance = swap.getBalance(user1, ASSET_TWO_ID);
        uint256 user1Asset3Balance = swap.getBalance(user1, ASSET_THREE_ID);

        // Check that the user has deposited the correct amount of assets
        assertEq(user1Asset1Balance, TEN);
        assertEq(user1Asset2Balance, TEN);
        assertEq(user1Asset3Balance, TEN);
    }

    function test_depositAssets_EmitsEvent() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);

        // Check that the AssetsDeposited event was emitted
        vm.expectEmit(false, false, false, false, address(swap));
        emit AssetSwap.AssetsDeposited(user1, asset1Single, amountSingle);
        swap.depositAssets(asset1Single, amountSingle);
        vm.stopPrank();
    }

    function test_depositAssets_RevertsIf_ArraysLengthMismatch() public {
        vm.prank(user1);

        // Check that the function reverts with the AssetSwapArraysLengthMismatch error
        vm.expectRevert(
            abi.encodeWithSelector(AssetSwap.AssetSwapArraysLengthMismatch.selector, assetIds.length, invalid.length)
        );
        swap.depositAssets(assetIds, invalid);
    }

    function test_depositAssets_RevertsIf_InsufficientBalance() public {
        amountSingle[0] = ONE_MILLION;

        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user1, TEN, ONE_MILLION, ASSET_ONE_ID
            )
        );
        swap.depositAssets(asset1Single, amountSingle);
        vm.stopPrank();
    }
}

///////////////////////////////////////////////////////////
///               WITHDRAW FUNCTION TESTS               ///
///////////////////////////////////////////////////////////

contract AssetSwapWithdrawAssetsTest is AssetSwapHelper {
    function setUp() public override {
        super.setUp();
        vm.startPrank(user1);
        factory.setApprovalForAll(address(swap), true);
        swap.depositAssets(assetIds, all);
        vm.stopPrank();
    }

    function test_withdrawAssets() public {
        vm.prank(user1);
        swap.withdrawAssets(asset1Single, amountSingle);

        uint256 expectedUser1Asset1SwapBalance = TEN - ONE;
        uint256 actualUser1Asset1SwapBalance = swap.getBalance(user1, ASSET_ONE_ID);

        // Check that the user's asset balance was updated
        assertEq(expectedUser1Asset1SwapBalance, actualUser1Asset1SwapBalance);

        uint256 expectedUser1Asset1FactoryBalance = ONE;
        uint256 actualUser1Asset1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);

        // Check the asset contract balance to ensure the assets were withdrawn
        assertEq(expectedUser1Asset1FactoryBalance, actualUser1Asset1FactoryBalance);
    }

    function test_withdrawAssets_Multiple() public {
        vm.prank(user1);
        swap.withdrawAssets(assetIds, all);

        uint256 expectedUser1Asset1SwapBalance = 0;
        uint256 expectedUser1Asset2SwapBalance = 0;
        uint256 expectedUser1Asset3SwapBalance = 0;
        uint256 actualUser1Asset1SwapBalance = swap.getBalance(user1, ASSET_ONE_ID);
        uint256 actualUser1Asset2SwapBalance = swap.getBalance(user1, ASSET_TWO_ID);
        uint256 actualUser1Asset3SwapBalance = swap.getBalance(user1, ASSET_THREE_ID);

        // Check that the user's asset balance was updated
        assertEq(expectedUser1Asset1SwapBalance, actualUser1Asset1SwapBalance);
        assertEq(expectedUser1Asset2SwapBalance, actualUser1Asset2SwapBalance);
        assertEq(expectedUser1Asset3SwapBalance, actualUser1Asset3SwapBalance);

        uint256 expectedUser1Asset1FactoryBalance = TEN;
        uint256 expectedUser1Asset2FactoryBalance = TEN;
        uint256 expectedUser1Asset3FactoryBalance = TEN;
        uint256 actualUser1Asset1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);
        uint256 actualUser1Asset2FactoryBalance = factory.balanceOf(user1, ASSET_TWO_ID);
        uint256 actualUser1Asset3FactoryBalance = factory.balanceOf(user1, ASSET_THREE_ID);

        // Check the asset contract balance to ensure the assets were withdrawn
        assertEq(expectedUser1Asset1FactoryBalance, actualUser1Asset1FactoryBalance);
        assertEq(expectedUser1Asset2FactoryBalance, actualUser1Asset2FactoryBalance);
        assertEq(expectedUser1Asset3FactoryBalance, actualUser1Asset3FactoryBalance);
    }

    function test_withdrawAssets_AfterCancelingProposal() public {
        createProposalHelper();

        vm.startPrank(user1);
        swap.cancelProposal(ONE);
        swap.withdrawAssets(asset1Single, amountSingle);

        uint256 expectedUser1SwapBalance = TEN - ONE;
        uint256 actualUser1SwapBalance = swap.getBalance(user1, ASSET_ONE_ID);

        // Check that the user's asset balance was updated
        assertEq(expectedUser1SwapBalance, actualUser1SwapBalance);

        uint256 expectedUser1FactoryBalance = ONE;
        uint256 actualUser1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);

        // Check the asset contract balance to ensure the assets were withdrawn
        assertEq(expectedUser1FactoryBalance, actualUser1FactoryBalance);
    }

    function test_withdrawAssets_AfterApproval() public {
        createProposalHelper();

        vm.startPrank(user2);
        factory.setApprovalForAll(address(swap), true);
        swap.approveProposal(ONE);
        vm.stopPrank();

        vm.prank(user1);
        swap.withdrawAssets(asset2Single, amountSingle);

        vm.prank(user2);
        swap.withdrawAssets(asset1Single, amountSingle);

        uint256 expectedUser1Asset1SwapBalance = TEN - ONE;
        uint256 expectedUser1Asset2SwapBalance = TEN;
        uint256 actualUser1Asset1SwapBalance = swap.getBalance(user1, ASSET_ONE_ID);
        uint256 actualUser1Asset2SwapBalance = swap.getBalance(user1, ASSET_TWO_ID);

        // Check that the user1's swap contract balances are correct
        assertEq(expectedUser1Asset1SwapBalance, actualUser1Asset1SwapBalance);
        assertEq(expectedUser1Asset2SwapBalance, actualUser1Asset2SwapBalance);

        uint256 expectedUser2Asset1SwapBalance = 0;
        uint256 expectedUser2Asset2SwapBalance = 0;
        uint256 actualUser2Asset1SwapBalance = swap.getBalance(user2, ASSET_ONE_ID);
        uint256 actualUser2Asset2SwapBalance = swap.getBalance(user2, ASSET_TWO_ID);

        // Check that the user2's swap contract balances are correct
        assertEq(expectedUser2Asset1SwapBalance, actualUser2Asset1SwapBalance);
        assertEq(expectedUser2Asset2SwapBalance, actualUser2Asset2SwapBalance);

        uint256 expectedUser1Asset1FactoryBalance = 0;
        uint256 expectedUser1Asset2FactoryBalance = ONE;
        uint256 actualUser1Asset1FactoryBalance = factory.balanceOf(user1, ASSET_ONE_ID);
        uint256 actualUser1Asset2FactoryBalance = factory.balanceOf(user1, ASSET_TWO_ID);

        // Check that the user1's asset contract balances are correct
        assertEq(expectedUser1Asset1FactoryBalance, actualUser1Asset1FactoryBalance);
        assertEq(expectedUser1Asset2FactoryBalance, actualUser1Asset2FactoryBalance);

        uint256 expectedUser2Asset1FactoryBalance = TEN + ONE;
        uint256 expectedUser2Asset2FactoryBalance = TEN - ONE;
        uint256 actualUser2Asset2FactoryBalance = factory.balanceOf(user2, ASSET_TWO_ID);
        uint256 actualUser2Asset1FactoryBalance = factory.balanceOf(user2, ASSET_ONE_ID);

        // Check that the user2's asset contract balances are correct
        assertEq(expectedUser2Asset2FactoryBalance, actualUser2Asset2FactoryBalance);
        assertEq(expectedUser2Asset1FactoryBalance, actualUser2Asset1FactoryBalance);
    }

    function test_withdrawAssets_EmitsEvent() public {
        vm.prank(user1);

        // Check that the AssetsWithdrawn event was emitted
        vm.expectEmit(false, false, false, false, address(swap));
        emit AssetSwap.AssetsWithdrawn(user1, asset1Single, amountSingle);
        swap.withdrawAssets(asset1Single, amountSingle);
    }

    function test_withdrawAssets_RevertsIf_ArrayLengthMismatch() public {
        vm.prank(user1);

        // Check that the function reverts with the AssetSwapArraysLengthMismatch error
        vm.expectRevert(
            abi.encodeWithSelector(AssetSwap.AssetSwapArraysLengthMismatch.selector, assetIds.length, invalid.length)
        );
        swap.withdrawAssets(assetIds, invalid);
        vm.stopPrank();
    }

    function test_withdrawAssets_RevertsIf_InsufficientBalance() public {
        amountSingle[0] = ONE_MILLION;

        vm.prank(user1);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetSwap.AssetSwapInsufficientBalance.selector, user1, TEN, ONE_MILLION, ASSET_ONE_ID
            )
        );
        swap.withdrawAssets(asset1Single, amountSingle);
    }
}

///////////////////////////////////////////////////////////
///                  VIEW FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetSwapViewFunctionsTest is AssetSwapHelper {
    function setUp() public override {
        super.setUp();
        createProposalHelper();
    }

    function test_getProposal() public view {
        AssetSwap.Proposal memory proposal = swap.getProposal(1);
        uint256 status = uint256(proposal.status);

        // Check the proposal was created correctly
        assertEq(user1, proposal.user1);
        assertEq(user2, proposal.user2);
        assertEq(ASSET_ONE_ID, proposal.asset1TokenId);
        assertEq(ASSET_TWO_ID, proposal.asset2TokenId);
        assertEq(status, pendingStatus);
    }

    function test_getProposalUser1() public view {
        address user1Address = swap.getProposalUser1(1);

        // Check that the user1 address is correct
        assertEq(user1, user1Address);
    }

    function test_getProposalUser2() public view {
        address user2Address = swap.getProposalUser2(1);

        // Check that the user2 address is correct
        assertEq(user2, user2Address);
    }

    function test_getProposalAsset1TokenId() public view {
        uint256 asset1TokenId = swap.getProposalAsset1TokenId(1);

        // Check that the asset1 token ID is correct
        assertEq(ASSET_ONE_ID, asset1TokenId);
    }

    function test_getProposalAsset2TokenId() public view {
        uint256 asset2TokenId = swap.getProposalAsset2TokenId(1);

        // Check that the asset2 token ID is correct
        assertEq(ASSET_TWO_ID, asset2TokenId);
    }

    function test_getProposalStatus() public view {
        uint256 status = uint256(swap.getProposalStatus(1));

        // Check that the proposal status is correct
        assertEq(status, pendingStatus);
    }

    function test_getBalance() public view {
        uint256 balance = swap.getBalance(user1, ASSET_ONE_ID);

        // Check that the user's balance is correct
        assertEq(balance, 0);
    }

    function test_getProposalCount() public view {
        uint256 proposalCount = swap.getProposalCount();

        // Check that the proposal count is correct
        assertEq(proposalCount, ONE);
    }

    function test_getAssetsContractAddress() public view {
        address assetsContract = swap.getAssetsContractAddress();

        // Check that the assets contract address is correct
        assertEq(address(factory), assetsContract);
    }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetSwapERC1155ReceiverTest is AssetSwapHelper {
    function test_onERC1155Received() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        bytes4 returnedSelector = swap.onERC1155Received(address(0), address(0), 0, 0, "");

        // Check that the correct selector was returned
        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        bytes4 returnedSelector =
            swap.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");

        // Check that the correct selector was returned
        assertEq(returnedSelector, expectedSelector);
    }
}

///////////////////////////////////////////////////////////
///               IERC165 INTERFACE TESTS               ///
///////////////////////////////////////////////////////////

contract AssetSwapERC165Test is AssetSwapHelper {
    function test_supportsInterfaceIdIERC165() public view {
        bytes4 expectedSelector = 0x01ffc9a7;
        bool returnedSelector = swap.supportsInterface(expectedSelector);

        // Check that the contract supports the IERC165 interface
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceIdIERC1155Receiver() public view {
        bytes4 expectedSelector = 0x4e2312e0;
        bool returnedSelector = swap.supportsInterface(expectedSelector);

        // Check that the contract supports the IERC1155Receiver interface
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceBadSelector() public view {
        bytes4 badSelector = bytes4(keccak256("badSelector"));
        bool returnedSelector = swap.supportsInterface(badSelector);

        // Check that the contract throws false for an unsupported interface
        assertEq(returnedSelector, false);
    }
}
