//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
    IERC1155Errors
} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {
    IERC1155Receiver
} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {AssetVault} from "@contracts/AssetVault.sol";
import {AssetTrade} from "@contracts/AssetTrade.sol";
import {AssetTradeTestHelper} from "./helpers/AssetTradeTestHelper.sol";

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetTradeConstructorTest is AssetTradeTestHelper {
    function test_constructor() public view {
        // Check that the vault address is correct
        address expectedVaultAddress = address(vault);
        address actualVaultAddress = tradeContract.getAssetVaultAddress();
        assertEq(expectedVaultAddress, actualVaultAddress);

        // Check the proposal count is 0
        assertEq(0, tradeContract.getProposalCount());
    }
}

///////////////////////////////////////////////////////////
///              PROPOSER FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetTradeProposerCreateProposalTest is AssetTradeTestHelper {
    function test_createProposal() public {
        vm.prank(userA);

        // Check for the ProposalCreated event when creating a proposal
        vm.expectEmit(false, false, false, false, address(tradeContract));
        emit AssetTrade.ProposalCreated(1);
        tradeContract.createProposal(userB, ASSET_ONE_ID, ASSET_TWO_ID);

        // Check that the proposal count was incremented
        uint256 proposalCount = tradeContract.getProposalCount();
        assertEq(proposalCount, 1);

        // Destructure the Proposal struct to get all it's values
        // Note: The proposal ID is 1 because it is the first proposal created
        AssetTrade.Proposal memory proposal = tradeContract.getProposal(1);
        (
            address proposer,
            address receiver,
            uint256 assetAId,
            uint256 assetBId,
            uint256 proposalStatus
        ) = (
                proposal.proposer,
                proposal.receiver,
                proposal.assetAId,
                proposal.assetBId,
                uint256(proposal.status)
            );

        // Check that the proposal was created correctly
        assertEq(proposer, userA);
        assertEq(receiver, userB);
        assertEq(assetAId, ASSET_ONE_ID);
        assertEq(assetBId, ASSET_TWO_ID);
        assertEq(proposalStatus, pendingStatus);

        // Check that userA's vault balance was updated
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(
            userA,
            ASSET_ONE_ID
        );
        assertEq(
            userAEndingVaultAssetOneBalance,
            userAStartingVaultAssetOneBalance - 1
        );
    }

    function test_createProposal_RevertsIf_InsufficientBalance() public {
        vm.prank(userA);

        // Check that the call reverts with the AssetVaultInsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetVault.AssetVaultInsufficientBalance.selector,
                userA,
                0,
                1,
                ASSET_THREE_ID
            )
        );
        tradeContract.createProposal(userB, ASSET_THREE_ID, ASSET_TWO_ID);
    }
}

contract AssetTradeProposerCancelProposalTest is AssetTradeTestHelper {
    function setUp() public override {
        super.setUp();
        createProposalHelper(userA, userB, ASSET_ONE_ID, ASSET_TWO_ID);

        // Update the starting vault balance for userA
        userAStartingVaultAssetOneBalance = vault.balanceOf(
            userA,
            ASSET_ONE_ID
        );
    }

    function test_cancelProposal() public {
        vm.prank(userA);

        // Check for the ProposalCanceled event when canceling a proposal
        vm.expectEmit(false, false, false, false, address(tradeContract));
        emit AssetTrade.ProposalCanceled(1);
        tradeContract.cancelProposal(1);

        // Check that the proposal status was updated
        uint256 status = uint256(tradeContract.getProposal(1).status);
        assertEq(status, canceledStatus);

        // Check that userA's vault balance was updated
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(
            userA,
            ASSET_ONE_ID
        );
        assertEq(
            userAEndingVaultAssetOneBalance,
            userAStartingVaultAssetOneBalance + 1
        );
    }

    function test_cancelProposal_RevertsIf_NotPendingStatus() public {
        vm.startPrank(userA);
        // Note: The proposal status is now canceled after the first call
        tradeContract.cancelProposal(1);

        // Check that the call reverts when the proposal status is not pending
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetTrade.AssetTradeProposalNotPending.selector,
                canceledStatus
            )
        );
        tradeContract.cancelProposal(1);
        vm.stopPrank();
    }

    function test_cancelProposal_RevertsIf_NotProposer() public {
        vm.prank(userB);

        // Check that the call reverts with the AssetTradeNotProposer error
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetTrade.AssetTradeNotProposer.selector,
                userB,
                userA
            )
        );
        tradeContract.cancelProposal(1);
    }
}

