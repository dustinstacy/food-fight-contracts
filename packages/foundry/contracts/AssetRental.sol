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

    // Emitted when an asset rental is returned.
    event RentalReturned(address renter, uint256 rentalId, uint256 timeReturned);

    // Emitted when an asset rental is retrieved.
    event RentalRetrieved(address rentalOwner, address renter, uint256 rentalId, uint256 timeRetrieved);

    // Emitted when assets are withdrawn from the contract.
    event AssetsWithdrawn(address to, uint256[] tokenIds, uint256[] amounts);

    // Emitted when IGC is withdrawn from the contract.
    event IGCWithdrawn(address to, uint256 amount);

    // Emitted when assets are deposited into the contract.
    event AssetsDeposited(address from, uint256[] tokenIds, uint256[] amounts);

    // Emitted when IGC is deposited into the contract.
    event IGCDeposited(address from, uint256 amount);

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
    mapping(address user => uint256 amountOwed) private unreturnedDeposits;

    uint8 private igcTokenId = 0;
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
            // Create empty arrays for the depositAssets function
            uint256[] memory tokenIds = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);

            // Store the tokenId and amount in the arrays
            tokenIds[0] = tokenId;
            amounts[0] = 1;

            // Deposit the asset
            depositAssets(tokenIds, amounts);
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
            depositIGC(rental.price + rental.deposit - igcBalances[msg.sender]);
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

    function returnAsset(uint256 rentalId) external {
        RentalAsset memory rental = rentals[rentalId];

        // Check if the rental is being rented
        if (rental.status != RentalStatus.Rented) {
            revert("AssetRental: Rental not currently rented");
        }

        // Check if the caller is the renter
        if (rental.renter != msg.sender) {
            revert("AssetRental: Not the renter of the rental");
        }

        // Check if the rental has expired
        if (block.timestamp < rental.expiration + rental.depositExpiration) {
            // Return the deposit
            igcBalances[rental.renter] += rental.deposit;
        }

        // Return the asset
        rental.status = RentalStatus.Available;

        // Remove the rental from the renter's tokens
        renterTokens[rental.renter][rental.tokenId] -= 1;

        // Check if the owner has enough funds to refund the deposit
        if (igcBalances[rental.owner] < rental.deposit) {
            // Add the deposit to the unreturned deposits
            unreturnedDeposits[rental.owner] += rental.deposit;
            return;
        }

        // Update the owner igc balance
        igcBalances[rental.owner] -= rental.deposit;

        emit RentalReturned(rental.renter, rentalId, block.timestamp);
    }

    function retrieveAsset(uint256 rentalId) external {
        RentalAsset memory rental = rentals[rentalId];

        // Check if the rental is being rented
        if (rental.status != RentalStatus.Rented) {
            revert("AssetRental: Rental not being rented");
        }

        // Check if the caller is the owner of the rental
        if (rental.owner != msg.sender) {
            revert("AssetRental: Not the owner of the rental");
        }

        // Check if the rental has passed the return deadline
        if (block.timestamp < rental.expiration + rental.depositExpiration) {
            revert("AssetRental: Rental has not passed the return deadline");
        }

        // Update the renter's tokens
        renterTokens[rental.renter][rental.tokenId] -= 1;

        // Make the asset available for rent
        rental.status = RentalStatus.Available;

        emit RentalRetrieved(rental.owner, rental.renter, rentalId, block.timestamp);
    }

    function unlistAsset(uint256 rentalId) external {
        RentalAsset memory rental = rentals[rentalId];

        // Check if the caller is the owner of the rental
        if (rental.owner != msg.sender) {
            revert("AssetRental: Not the owner of the rental");
        }

        // Check if the rental is being rented
        if (rental.status == RentalStatus.Rented) {
            revert("AssetRental: Rental is currently being rented");
        }

        // Remove the rental
        rental.status = RentalStatus.Removed;

        // Update the asset balances
        assetBalances[msg.sender][rental.tokenId] += 1;
    }

    ///////////////////////////////////////////////////////////
    ///                  ASSETS FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Withdraw assets from the contract
    /// @param tokenIds The token IDs of the assets to withdraw
    /// @param amounts The amounts of the assets to withdraw
    function withdrawAssets(uint256[] memory tokenIds, uint256[] memory amounts) external {
        // Check if the token IDs and amounts arrays have the same length
        if (tokenIds.length != amounts.length) {
            revert("AssetRental: Arrays length mismatch");
        }

        // Store the necessary variables for the safeBatchTransferFrom function
        uint256 length = tokenIds.length;
        address from = address(this);
        address to = msg.sender;
        bytes memory data = "";

        for (uint256 i = 0; i < length; i++) {
            // Check if the user has enough balance
            if (assetBalances[from][tokenIds[i]] < amounts[i]) {
                revert("AssetRental: Insufficient balance");
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
            revert("AssetRental: Insufficient balance");
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

    /// @notice Deposit assets into the contract
    /// @param tokenIds The token IDs of the assets to deposit
    /// @param amounts The amounts of the assets to deposit
    function depositAssets(uint256[] memory tokenIds, uint256[] memory amounts) public {
        // Check if the token IDs and amounts arrays have the same length
        if (tokenIds.length != amounts.length) {
            revert("AssetRental: Arrays length mismatch");
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
}
