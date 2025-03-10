//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @title AssetAuction
/// @notice Auction contract where users can put their NFTs up for auction and other users can bid on them.
contract AssetAuction {
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
        address nft;
        address seller;
        address highestBidder;
        address winningBidder;
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

    uint256 private auctionCount;

    IERC1155 private assetsContract;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    constructor(address _assetsContract) {
        assetsContract = IERC1155(_assetsContract);
    }
}
