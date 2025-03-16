//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Remove when deploying to a live network.
import "forge-std/console.sol";

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { AssetVault } from "./AssetVault.sol";

/// @title AssetTrade
/// @notice This contract allows users to trade ERC1155 assets with each other.
contract AssetTrade is IERC1155Receiver {
    ///////////////////////////////////////////////////////////
    ///                      ERRORS                         ///
    ///////////////////////////////////////////////////////////

    /// @notice Thrown when the caller lacks the required balance to perform an action.
    error AssetTradeInsufficientBalance(address caller, uint256 tokenId);

    /// @notice Thrown when the proposal is not in a pending state.
    error AssetTradeProposalNotPending(ProposalStatus status);

    /// @notice Thrown when the caller, who is not the proposer, tries to cancel the proposal.
    error AssetTradeNotProposer(address caller, address proposer);

    /// @notice Thrown when the caller, who is not the receiver, tries to address the proposal.
    error AssetTradeNotUser2(address caller, address receiver);

    ///////////////////////////////////////////////////////////
    ///                    EVENTS                           ///
    ///////////////////////////////////////////////////////////

    /// @notice Emitted when a proposal is created.
    event ProposalCreated(uint256 proposalId);

    /// @notice Emitted when a proposal is approved.
    event ProposalApproved(uint256 proposalId);

    /// @notice Emitted when a proposal is rejected.
    event ProposalRejected(uint256 proposalId);

    /// @notice Emitted when a proposal is canceled.
    event ProposalCanceled(uint256 proposalId);

    ///////////////////////////////////////////////////////////
    ///                     ENUMS                           ///
    ///////////////////////////////////////////////////////////

    /// @notice The status of a proposal.
    enum ProposalStatus {
        Pending,
        Approved,
        Rejected,
        Canceled
    }

    ///////////////////////////////////////////////////////////
    ///                     STRUCTS                         ///
    ///////////////////////////////////////////////////////////

    /// @notice The proposal object.
    struct Proposal {
        address proposer;
        address receiver;
        uint256 assetAId;
        uint256 assetBId;
        ProposalStatus status;
    }

    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mapping of the proposal ID to the proposal object.
    mapping(uint256 proposalId => Proposal) private proposals;

    /// @notice Instance of the ERC1155 contract that is responsible for minting assets.
    IERC1155 private factory;

    /// @notice Instance of the AssetVault contract that is responsible for managing assets.
    AssetVault private vault;

    /// @notice The number of proposals.
    uint256 private proposalCount;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @param _factoryAddress The address of the ERC1155 contract.
    constructor(address _factoryAddress, address _assetVaultAddress) {
        factory = IERC1155(_factoryAddress);
        vault = AssetVault(_assetVaultAddress);
    }

    ///////////////////////////////////////////////////////////
    ///                    CORE FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Create a proposal to trade assets.
    /// @param receiver The address of the user to trade with.
    /// @param assetAId The token ID of the asset being traded.
    /// @param assetBId The token ID of the asset being traded for.
    //!! Update to allow users to trade larger amounts of assets.
    function createProposal(address receiver, uint256 assetAId, uint256 assetBId) external {
        if (vault.balanceOf(msg.sender, assetAId) == 0) {
            revert AssetTradeInsufficientBalance(msg.sender, assetAId);
        }

        proposalCount++;
        proposals[proposalCount] = Proposal({
            proposer: msg.sender,
            receiver: receiver,
            assetAId: assetAId,
            assetBId: assetBId,
            status: ProposalStatus.Pending
        });

        vault.lockAsset(msg.sender, assetAId);

        emit ProposalCreated(proposalCount);
    }

    /// @notice Cancel a proposal to trade assets.
    /// @param proposalId The ID of the proposal to cancel.
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.status != ProposalStatus.Pending) {
            revert AssetTradeProposalNotPending(proposal.status);
        }

        if (proposal.proposer != msg.sender) {
            revert AssetTradeNotProposer(msg.sender, proposal.proposer);
        }

        proposal.status = ProposalStatus.Canceled;

        vault.unlockAsset(proposal.proposer, proposal.assetAId);

        emit ProposalCanceled(proposalId);
    }

    /// @notice Approve a proposal to trade assets.
    /// @param proposalId The ID of the proposal to approve.
    function approveProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.status != ProposalStatus.Pending) {
            revert AssetTradeProposalNotPending(proposal.status);
        }

        if (proposal.receiver != msg.sender) {
            revert AssetTradeNotUser2(msg.sender, proposal.receiver);
        }

        if (vault.balanceOf(proposal.receiver, proposal.assetBId) == 0) {
            revert AssetTradeInsufficientBalance(proposal.receiver, proposal.assetBId);
        }

        proposal.status = ProposalStatus.Approved;

        // Executes swap by updating the balances in the AssetVault contract
        vault.lockAsset(proposal.receiver, proposal.assetBId);
        vault.unlockAsset(proposal.proposer, proposal.assetBId);
        vault.unlockAsset(proposal.receiver, proposal.assetAId);

        emit ProposalApproved(proposalId);
    }

    /// @notice Reject a proposal to trade two assets.
    /// @param proposalId The ID of the proposal to reject.
    function rejectProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.status != ProposalStatus.Pending) {
            revert AssetTradeProposalNotPending(proposal.status);
        }
        if (proposal.receiver != msg.sender) {
            revert AssetTradeNotUser2(msg.sender, proposal.receiver);
        }

        proposal.status = ProposalStatus.Rejected;

        vault.unlockAsset(proposal.proposer, proposal.assetAId);

        emit ProposalRejected(proposalId);
    }

    ///////////////////////////////////////////////////////////
    ///                    VIEW FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Get an existing proposal.
    /// @param proposalId The ID of the proposal.
    /// @return proposal The proposal object.
    function getProposal(uint256 proposalId) public view returns (Proposal memory proposal) {
        return proposals[proposalId];
    }

    /// @notice Get the proposer of a proposal.
    /// @param proposalId The ID of the proposal.
    /// @return proposer The address of the proposer.
    function getProposalProposer(uint256 proposalId) public view returns (address proposer) {
        return proposals[proposalId].proposer;
    }

    /// @notice Get the receiver of a proposal.
    /// @param proposalId The ID of the proposal.
    /// @return receiver The address of the receiver.
    function getProposalUser2(uint256 proposalId) public view returns (address receiver) {
        return proposals[proposalId].receiver;
    }

    /// @notice Get the asset1 token ID of a proposal.
    /// @param proposalId The ID of the proposal.
    /// @return assetAId The token ID of the asset1.
    function getProposalAsset1TokenId(uint256 proposalId) public view returns (uint256 assetAId) {
        return proposals[proposalId].assetAId;
    }

    /// @notice Get the asset2 token ID of a proposal.
    /// @param proposalId The ID of the proposal.
    /// @return assetBId The token ID of the asset2.
    function getProposalAsset2TokenId(uint256 proposalId) public view returns (uint256 assetBId) {
        return proposals[proposalId].assetBId;
    }

    /// @notice Get the status of a proposal.
    /// @param proposalId The ID of the proposal.
    /// @return status The status of the proposal.
    function getProposalStatus(uint256 proposalId) public view returns (ProposalStatus status) {
        return proposals[proposalId].status;
    }

    /// @notice Get the number of proposals.
    /// @return proposalCount The number of proposals.
    function getProposalCount() public view returns (uint256) {
        return proposalCount;
    }

    /// @notice Get the address of the ERC1155 contract.
    /// @return factory The address of the ERC1155 contract.
    function getFactoryAddress() public view returns (address) {
        return address(factory);
    }

    /////////////////////////////////////////////////////////////
    ///               ERC1155 RECEIVER FUNCTIONS              ///
    /////////////////////////////////////////////////////////////

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(
        address, /*operator*/
        address, /*from*/
        uint256, /*id*/
        uint256, /*value*/
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155BatchReceived(
        address, /*operator*/
        address, /*from*/
        uint256[] memory, /*ids*/
        uint256[] memory, /*values*/
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    /////////////////////////////////////////////////////////////
    ///               IERC165 INTERFACE FUNCTIONS             ///
    /////////////////////////////////////////////////////////////

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
