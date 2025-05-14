//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AssetVault} from "./AssetVault.sol";

/// @title AssetAuction
/// @notice This contract allows users to create and participate in auctions for ERC1155 assets.
contract AssetAuction is IERC1155Receiver, ReentrancyGuard {
    ///////////////////////////////////////////////////////////
    ///                  TYPE DECLARATIONS                  ///
    ///////////////////////////////////////////////////////////

    /// @notice The status of an auction
    enum AuctionStatus {
        Open,
        Canceled,
        Ended,
        ReserveNotMet
    }

    /// @notice The details of an auction.
    struct Auction {
        address seller;
        address highestBidder;
        address winningBidder;
        uint256 assetId;
        uint256 reservePrice;
        uint256 deadlineBlock;
        uint256 highestBid;
        uint256 winningBid;
        AuctionStatus status;
    }

    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mapping of auction ID to auction details.
    mapping(uint256 auctionId => Auction) private auctions;

    /// @notice The number of auctions.
    uint256 private auctionCount;

    /// @notice Instance of the AssetVault contract that is responsible for managing assets.
    AssetVault private immutable VAULT;

    ///////////////////////////////////////////////////////////
    ///                     EVENTS                          ///
    ///////////////////////////////////////////////////////////

    /// @notice Emitted when an auction is canceled.
    event AuctionCanceled(uint256 auctionId);

    /// @notice Emitted when an auction is created.
    event AuctionCreated(
        address seller,
        uint256 auctionId,
        uint256 assetId,
        uint256 reservePrice,
        uint256 blocksDuration
    );

    /// @notice Emitted when an auction is ended.
    event AuctionEnded(uint256 auctionId, address winningBidder, uint256 winningBid);

    /// @notice Emitted when an auction ends without meeting the reserve price.
    event AuctionReserveNotMet(uint256 auctionId, uint256 reservePrice, uint256 highestBid);

    /// @notice Emitted when a bid is placed.
    event BidPlaced(address bidder, uint256 auctionId, uint256 amount);

    ///////////////////////////////////////////////////////////
    ///                     ERRORS                          ///
    ///////////////////////////////////////////////////////////

    /// @notice Thrown when the bid is not higher than the highest bid.
    error AssetAuctionBidBelowHighestBid(uint256 amount, uint256 highestBid);

    /// @notice Thrown when the deadline has not passed.
    error AssetAuctionDeadlineNotPassed(uint256 currentBlock, uint256 deadlineBlock);

    /// @notice Thrown when the deadline has passed.
    error AssetAuctionDeadlineHasPassed(uint256 currentBlock, uint256 deadlineBlock);

    /// @notice Thrown when the caller is not the seller.
    error AssetAuctionNotTheSeller(address caller, address seller);

    /// @notice Thrown when the auction is not open.
    error AssetAuctionNotOpen(AuctionStatus status);

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @param _assetVaultAddress The address of the AssetVault contract.
    constructor(address _assetVaultAddress) {
        VAULT = AssetVault(_assetVaultAddress);
    }

    ///////////////////////////////////////////////////////////
    ///                  SELLER FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Create a new auction.
    /// @param assetId The ID of the asset.
    /// @param reservePrice The reserve price of the auction.
    /// @param blocksDuration The amount of blocks until the auction ends.
    /// @dev Will throw an error if the user lacks the required balance of the asset to auction. (AssetVaultInsufficientBalance).
    //!! Create designated block start time?
    function createAuction(uint256 assetId, uint256 reservePrice, uint256 blocksDuration) public {
        uint256 startBlock = block.number;
        uint256 endBlock = startBlock + blocksDuration;

        auctionCount++;
        auctions[auctionCount] = Auction({
            seller: msg.sender,
            assetId: assetId,
            reservePrice: reservePrice,
            deadlineBlock: endBlock,
            highestBid: 0,
            highestBidder: address(0),
            winningBid: 0,
            winningBidder: address(0),
            status: AuctionStatus.Open
        });

        VAULT.lockAsset(msg.sender, assetId, 1);

        emit AuctionCreated(msg.sender, auctionCount, assetId, reservePrice, blocksDuration);
    }

    /// @notice Cancel an auction.
    /// @param auctionId The ID of the auction to cancel.
    function cancelAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        if (auction.status != AuctionStatus.Open) {
            revert AssetAuctionNotOpen(auction.status);
        }

        if (block.number >= auction.deadlineBlock) {
            revert AssetAuctionDeadlineHasPassed(block.number, auction.deadlineBlock);
        }

        if (auction.seller != msg.sender) {
            revert AssetAuctionNotTheSeller(msg.sender, auction.seller);
        }

        auction.status = AuctionStatus.Canceled;

        VAULT.unlockAsset(auction.seller, auction.assetId, 1);

        emit AuctionCanceled(auctionId);
    }

    ///////////////////////////////////////////////////////////
    ///                  BIDDER FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Bid on an auction.
    /// @param auctionId The ID of the auction.
    /// @param amount The amount to bid.
    /// @dev Will throw an error if the user lacks the required balance to place the bid. (AssetVaultInsufficientBalance).
    function placeBid(uint256 auctionId, uint256 amount) external nonReentrant {
        Auction storage auction = auctions[auctionId];

        if (auction.status != AuctionStatus.Open) {
            revert AssetAuctionNotOpen(auction.status);
        }

        if (block.number >= auction.deadlineBlock) {
            revert AssetAuctionDeadlineHasPassed(block.number, auction.deadlineBlock);
        }

        if (amount <= auction.highestBid) {
            revert AssetAuctionBidBelowHighestBid(amount, auction.highestBid);
        }

        // Lock the IGC tokens of the bidder and unlock the IGC tokens of the previous highest bidder
        VAULT.lockAsset(msg.sender, VAULT.getIGCTokenId(), amount);
        VAULT.unlockAsset(auction.highestBidder, VAULT.getIGCTokenId(), auction.highestBid);

        auction.highestBid = amount;
        auction.highestBidder = msg.sender;

        emit BidPlaced(msg.sender, auctionId, amount);
    }

    ///////////////////////////////////////////////////////////
    ///                 ANY CALLER FUNCTIONS                ///
    ///////////////////////////////////////////////////////////

    /// @notice Complete an auction.
    /// @param auctionId The ID of the auction to complete.
    function completeAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        if (auction.status != AuctionStatus.Open) {
            revert AssetAuctionNotOpen(auction.status);
        }

        if (block.number < auction.deadlineBlock) {
            revert AssetAuctionDeadlineNotPassed(block.number, auction.deadlineBlock);
        }

        if (auction.highestBid < auction.reservePrice) {
            auction.status = AuctionStatus.ReserveNotMet;

            VAULT.unlockAsset(auction.seller, auction.assetId, 1);

            emit AuctionReserveNotMet(auctionId, auction.reservePrice, auction.highestBid);

            return;
        }

        auction.status = AuctionStatus.Ended;
        auction.winningBid = auction.highestBid;
        auction.winningBidder = auction.highestBidder;

        // Execute the exchange of assets by updating the balances in the AssetVault contract
        VAULT.unlockAsset(auction.seller, VAULT.getIGCTokenId(), auction.winningBid);
        VAULT.unlockAsset(auction.winningBidder, auction.assetId, 1);

        emit AuctionEnded(auctionId, auction.winningBidder, auction.winningBid);
    }

    ///////////////////////////////////////////////////////////
    ///                  VIEW FUNCTIONS                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Get the details of an auction.
    /// @param auctionId The ID of the auction.
    /// @return auction The details of the auction.
    function getAuction(uint256 auctionId) public view returns (Auction memory auction) {
        return auctions[auctionId];
    }

    /// @notice Get the auction count.
    /// @return count The auction count.
    function getAuctionCount() public view returns (uint256 count) {
        return auctionCount;
    }

    /// @notice Get the vault contract address.
    /// @return vaultAddress The address of the vault contract.
    function getAssetVaultAddress() public view returns (address vaultAddress) {
        return address(VAULT);
    }

    /////////////////////////////////////////////////////////////
    ///               ERC1155 RECEIVER FUNCTIONS              ///
    /////////////////////////////////////////////////////////////

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*id*/,
        uint256 /*value*/,
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155BatchReceived(
        address /*operator*/,
        address /*from*/,
        uint256[] memory /*ids*/,
        uint256[] memory /*values*/,
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return
            bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    /////////////////////////////////////////////////////////////
    ///               IERC165 INTERFACE FUNCTIONS             ///
    /////////////////////////////////////////////////////////////

    // Implement supportsInterface
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}