///////////////////////////////////////////////////////////
///               RECEIVER FUNCTION TESTS               ///
///////////////////////////////////////////////////////////

contract AssetTradeReceiverFunctionsTest is AssetTradeTestHelper {
    function setUp() public override {
        super.setUp();
        createProposalHelper(userA, userB, ASSET_ONE_ID, ASSET_TWO_ID);

        // Update the starting vault balance for userA
        userAStartingVaultAssetOneBalance = vault.balanceOf(
            userA,
            ASSET_ONE_ID
        );
    }

    function test_acceptProposal() public {
        vm.prank(userB);

        // Check for the ProposalAccepted event when accepting a proposal
        vm.expectEmit(false, false, false, false, address(tradeContract));
        emit AssetTrade.ProposalAccepted(1);
        tradeContract.acceptProposal(1);

        // Check that the proposal status was updated
        uint256 status = uint256(tradeContract.getProposal(1).status);
        assertEq(status, approvedStatus);

        // Check that both userA's vault balances were updated
        // Note: userA's asset one balance should be the same because it was previously locked
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(
            userA,
            ASSET_ONE_ID
        );
        assertEq(
            userAEndingVaultAssetOneBalance,
            userAStartingVaultAssetOneBalance
        );

        uint256 userAEndingVaultAssetTwoBalance = vault.balanceOf(
            userA,
            ASSET_TWO_ID
        );
        assertEq(
            userAEndingVaultAssetTwoBalance,
            userAStartingVaultAssetTwoBalance + 1
        );

        // Check that both userB's vault balances were updated
        uint256 userBEndingVaultAssetOneBalance = vault.balanceOf(
            userB,
            ASSET_ONE_ID
        );
        assertEq(
            userBEndingVaultAssetOneBalance,
            userBStartingVaultAssetOneBalance + 1
        );

        uint256 userBEndingVaultAssetTwoBalance = vault.balanceOf(
            userB,
            ASSET_TWO_ID
        );
        assertEq(
            userBEndingVaultAssetTwoBalance,
            userBStartingVaultAssetTwoBalance - 1
        );
    }

    function test_acceptProposal_RevertsIf_NotPendingStatus() public {
        cancelProposalHelper(userA, 1);

        vm.prank(userB);

        // Check that the call reverts when the proposal status is not pending
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetTrade.AssetTradeProposalNotPending.selector,
                canceledStatus
            )
        );
        tradeContract.acceptProposal(1);
    }

    function test_acceptProposal_RevertsIf_NotReceiver() public {
        vm.prank(userC);

        // Check that the call reverts when the user is not the proposal receiver
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetTrade.AssetTradeNotReceiver.selector,
                userC,
                userB
            )
        );
        tradeContract.acceptProposal(1);
    }

    function test_rejectProposal() public {
        vm.prank(userB);

        // Check for the ProposalRejected event when rejecting a proposal
        vm.expectEmit(false, false, false, false, address(tradeContract));
        emit AssetTrade.ProposalRejected(1);
        tradeContract.rejectProposal(1);

        // Check that the proposal status was updated
        uint256 status = uint256(tradeContract.getProposal(1).status);
        assertEq(status, rejectedStatus);

        // Check that userA's asset balance was updated
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(
            userA,
            ASSET_ONE_ID
        );
        assertEq(
            userAEndingVaultAssetOneBalance,
            userAStartingVaultAssetOneBalance + 1
        );
    }

    function test_rejectProposal_RevertIf_NotPendingStatus() public {
        cancelProposalHelper(userA, 1);

        vm.prank(userB);

        // Check that the call reverts when the proposal status is not pending
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetTrade.AssetTradeProposalNotPending.selector,
                canceledStatus
            )
        );
        tradeContract.rejectProposal(1);
    }

    function test_rejectProposal_RevertsIf_NotReceiver() public {
        vm.prank(userC);

        // Check that the call reverts when the user is not the proposal receiver
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetTrade.AssetTradeNotReceiver.selector,
                userC,
                userB
            )
        );
        tradeContract.rejectProposal(1);
    }
}

