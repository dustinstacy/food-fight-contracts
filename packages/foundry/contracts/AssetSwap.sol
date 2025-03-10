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

    ///////////////////////////////////////////////////////////
    ///                     ENUMS                           ///
    ///////////////////////////////////////////////////////////

    enum ProposalStatus {
        Pending,
        Approved,
        Rejected,
        Executed
    }

    ///////////////////////////////////////////////////////////
    ///                     STRUCTS                         ///
    ///////////////////////////////////////////////////////////

    struct Proposal {
        address owner1;
        address owner2;
        uint256 nft1TokenId;
        uint256 nft2TokenId;
        ProposalStatus status;
    }

    ///////////////////////////////////////////////////////////
    ///                 STORAGE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    mapping(uint256 proposalId => Proposal) public proposals;

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
    /// @param nft1TokenId The token ID of the first NFT
    /// @param nft2TokenId The token ID of the second NFT
    /// @param timeToExecute The time in seconds for how long owner2 has to execute the swap after approval
    function createProposal(address owner2, uint256 nft1TokenId, uint256 nft2TokenId, uint256 timeToExecute) external {
        // Make sure the caller has a balance of NFT1
        if (assetsContract.balanceOf(msg.sender, nft1TokenId) == 0) {
            revert AssetSwapAssetNotOwned(nft1TokenId);
        }

        // Deposit NFT1 into the contract
        assetsContract.safeTransferFrom(msg.sender, address(this), nft1TokenId, 1, "");

        proposalCount++;

        // Create the proposal and store it in the proposals mapping
        proposals[proposalCount] = Proposal({
            owner1: msg.sender,
            owner2: owner2,
            nft1TokenId: nft1TokenId,
            nft2TokenId: nft2TokenId,
            status: ProposalStatus.Pending
        });
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
        assetsContract.safeTransferFrom(msg.sender, address(this), proposal.nft2TokenId, 1, "");

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
}
