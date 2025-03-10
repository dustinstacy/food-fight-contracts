//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract AssetSwap {
    ///////////////////////////////////////////////////////////
    ///                      ERRORS                         ///
    ///////////////////////////////////////////////////////////

    /// Emitted when the caller tries to create a proposal for an asset they do not own.
    error AssetSwapAssetNotOwned(uint256 requiredAssetId);

    /// Emitted when the caller tries to approve a proposal that is not pending.
    error AssetSwapProposalNotPending(ProposalStatus status);

    /// Emitted when the caller tries to approve a proposal that is not the owner2.
    error AssetSwapNotOwner2(address owner2, address caller);

    /// Emitted when the caller tries to withdraw more assets than they own.
    error AssetSwapInsufficientBalance(address owner, uint256 balance, uint256 amount, uint256 tokenId);

    ///////////////////////////////////////////////////////////
    ///                     ENUMS                           ///
    ///////////////////////////////////////////////////////////

    enum ProposalStatus {
        Pending,
        Approved,
        Rejected,
        Executed,
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
    /// @param asset1TokenId The token ID of the first NFT
    /// @param asset2TokenId The token ID of the second NFT
    function createProposal(address owner2, uint256 asset1TokenId, uint256 asset2TokenId) external {
        // Make sure the caller has a balance of NFT1
        if (assetsContract.balanceOf(msg.sender, asset1TokenId) == 0) {
            revert AssetSwapAssetNotOwned(asset1TokenId);
        }

        // Deposit NFT1 into the contract
        assetsContract.safeTransferFrom(msg.sender, address(this), asset1TokenId, 1, "");

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
        balances[msg.sender][asset1TokenId] += 1;
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

        // Deposit NFT2 into the contract
        assetsContract.safeTransferFrom(msg.sender, address(this), proposal.asset2TokenId, 1, "");

        // Update the user balances
        balances[proposal.owner1][proposal.asset1TokenId] -= 1;
        balances[proposal.owner1][proposal.asset2TokenId] += 1;
        balances[proposal.owner2][proposal.asset1TokenId] += 1;

        // Update the proposal status
        proposal.status = ProposalStatus.Approved;
    }

    function rejectProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        // Check if the proposal is pending
        if (proposal.status != ProposalStatus.Pending) {
            revert AssetSwapProposalNotPending(proposal.status);
        }

        // Check if the caller is the owner1
        if (proposal.owner2 != msg.sender) {
            revert AssetSwapNotOwner2(proposal.owner2, msg.sender);
        }

        // Update the proposal status
        proposal.status = ProposalStatus.Rejected;
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
    }

    function withdrawAsset(uint256 tokenId, uint256 amount) external {
        // Check if the caller has enough of the asset
        if (balances[msg.sender][tokenId] < amount) {
            revert AssetSwapInsufficientBalance(msg.sender, balances[msg.sender][tokenId], amount, tokenId);
        }

        // Update the user balances
        balances[msg.sender][tokenId] -= amount;

        // Transfer the asset to the caller
        assetsContract.safeTransferFrom(address(this), msg.sender, tokenId, amount, "");
    }
}
