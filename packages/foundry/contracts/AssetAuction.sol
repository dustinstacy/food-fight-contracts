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
        Ended
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

    mapping(uint256 auctionId => Auction) public auctions;
    mapping(address => mapping(uint256 => uint256)) public balances;

    uint256 private auctionCount;

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
        if (balances[msg.sender][assetTokenId] == 0) {
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

        // Update the user balances
        balances[msg.sender][assetTokenId] -= 1;

        emit AuctionCreated(auctionCount, assetTokenId, reservePrice, deadline, style);
    }
}
