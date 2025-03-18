//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { AssetVault } from "@contracts/AssetVault.sol";
import { AssetTrade } from "@contracts/AssetTrade.sol";
import { AssetTradeTestHelper } from "./helpers/AssetTradeTestHelper.sol";

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetTradeConstructorTest is AssetTradeTestHelper {
    function test_constructor() public view {
        address expectedFactoryAddress = address(factory);
        address expectedVaultAddress = address(vault);
        address actualFactoryAddress = trade.getAssetFactoryAddress();
        address actualVaultAddress = trade.getAssetVaultAddress();

        // Check that the factory and vault addresses are correct
        assertEq(expectedFactoryAddress, actualFactoryAddress);
        assertEq(expectedVaultAddress, actualVaultAddress);
        // Check the proposal count is 0
        assertEq(0, trade.getProposalCount());
    }
}

///////////////////////////////////////////////////////////
///              PROPOSER FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetTradeProposerCreateProposalTest is AssetTradeTestHelper {
    function test_createProposal() public {
        vm.prank(userA);
        trade.createProposal(userB, ASSET_ONE_ID, ASSET_TWO_ID);

        AssetTrade.Proposal memory proposal = trade.getProposal(1);
        address proposer = proposal.proposer;
        address receiver = proposal.receiver;
        uint256 assetAId = uint256(proposal.assetAId);
        uint256 assetBId = uint256(proposal.assetBId);
        uint256 proposalStatus = uint256(proposal.status);

        // Check that the proposal was created correctly
        assertEq(proposer, userA);
        assertEq(receiver, userB);
        assertEq(assetAId, ASSET_ONE_ID);
        assertEq(assetBId, ASSET_TWO_ID);
        assertEq(proposalStatus, pendingStatus);
    }

    function test_createProposal_ProposalCountIncremented() public {
        createProposalHelper();

        uint256 proposalCount = trade.getProposalCount();

        // Check that the proposal count was incremented
        assertEq(proposalCount, 1);
    }

    function test_createProposal_AssetLocked() public {
        createProposalHelper();

        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);

        // Check that userA's asset balance was updated
        assertEq(userAEndingVaultAssetOneBalance, userAStartingVaultAssetOneBalance - 1);
    }

    function test_createProposal_EventEmitted() public {
        vm.prank(userA);

        // Check that the ProposalCreated event was emitted
        vm.expectEmit(false, false, false, false, address(trade));
        emit AssetTrade.ProposalCreated(1);
        trade.createProposal(userB, ASSET_ONE_ID, ASSET_TWO_ID);
    }

    function test_createProposal_RevertsIf_InsufficientBalance() public {
        vm.prank(userA);

        // Check that the call reverts with the AssetVaultInsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(AssetVault.AssetVaultInsufficientBalance.selector, userA, 0, 1, ASSET_THREE_ID)
        );
        trade.createProposal(userB, ASSET_THREE_ID, ASSET_TWO_ID);
    }
}

contract AssetTradeProposerCancelProposalTest is AssetTradeTestHelper {
    function setUp() public override {
        super.setUp();
        createProposalHelper();

        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
    }

    function test_cancelProposal() public {
        vm.prank(userA);
        trade.cancelProposal(1);

        AssetTrade.Proposal memory proposal = trade.getProposal(1);
        uint256 status = uint256(proposal.status);
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);

        // Check that the proposal status was updated
        assertEq(status, canceledStatus);
        // Check that userA's asset balance was updated
        assertEq(userAEndingVaultAssetOneBalance, userAStartingVaultAssetOneBalance + 1);
    }

    function test_cancelProposal_EventEmitted() public {
        vm.prank(userA);

        // Check that the ProposalCanceled event was emitted
        vm.expectEmit(false, false, false, false, address(trade));
        emit AssetTrade.ProposalCanceled(1);
        trade.cancelProposal(1);
    }

    function test_cancelProposal_RevertsIf_NotPendingStatus() public {
        vm.startPrank(userA);
        trade.cancelProposal(1);

        AssetTrade.Proposal memory proposal = trade.getProposal(1);
        uint256 status = uint256(proposal.status);

        // Check that the call reverts when the proposal status is not pending
        vm.expectRevert(abi.encodeWithSelector(AssetTrade.AssetTradeProposalNotPending.selector, status));
        trade.cancelProposal(1);
        vm.stopPrank();
    }

    function test_cancelProposal_RevertsIf_NotProposer() public {
        vm.prank(userB);

        // Check that the call reverts when the user is not the proposer
        vm.expectRevert(abi.encodeWithSelector(AssetTrade.AssetTradeNotProposer.selector, userB, userA));
        trade.cancelProposal(1);
    }
}

