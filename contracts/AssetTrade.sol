//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { AssetVault } from "./AssetVault.sol";

/// @title AssetTrade
/// @notice This contract allows users to trade ERC1155 assets with each other.
contract AssetTrade is IERC1155Receiver {
    ///////////////////////////////////////////////////////////
    ///                   TYPE DECLARATIONS                 ///
    ///////////////////////////////////////////////////////////

    /// @notice The status of a proposal.
    enum ProposalStatus {
        Pending,
        Accepted,
        Rejected,
        Canceled
    }

    /// @notice The details of a proposal.
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

    /// @notice The number of proposals.
    uint256 private proposalCount;

    /// @notice Instance of the AssetVault contract that is responsible for managing assets.
    AssetVault private immutable i_vault;

    ///////////////////////////////////////////////////////////
    ///                      EVENTS                         ///
    ///////////////////////////////////////////////////////////

    /// @notice Emitted when a proposal is approved.
    event ProposalAccepted(uint256 proposalId);

    /// @notice Emitted when a proposal is canceled.
    event ProposalCanceled(uint256 proposalId);

    /// @notice Emitted when a proposal is created.
    event ProposalCreated(uint256 proposalId);

    /// @notice Emitted when a proposal is rejected.
    event ProposalRejected(uint256 proposalId);

    ///////////////////////////////////////////////////////////
    ///                      ERRORS                         ///
    ///////////////////////////////////////////////////////////

    /// @notice Thrown when the caller, who is not the proposer, tries to cancel the proposal.
    error AssetTradeNotProposer(address caller, address proposer);

    /// @notice Thrown when the caller, who is not the receiver, tries to address the proposal.
    error AssetTradeNotReceiver(address caller, address receiver);

    /// @notice Thrown when the proposal is not in a pending state.
    error AssetTradeProposalNotPending(ProposalStatus status);

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @param _assetVaultAddress The address of the AssetVault contract.
    constructor(address _assetVaultAddress) {
        i_vault = AssetVault(_assetVaultAddress);
    }

    ///////////////////////////////////////////////////////////
    ///                  PROPOSER FUNCTIONS                 ///
    ///////////////////////////////////////////////////////////

    /// @notice Create a proposal to trade assets.
    /// @param receiver The address of the user to trade with.
    /// @param assetAId The token ID of the asset being traded.
    /// @param assetBId The token ID of the asset being traded for.
    /// @dev Will throw an error when the user lacks the required balance of the asset to trade. (AssetVaultInsufficientBalance).
    function createProposal(address receiver, uint256 assetAId, uint256 assetBId) external {
        proposalCount++;
        proposals[proposalCount] = Proposal({
            proposer: msg.sender,
            receiver: receiver,
            assetAId: assetAId,
            assetBId: assetBId,
            status: ProposalStatus.Pending
        });

        i_vault.lockAsset(msg.sender, assetAId, 1);

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

        i_vault.unlockAsset(proposal.proposer, proposal.assetAId, 1);

        emit ProposalCanceled(proposalId);
    }

    ///////////////////////////////////////////////////////////
    ///                    RECEIVER FUNCTIONS               ///
    ///////////////////////////////////////////////////////////

    /// @notice Accept a proposal to trade assets.
    /// @param proposalId The ID of the proposal to approve.
    /// @dev Will throw an error when the user lacks the required balance of the asset to trade. (AssetVaultInsufficientBalance).
    function acceptProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.status != ProposalStatus.Pending) {
            revert AssetTradeProposalNotPending(proposal.status);
        }

        if (proposal.receiver != msg.sender) {
            revert AssetTradeNotReceiver(msg.sender, proposal.receiver);
        }

        proposal.status = ProposalStatus.Accepted;

        // Execute the exchange of assets by updating the balances in the AssetVault contract
        i_vault.lockAsset(proposal.receiver, proposal.assetBId, 1);
        i_vault.unlockAsset(proposal.proposer, proposal.assetBId, 1);
        i_vault.unlockAsset(proposal.receiver, proposal.assetAId, 1);

        emit ProposalAccepted(proposalId);
    }

    /// @notice Reject a proposal to trade two assets.
    /// @param proposalId The ID of the proposal to reject.
    function rejectProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.status != ProposalStatus.Pending) {
            revert AssetTradeProposalNotPending(proposal.status);
        }
        if (proposal.receiver != msg.sender) {
            revert AssetTradeNotReceiver(msg.sender, proposal.receiver);
        }

        proposal.status = ProposalStatus.Rejected;

        i_vault.unlockAsset(proposal.proposer, proposal.assetAId, 1);

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

    /// @notice Get the number of proposals.
    /// @return proposalCount The number of proposals.
    function getProposalCount() public view returns (uint256) {
        return proposalCount;
    }

    /// @notice Get the vault contract address.
    /// @return vaultAddress The address of the vault contract.
    function getAssetVaultAddress() public view returns (address vaultAddress) {
        return address(i_vault);
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
