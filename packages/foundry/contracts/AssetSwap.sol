//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract AssetSwap {
    ///////////////////////////////////////////////////////////
    ///                      ERRORS                         ///
    ///////////////////////////////////////////////////////////

    /// Emitted when the caller tries to approve a proposal that is not pending.
    error AssetSwapProposalNotPending(ProposalStatus status);

    /// Emitted when the caller tries to approve a proposal that is not the owner2.
    error AssetSwapNotOwner2(address owner2, address caller);

    /// Emitted when the caller tries to withdraw more assets than they own.
    error AssetSwapInsufficientBalance(address owner, uint256 balance, uint256 amount, uint256 tokenId);

    /// Emitted when the token IDs and amounts arrays have different lengths.
    error AssetSwapArraysLengthMismatch(uint256 tokenIdsLength, uint256 amountsLength);

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

    // Emitted when assets are deposited into the contract
    event AssetsDeposited(address owner, uint256[] tokenIds, uint256[] amounts);

    // Emitted when assets are withdrawn from the contract
    event AssetsWithdrawn(address owner, uint256[] tokenIds, uint256[] amounts);

    ///////////////////////////////////////////////////////////
    ///                     ENUMS                           ///
    ///////////////////////////////////////////////////////////

    enum ProposalStatus {
        Pending,
        Approved,
        Rejected,
        Canceled
    }

    ///////////////////////////////////////////////////////////
    ///                     STRUCTS                         ///
    ///////////////////////////////////////////////////////////

    struct Proposal {
        address owner1;
        address owner2;
        uint256 asset1TokenId;
        uint256 asset2TokenId;
        ProposalStatus status;
    }

    ///////////////////////////////////////////////////////////
    ///                 STORAGE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    mapping(uint256 proposalId => Proposal) public proposals;
    mapping(address owner => mapping(uint256 tokenId => uint256 balance)) public balances;

    uint256 private proposalCount;

    IERC1155 private assetsContract;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @param _assetsContractAddress The address of the ERC1155 contract
    constructor(address _assetsContractAddress) {
        assetsContract = IERC1155(_assetsContractAddress);
    }

    /// @notice Create a proposal to swap two assets
    /// @param owner2 The address of the owner to swap with
    /// @param asset1TokenId The token ID of the first asset
    /// @param asset2TokenId The token ID of the second asset
    function createProposal(address owner2, uint256 asset1TokenId, uint256 asset2TokenId) external {
        // Check if the caller has any of the asset1 deposited
        if (balances[msg.sender][asset1TokenId] == 0) {
            // Create empty arrays for the depositAssets function
            uint256[] memory tokenIds = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);

            // Store the asset1 token ID and amount
            tokenIds[0] = asset1TokenId;
            amounts[0] = 1;

            // Deposit asset1 into the contract
            depositAssets(tokenIds, amounts);
        }

        // Increment the proposal count
        proposalCount++;

        // Create the proposal and store it in the proposals mapping
        proposals[proposalCount] = Proposal({
            owner1: msg.sender,
            owner2: owner2,
            asset1TokenId: asset1TokenId,
            asset2TokenId: asset2TokenId,
            status: ProposalStatus.Pending
        });

        // Update the user balances
        balances[msg.sender][asset1TokenId] -= 1;

        emit ProposalCreated(proposalCount);
    }

    function approveProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        // Check if the proposal is pending
        if (proposal.status != ProposalStatus.Pending) {
            revert AssetSwapProposalNotPending(proposal.status);
        }

        // Check if the caller is the owner2
        if (proposal.owner2 != msg.sender) {
            revert AssetSwapNotOwner2(proposal.owner2, msg.sender);
        }

        // Create empty arrays for the depositAssets function
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        // Store the asset2 token ID and amount
        tokenIds[0] = proposal.asset2TokenId;
        amounts[0] = 1;

        // Deposit asset2 into the contract
        depositAssets(tokenIds, amounts);

        // Update the user balances
        balances[proposal.owner2][proposal.asset2TokenId] -= 1;
        balances[proposal.owner1][proposal.asset2TokenId] += 1;
        balances[proposal.owner2][proposal.asset1TokenId] += 1;

        // Update the proposal status
        proposal.status = ProposalStatus.Approved;

        emit ProposalApproved(proposalId);
    }

    function rejectProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        // Check if the proposal is pending
        if (proposal.status != ProposalStatus.Pending) {
            revert AssetSwapProposalNotPending(proposal.status);
        }

        // Check if the caller is the owner2
        if (proposal.owner2 != msg.sender) {
            revert AssetSwapNotOwner2(proposal.owner2, msg.sender);
        }

        // Update the proposal status
        proposal.status = ProposalStatus.Rejected;

        // Update the user balances
        balances[proposal.owner1][proposal.asset1TokenId] += 1;

        emit ProposalRejected(proposalId);
    }

    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        // Check if the proposal is pending
        if (proposal.status != ProposalStatus.Pending) {
            revert AssetSwapProposalNotPending(proposal.status);
        }

        // Check if the caller is the owner1
        if (proposal.owner1 != msg.sender) {
            revert AssetSwapNotOwner2(proposal.owner1, msg.sender);
        }

        // Update the proposal status
        proposal.status = ProposalStatus.Canceled;

        // Update the user balances
        balances[proposal.owner1][proposal.asset1TokenId] += 1;

        emit ProposalCanceled(proposalId);
    }

    function withdrawAssets(uint256[] memory tokenIds, uint256[] memory amounts) external {
        // Check if the token IDs and amounts arrays have the same length
        if (tokenIds.length != amounts.length) {
            revert AssetSwapArraysLengthMismatch(tokenIds.length, amounts.length);
        }

        // Store the necessary variables for the safeBatchTransferFrom function
        uint256 length = tokenIds.length;
        address from = address(this);
        address to = msg.sender;
        bytes memory data = "";

        // Transfer the assets to the caller
        assetsContract.safeBatchTransferFrom(from, to, tokenIds, amounts, data);

        // Update the user balances
        for (uint256 i = 0; i < length; i++) {
            balances[to][tokenIds[i]] -= amounts[i];
        }

        emit AssetsWithdrawn(to, tokenIds, amounts);
    }

    function depositAssets(uint256[] memory tokenIds, uint256[] memory amounts) public {
        // Check if the token IDs and amounts arrays have the same length
        if (tokenIds.length != amounts.length) {
            revert AssetSwapArraysLengthMismatch(tokenIds.length, amounts.length);
        }

        // Store the necessary variables for the safeBatchTransferFrom function
        uint256 length = tokenIds.length;
        address from = msg.sender;
        address to = address(this);
        bytes memory data = "";

        // Transfer the assets to the contract
        assetsContract.safeBatchTransferFrom(from, to, tokenIds, amounts, data);

        // Update the user balances
        for (uint256 i = 0; i < length; i++) {
            balances[from][tokenIds[i]] += amounts[i];
        }

        emit AssetsDeposited(from, tokenIds, amounts);
    }
}
