//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @title AssetAuction
/// @notice Auction contract where users can put their NFTs up for auction and other users can bid on them.
contract AssetAuction {
    ///////////////////////////////////////////////////////////
    ///                     EVENTS                          ///
    ///////////////////////////////////////////////////////////

    event AuctionCreated(uint256 auctionId, uint256 assetTokenId, uint256 reservePrice, uint256 deadline, Style style);

    ///////////////////////////////////////////////////////////
    ///                     ENUMS                           ///
    ///////////////////////////////////////////////////////////

    enum Status {
        Open,
        Cancelled,
        Ended,
        ReserveNotMet
    }

    enum Style {
        English,
        Dutch,
        Blind,
        Candle
    }

    ///////////////////////////////////////////////////////////
    ///                     STRUCTS                         ///
    ///////////////////////////////////////////////////////////

    struct Auction {
        address seller;
        address highestBidder;
        address winningBidder;
        uint256 assetTokenId;
        uint256 reservePrice;
        uint256 deadline;
        uint256 highestBid;
        uint256 winningBid;
        Status status;
        Style style;
        Bid[] bids;
    }

    struct Bid {
        address user;
        uint256 auctionId;
        uint256 bid;
    }

    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    mapping(uint256 auctionId => Auction) private auctions;
    mapping(address user => mapping(uint256 assetId => uint256 assetBalance)) private assetBalances;
    mapping(address user => uint256 igcBalance) private igcBalances;

    uint256 private auctionCount;
    uint8 private igcTokenId = 0;

    IERC1155 private assetsContract;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    constructor(address _assetsContract) {
        assetsContract = IERC1155(_assetsContract);
    }

    ///////////////////////////////////////////////////////////
    ///                    CORE FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Creates a new auction
    /// @param assetTokenId The ID of the asset token
    /// @param reservePrice The reserve price of the auction
    /// @param deadline The deadline of the auction
    /// @param style The style of the auction
    function createAuction(uint256 assetTokenId, uint256 reservePrice, uint256 deadline, Style style) public {
        // Check if the caller has any of the assetTokenId deposited
        if (assetBalances[msg.sender][assetTokenId] == 0) {
            // depositAssets()
        }

        // Increment the auction count
        auctionCount++;

        // Create an empty array of bids
        Bid[] memory bids = new Bid[](0);

        // Create the auction and store it in the auctions mapping
        auctions[auctionCount] = Auction({
            assetTokenId: assetTokenId,
            seller: msg.sender,
            reservePrice: reservePrice,
            deadline: deadline,
            highestBid: 0,
            highestBidder: address(0),
            winningBid: 0,
            winningBidder: address(0),
            status: Status.Open,
            style: style,
            bids: bids
        });

        // Update the user assetBalances
        assetBalances[msg.sender][assetTokenId] -= 1;

        emit AuctionCreated(auctionCount, assetTokenId, reservePrice, deadline, style);
    }

    /// @notice Allows a user to bid on an auction
    /// @param auctionId The ID of the auction
    /// @param amount The amount to bid
    function bid(uint256 auctionId, uint256 amount) external {
        Auction storage auction = auctions[auctionId];

        // Check if the auction is open
        if (auction.status != Status.Open) {
            revert("Auction is not open");
        }

        // Check if the auction has ended
        if (block.timestamp >= auction.deadline) {
            revert("Auction has ended");
        }

        // Check if the bid is higher than the highest bid
        if (amount <= auction.highestBid) {
            revert("Bid must be higher than the highest bid");
        }

        // Update the highest bid and highest bidder
        auction.highestBid = amount;
        auction.highestBidder = msg.sender;

        // Add the bid to the bids array
        auction.bids.push(Bid({ user: msg.sender, auctionId: auctionId, bid: amount }));
    }

    /// @notice Allows a seller to complete an auction
    /// @param auctionId The ID of the auction
    function completeAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        // Check if the auction is open
        if (auction.status != Status.Open) {
            revert("Auction is not open");
        }

        // Check if the deadline has passed
        if (block.timestamp < auction.deadline) {
            revert("Auction has not passed the deadline");
        }

        // Check if the reserve price has been met
        if (auction.highestBid < auction.reservePrice) {
            // Update the auction status
            auction.status = Status.ReserveNotMet;
            // Update the seller assetBalances
            assetBalances[auction.seller][auction.assetTokenId] += 1;
            return;
        }

        // Update the auction status
        auction.status = Status.Ended;

        // Update the winning bid and winning bidder
        auction.winningBid = auction.highestBid;
        auction.winningBidder = auction.highestBidder;
    }
}
