//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title AssetAuction
/// @notice Auction contract where users can put their NFTs up for auction and other users can bid on them.
contract AssetAuction is IERC1155Receiver {
    ///////////////////////////////////////////////////////////
    ///                     ERRORS                          ///
    ///////////////////////////////////////////////////////////

    // Emitted when the auction is not open
    error AssetAuctionAuctionIsNotOpen(AuctionStatus status);

    // Emitted when the deadline has passed
    error AssetAuctionDeadlineHasPassed(uint256 deadline);

    // Emitted when the deadline has not passed
    error AssetAuctionDeadlineNotPassed(uint256 deadline);

    // Emitted when the bid is not higher than the highest bid
    error AssetAuctionBidNotHigherThanHighestBid(uint256 amount, uint256 highestBid);

    // Emitted when the auction has not ended
    error AssetAuctionAuctionHasNotEnded(AuctionStatus status);

    // Emitted when the asset has already been claimed
    error AssetAuctionAssetAlreadyClaimed(AuctionStatus status);

    // Emitted when the user is not the seller
    error AssetAuctionNotTheSeller(address caller, address seller);

    // Emitted when the user is not the winning bidder
    error AssetAuctionNotTheWinningBidder(address caller, address winningBidder);

    /// Emitted when the token IDs and amounts arrays have different lengths.
    error AssetAuctionArraysLengthMismatch(uint256 tokenIdsLength, uint256 amountsLength);

    /// Emitted when the caller tries to withdraw more assets than they own.
    error AssetAuctionInsufficientBalance(address caller, uint256 balance, uint256 amount, uint256 tokenId);

    ///////////////////////////////////////////////////////////
    ///                     EVENTS                          ///
    ///////////////////////////////////////////////////////////

    // Emitted when an auction is created
    event AuctionCreated(
        address seller, uint256 auctionId, uint256 assetTokenId, uint256 reservePrice, uint256 deadline, Style style
    );

    // Emitted when a bid is placed
    event BidPlaced(address bidder, uint256 auctionId, uint256 amount);

    // Emitted when an auction is ended
    event AuctionEnded(uint256 auctionId, address winningBidder, uint256 winningBid);

    // Emitted when an auction is cancelled
    event AuctionCanceled(uint256 auctionId);

    // Emitted when the reserve price is not met
    event AuctionReserveNotMet(uint256 auctionId, uint256 reservePrice, uint256 highestBid);

    // Emitted when an asset is claimed
    event AssetClaimed(address winningBidder, uint256 auctionId, uint256 assetClaimedTokenId, uint256 winningBid);

    // Emitted when assets are withdrawn
    event AssetsWithdrawn(address to, uint256[] tokenIds, uint256[] amounts);

    // Emitted when IGC is withdrawn
    event IGCWithdrawn(address to, uint256 amount);

    // Emitted when assets are deposited
    event AssetsDeposited(address from, uint256[] tokenIds, uint256[] amounts);

    // Emitted when IGC is deposited
    event IGCDeposited(address from, uint256 amount);

    ///////////////////////////////////////////////////////////
    ///                     ENUMS                           ///
    ///////////////////////////////////////////////////////////

    enum AuctionStatus {
        Open,
        Canceled,
        Ended,
        ReserveNotMet,
        Claimed
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
        AuctionStatus status;
        Style style;
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
    mapping(uint256 auctionId => Bid[]) private bids;
    mapping(address user => mapping(uint256 assetId => uint256 assetBalance)) private assetBalances;
    mapping(address user => uint256 igcBalance) private igcBalances;

    uint8 private igcTokenId = 0;
    uint256 private auctionCount;
    IERC1155 private assetsContract;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @param _assetsContractAddress The address of the ERC1155 contract.
    constructor(address _assetsContractAddress) {
        assetsContract = IERC1155(_assetsContractAddress);
    }

    ///////////////////////////////////////////////////////////
    ///                    CORE FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Creates a new auction
    /// @param assetTokenId The ID of the asset token
    /// @param reservePrice The reserve price of the auction
    /// @param deadline The deadline of the auction
    /// @param style The style of the auction
    /// @dev Should set bounds for the reserve price and deadline
    function createAuction(uint256 assetTokenId, uint256 reservePrice, uint256 deadline, Style style) public {
        // Check if the caller has any of the assetTokenId deposited
        if (assetBalances[msg.sender][assetTokenId] == 0) {
            // Create empty arrays for the depositAssets function
            uint256[] memory tokenIds = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);

            // Store the assetTokenId and amount in the arrays
            tokenIds[0] = assetTokenId;
            amounts[0] = 1;

            // Deposit the asset
            depositAssets(tokenIds, amounts);
        }

        // Increment the auction count
        auctionCount++;

        // Create the auction and store it in the auctions mapping
        auctions[auctionCount] = Auction({
            seller: msg.sender,
            assetTokenId: assetTokenId,
            reservePrice: reservePrice,
            deadline: deadline,
            highestBid: 0,
            highestBidder: address(0),
            winningBid: 0,
            winningBidder: address(0),
            status: AuctionStatus.Open,
            style: style
        });

        // Update the asset balances
        assetBalances[msg.sender][assetTokenId] -= 1;

        emit AuctionCreated(msg.sender, auctionCount, assetTokenId, reservePrice, deadline, style);
    }

    /// @notice Allows a seller to cancel an auction
    /// @param auctionId The ID of the auction
    function cancelAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        // Check if the auction is open
        if (auction.status != AuctionStatus.Open) {
            revert AssetAuctionAuctionIsNotOpen(auction.status);
        }

        // Check if the deadline has passed
        if (block.timestamp >= auction.deadline) {
            revert AssetAuctionDeadlineHasPassed(auction.deadline);
        }

        // Check if the caller is the seller
        if (auction.seller != msg.sender) {
            revert AssetAuctionNotTheSeller(msg.sender, auction.seller);
        }

        // Update the auction status
        auction.status = AuctionStatus.Canceled;

        // Update the seller assetBalances
        assetBalances[auction.seller][auction.assetTokenId] += 1;

        emit AuctionCanceled(auctionId);
    }

    /// @notice Allows a seller to complete an auction
    /// @param auctionId The ID of the auction
    function completeAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        // Check if the auction is open
        if (auction.status != AuctionStatus.Open) {
            revert AssetAuctionAuctionIsNotOpen(auction.status);
        }

        // Check if the deadline has passed
        if (block.timestamp < auction.deadline) {
            revert AssetAuctionDeadlineNotPassed(auction.deadline);
        }

        // Check if the caller is the seller
        if (auction.seller != msg.sender) {
            revert AssetAuctionNotTheSeller(msg.sender, auction.seller);
        }

        // Check if the reserve price has been met
        if (auction.highestBid < auction.reservePrice) {
            // Update the auction status
            auction.status = AuctionStatus.ReserveNotMet;
            // Update the seller assetBalances
            assetBalances[auction.seller][auction.assetTokenId] += 1;

            emit AuctionReserveNotMet(auctionId, auction.reservePrice, auction.highestBid);

            return;
        }

        // Update the auction status
        auction.status = AuctionStatus.Ended;

        // Update the winning bid and winning bidder
        auction.winningBid = auction.highestBid;
        auction.winningBidder = auction.highestBidder;

        emit AuctionEnded(auctionId, auction.winningBidder, auction.winningBid);
    }

    /// @notice Allows a user to bid on an auction
    /// @param auctionId The ID of the auction
    /// @param amount The amount to bid
    /// @dev Should check if the bidder has enough IGC to place the bid
    function placeBid(uint256 auctionId, uint256 amount) external {
        Auction storage auction = auctions[auctionId];

        // Check if the auction is open
        if (auction.status != AuctionStatus.Open) {
            revert AssetAuctionAuctionIsNotOpen(auction.status);
        }

        // Check if the auction has ended
        if (block.timestamp >= auction.deadline) {
            revert AssetAuctionDeadlineHasPassed(auction.deadline);
        }

        // Check if the bid is higher than the highest bid
        if (amount <= auction.highestBid) {
            revert AssetAuctionBidNotHigherThanHighestBid(amount, auction.highestBid);
        }

        // Update the highest bid and highest bidder
        auction.highestBid = amount;
        auction.highestBidder = msg.sender;

        // Add the bid to the bids array
        bids[auctionId].push(Bid({ user: msg.sender, auctionId: auctionId, bid: amount }));

        emit BidPlaced(msg.sender, auctionId, amount);
    }

    /// @notice Allows a user to claim the asset they won in an auction
    /// @param auctionId The ID of the auction
    function claimAsset(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        if (auction.status == AuctionStatus.Claimed) {
            revert AssetAuctionAssetAlreadyClaimed(auction.status);
        }

        // Check if the has ended
        if (auction.status != AuctionStatus.Ended) {
            revert AssetAuctionAuctionHasNotEnded(auction.status);
        }

        // Check if the caller is the winning bidder
        if (auction.winningBidder != msg.sender) {
            revert AssetAuctionNotTheWinningBidder(msg.sender, auction.winningBidder);
        }

        // Check the IGC balance of the bidder
        if (igcBalances[msg.sender] < auction.winningBid) {
            depositIGC(auction.winningBid - igcBalances[msg.sender]);
        }

        // update the auction status
        auction.status = AuctionStatus.Claimed;

        // update the igcBalances
        igcBalances[msg.sender] -= auction.winningBid;
        igcBalances[auction.seller] += auction.winningBid;

        // Transfer the asset to the winning bidder
        assetBalances[auction.winningBidder][auction.assetTokenId] += 1;

        emit AssetClaimed(auction.winningBidder, auctionId, auction.assetTokenId, auction.winningBid);
    }

    ///////////////////////////////////////////////////////////
    ///                  ASSETS FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Deposit assets into the contract
    /// @param tokenIds The token IDs of the assets to deposit
    /// @param amounts The amounts of the assets to deposit
    function depositAssets(uint256[] memory tokenIds, uint256[] memory amounts) public {
        // Check if the token IDs and amounts arrays have the same length
        if (tokenIds.length != amounts.length) {
            revert AssetAuctionArraysLengthMismatch(tokenIds.length, amounts.length);
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
            assetBalances[from][tokenIds[i]] += amounts[i];
        }

        emit AssetsDeposited(from, tokenIds, amounts);
    }

    /// @notice Deposit IGC into the contract
    /// @param amount The amount of IGC to deposit
    function depositIGC(uint256 amount) public {
        // Store the necessary variables for the safeTransferFrom function
        address from = msg.sender;
        address to = address(this);
        bytes memory data = "";

        // Transfer the IGC to the contract
        assetsContract.safeTransferFrom(from, to, igcTokenId, amount, data);

        // Update the user balance
        igcBalances[from] += amount;

        emit IGCDeposited(from, amount);
    }

    /// @notice Withdraw assets from the contract
    /// @param tokenIds The token IDs of the assets to withdraw
    /// @param amounts The amounts of the assets to withdraw
    function withdrawAssets(uint256[] memory tokenIds, uint256[] memory amounts) external {
        // Check if the token IDs and amounts arrays have the same length
        if (tokenIds.length != amounts.length) {
            revert AssetAuctionArraysLengthMismatch(tokenIds.length, amounts.length);
        }

        // Store the necessary variables for the safeBatchTransferFrom function
        uint256 length = tokenIds.length;
        address from = address(this);
        address to = msg.sender;
        bytes memory data = "";

        for (uint256 i = 0; i < length; i++) {
            // Check if the user has enough balance
            if (assetBalances[from][tokenIds[i]] < amounts[i]) {
                revert AssetAuctionInsufficientBalance(from, assetBalances[from][tokenIds[i]], amounts[i], tokenIds[i]);
            }
        }

        // Update the user balances
        for (uint256 i = 0; i < length; i++) {
            assetBalances[from][tokenIds[i]] -= amounts[i];
        }

        // Transfer the assets to the user
        assetsContract.safeBatchTransferFrom(from, to, tokenIds, amounts, data);

        emit AssetsWithdrawn(to, tokenIds, amounts);
    }

    /// @notice Withdraw IGC from the contract
    /// @param amount The amount of IGC to withdraw
    function withdrawIGC(uint256 amount) external {
        // Check if the user has enough balance
        if (igcBalances[msg.sender] < amount) {
            revert AssetAuctionInsufficientBalance(msg.sender, igcBalances[msg.sender], amount, igcTokenId);
        }

        // Store the necessary variables for the safeTransferFrom function
        address from = address(this);
        address to = msg.sender;
        bytes memory data = "";

        // Update the user balance
        igcBalances[msg.sender] -= amount;

        // Transfer the IGC to the user
        assetsContract.safeTransferFrom(from, to, igcTokenId, amount, data);

        emit IGCWithdrawn(to, amount);
    }

    ///////////////////////////////////////////////////////////
    ///                  VIEW FUNCTIONS                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Get the details of an auction
    /// @param auctionId The ID of the auction
    /// @return auction The details of the auction
    function getAuction(uint256 auctionId) public view returns (Auction memory auction) {
        return auctions[auctionId];
    }

    /// @notice Get the seller of an auction
    /// @param auctionId The ID of the auction
    /// @return seller The address of the seller
    function getAuctionSeller(uint256 auctionId) public view returns (address seller) {
        return auctions[auctionId].seller;
    }

    /// @notice Get the highest bidder of an auction
    /// @param auctionId The ID of the auction
    /// @return highestBidder The address of the highest bidder
    function getAuctionHighestBidder(uint256 auctionId) public view returns (address highestBidder) {
        return auctions[auctionId].highestBidder;
    }

    /// @notice Get the winning bidder of an auction
    /// @param auctionId The ID of the auction
    /// @return winningBidder The address of the winning bidder
    function getAuctionWinningBidder(uint256 auctionId) public view returns (address winningBidder) {
        return auctions[auctionId].winningBidder;
    }

    /// @notice Get the asset token ID of an auction
    /// @param auctionId The ID of the auction
    /// @return assetTokenId The asset token ID
    function getAuctionAssetTokenId(uint256 auctionId) public view returns (uint256 assetTokenId) {
        return auctions[auctionId].assetTokenId;
    }

    /// @notice Get the reserve price of an auction
    /// @param auctionId The ID of the auction
    /// @return reservePrice The reserve price
    function getAuctionReservePrice(uint256 auctionId) public view returns (uint256 reservePrice) {
        return auctions[auctionId].reservePrice;
    }

    /// @notice Get the deadline of an auction
    /// @param auctionId The ID of the auction
    /// @return deadline The deadline
    function getAuctionDeadline(uint256 auctionId) public view returns (uint256 deadline) {
        return auctions[auctionId].deadline;
    }

    /// @notice Get the highest bid of an auction
    /// @param auctionId The ID of the auction
    /// @return highestBid The highest bid
    function getAuctionHighestBid(uint256 auctionId) public view returns (uint256 highestBid) {
        return auctions[auctionId].highestBid;
    }

    /// @notice Get the winning bid of an auction
    /// @param auctionId The ID of the auction
    /// @return winningBid The winning bid
    function getAuctionWinningBid(uint256 auctionId) public view returns (uint256 winningBid) {
        return auctions[auctionId].winningBid;
    }

    /// @notice Get the status of an auction
    /// @param auctionId The ID of the auction
    /// @return status The status of the auction
    function getAuctionAuctionStatus(uint256 auctionId) public view returns (AuctionStatus status) {
        return auctions[auctionId].status;
    }

    /// @notice Get the style of an auction
    /// @param auctionId The ID of the auction
    /// @return style The style of the auction
    function getAuctionStyle(uint256 auctionId) public view returns (Style style) {
        return auctions[auctionId].style;
    }

    /// @notice Get the bids of an auction
    /// @param auctionId The ID of the auction
    /// @return bidsArray The bids of the auction
    function getAuctionBids(uint256 auctionId) public view returns (Bid[] memory bidsArray) {
        return bids[auctionId];
    }

    /// @notice Get the count of bids of an auction
    /// @param auctionId The ID of the auction
    /// @return count The count of bids of the auction
    function getAuctionBidCount(uint256 auctionId) public view returns (uint256 count) {
        return bids[auctionId].length;
    }

    /// @notice Get the balance of an asset for a user
    /// @param user The address of the user
    /// @param assetId The ID of the asset
    /// @return balance The balance of the asset
    function getAssetBalance(address user, uint256 assetId) public view returns (uint256 balance) {
        return assetBalances[user][assetId];
    }

    /// @notice Get the balance of IGC for a user
    /// @param user The address of the user
    /// @return balance The balance of IGC
    function getIGCBalance(address user) public view returns (uint256 balance) {
        return igcBalances[user];
    }

    /// @notice Get the auction count
    /// @return count The auction count
    function getAuctionCount() public view returns (uint256 count) {
        return auctionCount;
    }

    /// @notice Get the IGC token ID
    /// @return tokenId The IGC token ID
    function getIGCTokenId() public view returns (uint8 tokenId) {
        return igcTokenId;
    }

    /// @notice Get the assets contract address
    /// @return address The address of the assets contract
    function getAssetsContract() public view returns (address) {
        return address(assetsContract);
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