///////////////////////////////////////////////////////////
///                  VIEW FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetTradeViewFunctionsTest is AssetTradeTestHelper {
    function setUp() public override {
        super.setUp();
        createProposalHelper(userA, userB, ASSET_ONE_ID, ASSET_TWO_ID);
    }

    function test_getProposal() public view {
        AssetTrade.Proposal memory proposal = tradeContract.getProposal(1);
        (
            address proposer,
            address receiver,
            uint256 assetAId,
            uint256 assetBId,
            uint256 status
        ) = (
                proposal.proposer,
                proposal.receiver,
                proposal.assetAId,
                proposal.assetBId,
                uint256(proposal.status)
            );

        // Check that the proposal was retrieved correctly
        assertEq(proposer, userA);
        assertEq(receiver, userB);
        assertEq(assetAId, ASSET_ONE_ID);
        assertEq(assetBId, ASSET_TWO_ID);
        assertEq(status, pendingStatus);
    }

    function test_getProposalCount() public view {
        // Check that the proposal count is correct
        uint256 proposalCount = tradeContract.getProposalCount();
        assertEq(proposalCount, 1);
    }

    function test_getVaultAddress() public view {
        // Check that the vault contract address is correct
        address vault = tradeContract.getAssetVaultAddress();
        assertEq(address(vault), vault);
    }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetTradeERC1155ReceiverTest is AssetTradeTestHelper {
    function test_onERC1155Received() public view {
        // Check that the correct selector was returned
        bytes4 expectedSelector = bytes4(
            keccak256(
                "onERC1155Received(address,address,uint256,uint256,bytes)"
            )
        );
        bytes4 returnedSelector = tradeContract.onERC1155Received(
            address(0),
            address(0),
            0,
            0,
            ""
        );
        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        // Check that the correct selector was returned
        bytes4 expectedSelector = bytes4(
            keccak256(
                "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
            )
        );
        bytes4 returnedSelector = tradeContract.onERC1155BatchReceived(
            address(0),
            address(0),
            new uint256[](0),
            new uint256[](0),
            ""
        );
        assertEq(returnedSelector, expectedSelector);
    }
}

///////////////////////////////////////////////////////////
///               IERC165 INTERFACE TESTS               ///
///////////////////////////////////////////////////////////

contract AssetTradeERC165Test is AssetTradeTestHelper {
    function test_supportsInterfaceIdIERC165() public view {
        // Check that the contract supports the IERC165 interface
        bytes4 expectedSelector = 0x01ffc9a7;
        bool returnedSelector = tradeContract.supportsInterface(
            expectedSelector
        );
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceIdIERC1155Receiver() public view {
        // Check that the contract supports the IERC1155Receiver interface
        bytes4 expectedSelector = 0x4e2312e0;
        bool returnedSelector = tradeContract.supportsInterface(
            expectedSelector
        );
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceBadSelector() public view {
        // Check that the contract throws false for an unsupported interface
        bytes4 badSelector = bytes4(keccak256("badSelector"));
        bool returnedSelector = tradeContract.supportsInterface(badSelector);
        assertEq(returnedSelector, false);
    }
}