///////////////////////////////////////////////////////////
///               RECEIVER FUNCTION TESTS               ///
///////////////////////////////////////////////////////////

contract AssetTradeReceiverFunctionsTest is AssetTradeTestHelper {
    function setUp() public override {
        super.setUp();
        createProposalHelper();

        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
    }

    function test_approveProposal() public {
        vm.prank(userB);
        trade.approveProposal(1);

        AssetTrade.Proposal memory proposal = trade.getProposal(1);
        uint256 status = uint256(proposal.status);
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        uint256 userAEndingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        uint256 userBEndingVaultAssetOneBalance = vault.balanceOf(userB, ASSET_ONE_ID);
        uint256 userBEndingVaultAssetTwoBalance = vault.balanceOf(userB, ASSET_TWO_ID);

        // Check that the proposal status was updated
        assertEq(status, approvedStatus);
        // Check that both user's asset balances were updated
        assertEq(userAEndingVaultAssetOneBalance, userAStartingVaultAssetOneBalance);
        assertEq(userAEndingVaultAssetTwoBalance, userAStartingVaultAssetTwoBalance + 1);
        assertEq(userBEndingVaultAssetOneBalance, userBStartingVaultAssetOneBalance + 1);
        assertEq(userBEndingVaultAssetTwoBalance, userBStartingVaultAssetTwoBalance - 1);
    }

    function test_approveProposal_EventEmitted() public {
        vm.prank(userB);

        // Check that the ProposalApproved event was emitted
        vm.expectEmit(false, false, false, false, address(trade));
        emit AssetTrade.ProposalApproved(1);
        trade.approveProposal(1);
    }

    function test_approveProposal_RevertsIf_NotPendingStatus() public {
        cancelProposalHelper();

        vm.prank(userB);

        // Check that the call reverts when the proposal status is not pending
        vm.expectRevert(abi.encodeWithSelector(AssetTrade.AssetTradeProposalNotPending.selector, canceledStatus));
        trade.approveProposal(1);
    }

    function test_approveProposal_RevertsIf_NotReceiver() public {
        vm.prank(userC);

        // Check that the call reverts when the user is not the proposal receiver
        vm.expectRevert(abi.encodeWithSelector(AssetTrade.AssetTradeNotReceiver.selector, userC, userB));
        trade.approveProposal(1);
    }

    function test_rejectProposal() public {
        vm.prank(userB);
        trade.rejectProposal(1);

        AssetTrade.Proposal memory proposal = trade.getProposal(1);
        uint256 status = uint256(proposal.status);
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);

        // Check that the proposal status was updated
        assertEq(status, rejectedStatus);
        // Check that userA's asset balance was updated
        assertEq(userAEndingVaultAssetOneBalance, userAStartingVaultAssetOneBalance + 1);
    }

    function test_rejectProposal_EventEmitted() public {
        vm.prank(userB);

        // Check that the ProposalRejected event was emitted
        vm.expectEmit(false, false, false, false, address(trade));
        emit AssetTrade.ProposalRejected(1);
        trade.rejectProposal(1);
    }

    function test_rejectProposal_RevertIf_NotPendingStatus() public {
        cancelProposalHelper();

        vm.prank(userB);

        // Check that the call reverts when the proposal status is not pending
        vm.expectRevert(abi.encodeWithSelector(AssetTrade.AssetTradeProposalNotPending.selector, canceledStatus));
        trade.rejectProposal(1);
    }

    function test_rejectProposal_RevertsIf_NotReceiver() public {
        vm.prank(userC);

        // Check that the call reverts when the user is not the proposal receiver
        vm.expectRevert(abi.encodeWithSelector(AssetTrade.AssetTradeNotReceiver.selector, userC, userB));
        trade.rejectProposal(1);
    }
}

