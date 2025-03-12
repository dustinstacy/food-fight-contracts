//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @title AssetSwap
/// @notice This contract allows users to swap ERC1155 assets with each other.
contract AssetSwap {
    ///////////////////////////////////////////////////////////
    ///                      ERRORS                         ///
    ///////////////////////////////////////////////////////////

    /// Emitted when the caller tries to approve a proposal that is not pending.
    error AssetSwapProposalNotPending(ProposalStatus status);

    /// Emitted when the caller tries to cancel a proposal that is not the owner1.
    error AssetSwapNotOwner1(address caller, address owner1);

    /// Emitted when the caller tries to approve a proposal that is not the owner2.
    error AssetSwapNotOwner2(address caller, address owner2);

    /// Emitted when the token IDs and amounts arrays have different lengths.
    error AssetSwapArraysLengthMismatch(uint256 tokenIdsLength, uint256 amountsLength);

    /// Emitted when the caller tries to withdraw more assets than they own.
    error AssetSwapInsufficientBalance(address caller, uint256 balance, uint256 amount, uint256 tokenId);

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
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    mapping(uint256 proposalId => Proposal) private proposals;
    mapping(address owner => mapping(uint256 tokenId => uint256 balance)) private balances;

    uint256 private proposalCount;
    IERC1155 private assetsContract;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @param _assetsContractAddress The address of the ERC1155 contract
    constructor(address _assetsContractAddress) {
        assetsContract = IERC1155(_assetsContractAddress);
    }

    ///////////////////////////////////////////////////////////
    ///                    CORE FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Create a proposal to swap two assets
    /// @param owner2 The address of the owner to swap with
    /// @param asset1TokenId The token ID of the first asset
    /// @param asset2TokenId The token ID of the second asset
    function createProposal(address owner2, uint256 asset1TokenId, uint256 asset2TokenId) external {
        // Check if the caller has any of the asset1TokenId deposited
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

        // Update the balances
        balances[msg.sender][asset1TokenId] -= 1;

        emit ProposalCreated(proposalCount);
    }

    // @notice Cancel a proposal to swap two assets
    /// @param proposalId The ID of the proposal to cancel
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        // Check if the proposal is pending
        if (proposal.status != ProposalStatus.Pending) {
            revert AssetSwapProposalNotPending(proposal.status);
        }

        // Check if the caller is the owner1
        if (proposal.owner1 != msg.sender) {
            revert AssetSwapNotOwner1(msg.sender, proposal.owner1);
        }

        // Update the proposal status
        proposal.status = ProposalStatus.Canceled;

        // Update the user balances
        balances[proposal.owner1][proposal.asset1TokenId] += 1;

        emit ProposalCanceled(proposalId);
    }

    // @notice Approve a proposal to swap two assets
    /// @param proposalId The ID of the proposal to approve
    function approveProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        // Check if the proposal is pending
        if (proposal.status != ProposalStatus.Pending) {
            revert AssetSwapProposalNotPending(proposal.status);
        }

        // Check if the caller is the owner2
        if (proposal.owner2 != msg.sender) {
            revert AssetSwapNotOwner2(msg.sender, proposal.owner2);
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

    // @notice Reject a proposal to swap two assets
    /// @param proposalId The ID of the proposal to reject
    function rejectProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        // Check if the proposal is pending
        if (proposal.status != ProposalStatus.Pending) {
            revert AssetSwapProposalNotPending(proposal.status);
        }

        // Check if the caller is the owner2
        if (proposal.owner2 != msg.sender) {
            revert AssetSwapNotOwner2(msg.sender, proposal.owner2);
        }

        // Update the proposal status
        proposal.status = ProposalStatus.Rejected;

        // Update the user balances
        balances[proposal.owner1][proposal.asset1TokenId] += 1;

        emit ProposalRejected(proposalId);
    }

    ///////////////////////////////////////////////////////////
    ///                  ASSETS FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Withdraw assets from the contract
    /// @param tokenIds The token IDs of the assets to withdraw
    /// @param amounts The amounts of the assets to withdraw
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

        // Check for sufficient balance
        for (uint256 i = 0; i < length; i++) {
            if (balances[to][tokenIds[i]] < amounts[i]) {
                revert AssetSwapInsufficientBalance(to, balances[to][tokenIds[i]], amounts[i], tokenIds[i]);
            }
        }

        // Update the user balances
        for (uint256 i = 0; i < length; i++) {
            balances[to][tokenIds[i]] -= amounts[i];
        }

        // Transfer the assets to the caller
        assetsContract.safeBatchTransferFrom(from, to, tokenIds, amounts, data);

        emit AssetsWithdrawn(to, tokenIds, amounts);
    }

    /// @notice Deposit assets into the contract
    /// @param tokenIds The token IDs of the assets to deposit
    /// @param amounts The amounts of the assets to deposit
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

    ///////////////////////////////////////////////////////////
    ///                    VIEW FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Get an existing proposal
    /// @param proposalId The ID of the proposal
    /// @return proposal The proposal object
    function getProposal(uint256 proposalId) public view returns (Proposal memory proposal) {
        return proposals[proposalId];
    }

    /// @notice Get the owner1 of a proposal
    /// @param proposalId The ID of the proposal
    /// @return owner1 The address of the owner1
    function getProposalOwner1(uint256 proposalId) public view returns (address owner1) {
        return proposals[proposalId].owner1;
    }

    /// @notice Get the owner2 of a proposal
    /// @param proposalId The ID of the proposal
    /// @return owner2 The address of the owner2
    function getProposalOwner2(uint256 proposalId) public view returns (address owner2) {
        return proposals[proposalId].owner2;
    }

    /// @notice Get the asset1 token ID of a proposal
    /// @param proposalId The ID of the proposal
    /// @return asset1TokenId The token ID of the asset1
    function getProposalAsset1TokenId(uint256 proposalId) public view returns (uint256 asset1TokenId) {
        return proposals[proposalId].asset1TokenId;
    }

    /// @notice Get the asset2 token ID of a proposal
    /// @param proposalId The ID of the proposal
    /// @return asset2TokenId The token ID of the asset2
    function getProposalAsset2TokenId(uint256 proposalId) public view returns (uint256 asset2TokenId) {
        return proposals[proposalId].asset2TokenId;
    }

    /// @notice Get the status of a proposal
    /// @param proposalId The ID of the proposal
    /// @return status The status of the proposal
    function getProposalStatus(uint256 proposalId) public view returns (ProposalStatus status) {
        return proposals[proposalId].status;
    }

    /// @notice Get the balance of a user for a specific token
    /// @param owner The address of the user
    /// @param tokenId The ID of the token
    /// @return balance The balance of the user for the token
    function getBalance(address owner, uint256 tokenId) public view returns (uint256 balance) {
        return balances[owner][tokenId];
    }

    /// @notice Get the number of proposals
    /// @return proposalCount The number of proposals
    function getProposalCount() public view returns (uint256) {
        return proposalCount;
    }

    /// @notice Get the address of the ERC1155 contract
    /// @return assetsContract The address of the ERC1155 contract
    function getAssetsContract() public view returns (address) {
        return address(assetsContract);
    }
}
