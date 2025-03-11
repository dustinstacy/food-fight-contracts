//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @title AssetRental
/// @notice A contract that allows users to put their assets up for rent and allows other users to rent them.
contract AssetRental {
    ///////////////////////////////////////////////////////////
    ///                     EVENTS                          ///
    ///////////////////////////////////////////////////////////

    // Emitted when an asset is posted for rent.
    event RentalAssetPosted(address rentalOwner, uint256 tokenId, uint256 rentalPrice, uint256 rentalDuration);

    // Emitted when an asset is rented.
    event RentalAssetRented(
        address renter, uint256 rentalId, uint256 rentalPrice, uint256 rentalDuration, uint256 timeRented
    );

    // Emitted when an asset rental is cancelled.
    event RentalCancelled(address rentalOwner, address renter, uint256 rentalId, uint256 timeCancelled);

    ///////////////////////////////////////////////////////////
    ///                     ENUMS                           ///
    ///////////////////////////////////////////////////////////

    enum RentalStatus {
        Available,
        Rented,
        Cancelled,
        Removed
    }

    ///////////////////////////////////////////////////////////
    ///                     STRUCTS                         ///
    ///////////////////////////////////////////////////////////

    struct RentalAsset {
        address owner;
        address renter;
        uint256 tokenId;
        uint256 price;
        uint256 deposit;
        uint256 duration;
        uint256 returnTime;
        uint256 expiration;
        uint256 depositExpiration;
        RentalStatus status;
    }

    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    mapping(uint256 rentalId => RentalAsset) private rentals;
    mapping(address owner => mapping(uint256 tokenId => uint256 balance)) private assetBalances;
    mapping(address user => uint256 igcBalance) private igcBalances;
    mapping(address user => mapping(uint256 rentalTokenId => uint256 balance)) private renterTokens;

    uint256 private rentalCount;

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

    /// @notice Post an asset for rent.
    /// @param tokenId The ID of the asset to rent.
    /// @param price The price to rent the asset.
    /// @param deposit The deposit required to rent the asset.
    /// @param duration The duration of the rental.
    /// @param returnTime The time to return the asset and be refunded the deposit.
    function postAssetForRent(uint256 tokenId, uint256 price, uint256 deposit, uint256 duration, uint256 returnTime)
        external
    {
        // Check if the caller has any of the tokenId deposited
        if (assetBalances[msg.sender][tokenId] == 0) {
            // deposit the asset
        }

        // Increment the rental count
        rentalCount++;

        // Create a new rental asset
        rentals[rentalCount] = RentalAsset({
            owner: msg.sender,
            renter: address(0),
            tokenId: tokenId,
            price: price,
            deposit: deposit,
            duration: duration,
            returnTime: returnTime,
            expiration: 0,
            depositExpiration: 0,
            status: RentalStatus.Available
        });

        // Update the asset balances
        assetBalances[msg.sender][tokenId] -= 1;

        emit RentalAssetPosted(msg.sender, tokenId, price, duration);
    }

    /// @notice Rent an asset.
    /// @param rentalId The ID of the rental asset.
    function rentAsset(uint256 rentalId) external {
        RentalAsset memory rental = rentals[rentalId];

        // Check if the rental is available
        if (rental.status != RentalStatus.Available) {
            revert("AssetRental: Rental not available");
        }

        // Check if the caller has enough funds to rent the asset
        if (igcBalances[msg.sender] < rental.price + rental.deposit) {
            revert("AssetRental: Insufficient funds");
        }

        // Rent the asset
        igcBalances[msg.sender] -= rental.price + rental.deposit;
        igcBalances[rental.owner] += rental.price + rental.deposit;
        renterTokens[msg.sender][rental.tokenId] += 1;

        // Update the rental
        rental.renter = msg.sender;
        rental.expiration = block.timestamp + rental.duration;
        rental.depositExpiration = rental.expiration + rental.returnTime;
        rental.status = RentalStatus.Rented;

        // Emit an event
        emit RentalAssetRented(msg.sender, rentalId, rental.price, rental.duration, block.timestamp);
    }

    function cancelRental(uint256 rentalId) external {
        RentalAsset memory rental = rentals[rentalId];

        // Check if the rental is being rented
        if (rental.status != RentalStatus.Rented) {
            revert("AssetRental: Rental not currently rented");
        }

        // Check if the caller is the owner of the rental
        if (rental.owner != msg.sender) {
            revert("AssetRental: Not the owner of the rental");
        }

        if (block.timestamp < rental.expiration) {
            // Check if the owner has enough funds to refund the renter
            if (igcBalances[rental.owner] < rental.price + rental.deposit) {
                revert("AssetRental: Insufficient funds to refund the renter");
            }

            // Refund the renter
            igcBalances[rental.owner] -= rental.price;
            igcBalances[rental.renter] += rental.price;
        }

        // Cancel the rental
        rental.status = RentalStatus.Cancelled;

        // Remove the rental from the renter's tokens
        renterTokens[rental.renter][rental.tokenId] -= 1;

        // Refund the deposit
        igcBalances[rental.renter] += rental.deposit;

        // Emit an event
        emit RentalCancelled(rental.owner, rental.renter, rentalId, block.timestamp);
    }
}