///////////////////////////////////////////////////////////
///                  VIEW FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetTradeViewFunctionsTest is AssetTradeTestHelper {
    function setUp() public override {
        super.setUp();
        createProposalHelper();
    }

    function test_getProposal() public view {
        AssetTrade.Proposal memory proposal = trade.getProposal(1);
        address proposer = proposal.proposer;
        address receiver = proposal.receiver;
        uint256 assetAId = uint256(proposal.assetAId);
        uint256 assetBId = uint256(proposal.assetBId);
        uint256 status = uint256(proposal.status);

        // Check that the proposal was retrieved correctly
        assertEq(proposer, userA);
        assertEq(receiver, userB);
        assertEq(assetAId, ASSET_ONE_ID);
        assertEq(assetBId, ASSET_TWO_ID);
        assertEq(status, pendingStatus);
    }

    function test_getProposalProposer() public view {
        address proposer = trade.getProposalProposer(1);

        // Check that the proposer address is correct
        assertEq(userA, proposer);
    }

    function test_getProposalReceiver() public view {
        address receiver = trade.getProposalReceiver(1);

        // Check that the receiver address is correct
        assertEq(userB, receiver);
    }

    function test_getProposalAssetATokenId() public view {
        uint256 assetATokenId = trade.getProposalAssetATokenId(1);

        // Check that the asset A token ID is correct
        assertEq(ASSET_ONE_ID, assetATokenId);
    }

    function test_getProposalAssetBTokenId() public view {
        uint256 assetBTokenId = trade.getProposalAssetBTokenId(1);

        // Check that the asset B token ID is correct
        assertEq(ASSET_TWO_ID, assetBTokenId);
    }

    function test_getProposalStatus() public view {
        uint256 status = uint256(trade.getProposalStatus(1));

        // Check that the proposal status is correct
        assertEq(status, pendingStatus);
    }

    function test_getProposalCount() public view {
        uint256 proposalCount = trade.getProposalCount();

        // Check that the proposal count is correct
        assertEq(proposalCount, 1);
    }

    function test_getFactoryAddress() public view {
        address factory = trade.getAssetFactoryAddress();

        // Check that the assets contract address is correct
        assertEq(address(factory), factory);
    }

    function test_getVaultAddress() public view {
        address vault = trade.getAssetVaultAddress();

        // Check that the vault contract address is correct
        assertEq(address(vault), vault);
    }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetTradeERC1155ReceiverTest is AssetTradeTestHelper {
    function test_onERC1155Received() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        bytes4 returnedSelector = trade.onERC1155Received(address(0), address(0), 0, 0, "");

        // Check that the correct selector was returned
        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        bytes4 returnedSelector =
            trade.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");

        // Check that the correct selector was returned
        assertEq(returnedSelector, expectedSelector);
    }
}

///////////////////////////////////////////////////////////
///               IERC165 INTERFACE TESTS               ///
///////////////////////////////////////////////////////////

contract AssetTradeERC165Test is AssetTradeTestHelper {
    function test_supportsInterfaceIdIERC165() public view {
        bytes4 expectedSelector = 0x01ffc9a7;
        bool returnedSelector = trade.supportsInterface(expectedSelector);

        // Check that the contract supports the IERC165 interface
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceIdIERC1155Receiver() public view {
        bytes4 expectedSelector = 0x4e2312e0;
        bool returnedSelector = trade.supportsInterface(expectedSelector);

        // Check that the contract supports the IERC1155Receiver interface
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceBadSelector() public view {
        bytes4 badSelector = bytes4(keccak256("badSelector"));
        bool returnedSelector = trade.supportsInterface(badSelector);

        // Check that the contract throws false for an unsupported interface
        assertEq(returnedSelector, false);
    }
}
