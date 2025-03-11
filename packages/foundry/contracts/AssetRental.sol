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
}
