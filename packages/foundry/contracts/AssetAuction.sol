//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { AssetVault } from "./AssetVault.sol";

/// @title AssetAuction
/// @notice This contract allows users to create and participate in auctions for ERC1155 assets.
contract AssetAuction is IERC1155Receiver {
    ///////////////////////////////////////////////////////////
    ///                     ERRORS                          ///
    ///////////////////////////////////////////////////////////

    /// @notice Thrown when the auction is not open.
    error AssetAuctionNotOpen(AuctionStatus status);

    /// @notice Thrown when the deadline has passed.
    error AssetAuctionDeadlineHasPassed(uint256 deadline);

    /// @notice Thrown when the caller is not the seller.
    error AssetAuctionNotTheSeller(address caller, address seller);

    /// @notice Thrown when the deadline has not passed.
    error AssetAuctionDeadlineNotPassed(uint256 deadline);

    /// @notice Thrown when the bid is not higher than the highest bid.
    error AssetAuctionBidNotHigherThanHighestBid(uint256 amount, uint256 highestBid);

    ///////////////////////////////////////////////////////////
    ///                     EVENTS                          ///
    ///////////////////////////////////////////////////////////

    /// @notice Emitted when an auction is created.
    event AuctionCreated(address seller, uint256 auctionId, uint256 assetId, uint256 reservePrice, uint256 deadline);

    /// @notice Emitted when an auction is ended.
    event AuctionEnded(uint256 auctionId, address winningBidder, uint256 winningBid);

    /// @notice Emitted when an auction is canceled.
    event AuctionCanceled(uint256 auctionId);

    /// @notice Emitted when an auction ends without meeting the reserve price.
    event AuctionReserveNotMet(uint256 auctionId, uint256 reservePrice, uint256 highestBid);

    /// @notice Emitted when a bid is placed.
    event BidPlaced(address bidder, uint256 auctionId, uint256 amount);

    ///////////////////////////////////////////////////////////
    ///                     ENUMS                           ///
    ///////////////////////////////////////////////////////////

    /// @notice The status of an auction
    enum AuctionStatus {
        Open,
        Canceled,
        Ended,
        ReserveNotMet
    }

    ///////////////////////////////////////////////////////////
    ///                     STRUCTS                         ///
    ///////////////////////////////////////////////////////////

    /// @notice The details of an auction.
    struct Auction {
        address seller;
        address highestBidder;
        address winningBidder;
        uint256 assetId;
        uint256 reservePrice;
        uint256 deadline;
        uint256 highestBid;
        uint256 winningBid;
        AuctionStatus status;
    }

    /// @notice The details of a bid.
    struct Bid {
        address user;
        uint256 auctionId;
        uint256 bid;
    }

    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mapping of auction ID to auction details.
    mapping(uint256 auctionId => Auction) private auctions;

    /// @notice Mapping of the auction ID to the bids.
    mapping(uint256 auctionId => Bid[]) private bids;

    /// @notice Instance of the ERC1155 contract that is responsible for minting assets.
    IERC1155 private factory;

    /// @notice Instance of the AssetVault contract that is responsible for managing assets.
    AssetVault private vault;

    /// @notice The token ID of the IGC token.
    uint8 private igcTokenId = 0;

    /// @notice The number of auctions.
    uint256 private auctionCount;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Construct the AssetAuction contract.
    /// @param _factoryAddress The address of the ERC1155 contract.
    /// @param _assetVaultAddress The address of the AssetVault contract.
    constructor(address _factoryAddress, address _assetVaultAddress) {
        factory = IERC1155(_factoryAddress);
        vault = AssetVault(_assetVaultAddress);
    }

    ///////////////////////////////////////////////////////////
    ///                    CORE FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Create a new auction.
    /// @param assetId The ID of the asset.
    /// @param reservePrice The reserve price of the auction.
    /// @param deadline The deadline of the auction.
    /// @dev Will throw an error if the user lacks the required balance of the asset to auction. (AssetVaultInsufficientBalance).
    //!! Consider bounds for reservePrice and deadline.
    function createAuction(uint256 assetId, uint256 reservePrice, uint256 deadline) public {
        auctionCount++;
        auctions[auctionCount] = Auction({
            seller: msg.sender,
            assetId: assetId,
            reservePrice: reservePrice,
            deadline: deadline,
            highestBid: 0,
            highestBidder: address(0),
            winningBid: 0,
            winningBidder: address(0),
            status: AuctionStatus.Open
        });

        vault.lockAsset(msg.sender, assetId, 1);

        emit AuctionCreated(msg.sender, auctionCount, assetId, reservePrice, deadline);
    }

    /// @notice Cancel an auction.
    /// @param auctionId The ID of the auction to cancel.
    function cancelAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        if (auction.status != AuctionStatus.Open) {
            revert AssetAuctionNotOpen(auction.status);
        }

        if (block.timestamp >= auction.deadline) {
            revert AssetAuctionDeadlineHasPassed(auction.deadline);
        }

        if (auction.seller != msg.sender) {
            revert AssetAuctionNotTheSeller(msg.sender, auction.seller);
        }

        auction.status = AuctionStatus.Canceled;

        vault.unlockAsset(auction.seller, auction.assetId, 1);

        emit AuctionCanceled(auctionId);
    }

    /// @notice Bid on an auction.
    /// @param auctionId The ID of the auction.
    /// @param amount The amount to bid.
    /// @dev Will throw an error if the user lacks the required balance to place the bid. (AssetVaultInsufficientBalance).
    function placeBid(uint256 auctionId, uint256 amount) external {
        Auction storage auction = auctions[auctionId];

        if (auction.status != AuctionStatus.Open) {
            revert AssetAuctionNotOpen(auction.status);
        }

        if (block.timestamp >= auction.deadline) {
            revert AssetAuctionDeadlineHasPassed(auction.deadline);
        }

        if (amount <= auction.highestBid) {
            revert AssetAuctionBidNotHigherThanHighestBid(amount, auction.highestBid);
        }

        // Lock the IGC tokens of the bidder and unlock the IGC tokens of the previous highest bidder
        vault.lockAsset(msg.sender, igcTokenId, amount);
        vault.unlockAsset(auction.highestBidder, igcTokenId, auction.highestBid);

        auction.highestBid = amount;
        auction.highestBidder = msg.sender;
        bids[auctionId].push(Bid({ user: msg.sender, auctionId: auctionId, bid: amount }));

        emit BidPlaced(msg.sender, auctionId, amount);
    }

    /// @notice Complete an auction.
    /// @param auctionId The ID of the auction to complete.
    function completeAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        if (auction.status != AuctionStatus.Open) {
            revert AssetAuctionNotOpen(auction.status);
        }

        if (block.timestamp < auction.deadline) {
            revert AssetAuctionDeadlineNotPassed(auction.deadline);
        }

        if (auction.highestBid < auction.reservePrice) {
            auction.status = AuctionStatus.ReserveNotMet;

            vault.unlockAsset(auction.seller, auction.assetId, 1);

            emit AuctionReserveNotMet(auctionId, auction.reservePrice, auction.highestBid);

            return;
        }

        auction.status = AuctionStatus.Ended;
        auction.winningBid = auction.highestBid;
        auction.winningBidder = auction.highestBidder;

        // Execute the exchange of assets by updating the balances in the AssetVault contract
        vault.unlockAsset(auction.seller, igcTokenId, auction.winningBid);
        vault.unlockAsset(auction.winningBidder, auction.assetId, 1);

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

    /// @notice Get the seller of an auction.
    /// @param auctionId The ID of the auction.
    /// @return seller The address of the seller.
    function getAuctionSeller(uint256 auctionId) public view returns (address seller) {
        return auctions[auctionId].seller;
    }

    /// @notice Get the highest bidder of an auction.
    /// @param auctionId The ID of the auction.
    /// @return highestBidder The address of the highest bidder.
    function getAuctionHighestBidder(uint256 auctionId) public view returns (address highestBidder) {
        return auctions[auctionId].highestBidder;
    }

    /// @notice Get the winning bidder of an auction.
    /// @param auctionId The ID of the auction.
    /// @return winningBidder The address of the winning bidder.
    function getAuctionWinningBidder(uint256 auctionId) public view returns (address winningBidder) {
        return auctions[auctionId].winningBidder;
    }

    /// @notice Get the asset ID of an auction.
    /// @param auctionId The ID of the auction.
    /// @return assetId The ID of the asset.
    function getAuctionAssetId(uint256 auctionId) public view returns (uint256 assetId) {
        return auctions[auctionId].assetId;
    }

    /// @notice Get the reserve price of an auction.
    /// @param auctionId The ID of the auction.
    /// @return reservePrice The reserve price.
    function getAuctionReservePrice(uint256 auctionId) public view returns (uint256 reservePrice) {
        return auctions[auctionId].reservePrice;
    }

    /// @notice Get the deadline of an auction.
    /// @param auctionId The ID of the auction.
    /// @return deadline The deadline.
    function getAuctionDeadline(uint256 auctionId) public view returns (uint256 deadline) {
        return auctions[auctionId].deadline;
    }

    /// @notice Get the highest bid of an auction.
    /// @param auctionId The ID of the auction.
    /// @return highestBid The highest bid.
    function getAuctionHighestBid(uint256 auctionId) public view returns (uint256 highestBid) {
        return auctions[auctionId].highestBid;
    }

    /// @notice Get the winning bid of an auction.
    /// @param auctionId The ID of the auction.
    /// @return winningBid The winning bid.
    function getAuctionWinningBid(uint256 auctionId) public view returns (uint256 winningBid) {
        return auctions[auctionId].winningBid;
    }

    /// @notice Get the status of an auction.
    /// @param auctionId The ID of the auction.
    /// @return status The status of the auction.
    function getAuctionStatus(uint256 auctionId) public view returns (AuctionStatus status) {
        return auctions[auctionId].status;
    }

    /// @notice Get the bids of an auction.
    /// @param auctionId The ID of the auction.
    /// @return bidsArray The bids of the auction.
    function getAuctionBids(uint256 auctionId) public view returns (Bid[] memory bidsArray) {
        return bids[auctionId];
    }

    /// @notice Get the count of bids of an auction.
    /// @param auctionId The ID of the auction.
    /// @return count The count of bids of the auction.
    function getAuctionBidCount(uint256 auctionId) public view returns (uint256 count) {
        return bids[auctionId].length;
    }

    /// @notice Get the auction count.
    /// @return count The auction count.
    function getAuctionCount() public view returns (uint256 count) {
        return auctionCount;
    }

    /// @notice Get the IGC token ID.
    /// @return tokenId The IGC token ID.
    function getIGCTokenId() public view returns (uint8 tokenId) {
        return igcTokenId;
    }

    /// @notice Get the factory contract address.
    /// @return factoryAddress The address of the assets contract.
    function getAssetFactoryAddress() public view returns (address factoryAddress) {
        return address(factory);
    }

    /// @notice Get the vault contract address.
    /// @return vaultAddress The address of the vault contract.
    function getAssetVaultAddress() public view returns (address vaultAddress) {
        return address(vault);
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

    // Implement supportsInterface
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
