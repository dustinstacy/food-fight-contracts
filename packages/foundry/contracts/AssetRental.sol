//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { AssetVault } from "./AssetVault.sol";

/// @title AssetRental
/// @notice This contract allows users to list assets for rent and rent assets from other users.
contract AssetRental is IERC1155Receiver {
    ///////////////////////////////////////////////////////////
    ///                     ERRORS                          ///
    ///////////////////////////////////////////////////////////

    /// @notice Thrown when the asset is not available for rent.
    error AssetRentalAssetIsNotAvailable(RentalStatus status);

    /// @notice Thrown when the asset is currently being rented.
    error AssetRentalIsCurrentlyRented(RentalStatus status);

    /// @notice Thrown when the caller is not the owner of the asset.
    error AssetRentalNotTheOwner(address caller, address owner);

    /// @notice Thrown when the caller is not the renter of the asset.
    error AssetRentalNotTheRenter(address caller, address renter);

    ///////////////////////////////////////////////////////////
    ///                     EVENTS                          ///
    ///////////////////////////////////////////////////////////

    /// @notice Emitted when an asset is posted for rent.
    event RentalAssetPosted(address rentalOwner, uint256 assetId, uint256 rentalPrice, uint256 rentalDuration);

    /// @notice Emitted when an asset is relisted.
    event RentalAssetRelisted(address rentalOwner, uint256 rentalAssetId, uint256 rentalPrice, uint256 rentalDuration);

    /// @notice Emitted when an asset is unlisted.
    event RentalAssetUnlisted(address rentalOwner, uint256 rentalAssetId);

    /// @notice Emitted when an asset is updated.
    event RentalAssetUpdated(address rentalOwner, uint256 rentalAssetId, uint256 rentalPrice, uint256 rentalDuration);

    /// @notice Emitted when an asset is rented.
    event RentalAssetRented(
        address renter, uint256 rentalAssetId, uint256 rentalPrice, uint256 rentalDuration, uint256 timeRented
    );

    ///////////////////////////////////////////////////////////
    ///                     ENUMS                           ///
    ///////////////////////////////////////////////////////////

    /// @notice The status of the rental asset.
    enum RentalStatus {
        Available,
        Rented,
        Unavailable
    }

    ///////////////////////////////////////////////////////////
    ///                     STRUCTS                         ///
    ///////////////////////////////////////////////////////////

    /// @notice The details of the rental asset.
    struct RentalAsset {
        address owner;
        address renter;
        uint256 assetId;
        uint256 price;
        uint256 duration;
        uint256 expiration;
        RentalStatus status;
    }

    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mapping of rental ID to rental asset.
    mapping(uint256 rentalAssetId => RentalAsset) private rentals;

    /// @notice Mapping of a user to their rented asset balances.
    mapping(address user => mapping(uint256 assetId => uint256 balance)) private rentedAssets;

    /// @notice Instance of the ERC1155 contract that is responsible for minting assets.
    IERC1155 private factory;

    /// @notice Instance of the AssetVault contract that is responsible for managing assets.
    AssetVault private vault;

    /// @notice The token ID of the IGC token.
    uint8 private igcTokenId = 0;

    /// @notice The number of rental assets.
    uint256 private rentalAssetCount;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Construct a new AssetRental contract.
    /// @param _factoryAddress The address of the ERC1155 contract.
    /// @param _vaultAddress The address of the AssetVault contract.
    constructor(address _factoryAddress, address _vaultAddress) {
        factory = IERC1155(_factoryAddress);
        vault = AssetVault(_vaultAddress);
    }

    ///////////////////////////////////////////////////////////
    ///                    CORE FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Post an asset for rent.
    /// @param assetId The ID of the asset to rent.
    /// @param price The price to rent the asset.
    /// @param duration The duration of the rental.
    /// @dev Will throw an error if the user lacks the required balance of the asset to post for rent. (AssetVaultInsufficientBalance).
    //!! Consider bounds for price and duration.
    function createRental(uint256 assetId, uint256 price, uint256 duration) external {
        rentalAssetCount++;
        rentals[rentalAssetCount] = RentalAsset({
            owner: msg.sender,
            renter: address(0),
            assetId: assetId,
            price: price,
            duration: duration,
            expiration: 0,
            status: RentalStatus.Available
        });

        vault.lockAsset(msg.sender, assetId, 1);

        emit RentalAssetPosted(msg.sender, assetId, price, duration);
    }

    function relistAsset(uint256 rentalAssetId) external {
        RentalAsset memory rental = rentals[rentalAssetId];

        emit RentalAssetRelisted(msg.sender, rentalAssetId, rental.price, rental.duration);
    }

    function unlistAsset(uint256 rentalAssetId) external {
        emit RentalAssetUnlisted(msg.sender, rentalAssetId);
    }

    function updateRental(uint256 rentalAssetId, uint256 price, uint256 duration) external {
        emit RentalAssetUpdated(msg.sender, rentalAssetId, price, duration);
    }

    function rentAsset(uint256 rentalAssetId) external {
        RentalAsset memory rental = rentals[rentalAssetId];

        emit RentalAssetRented(msg.sender, rentalAssetId, rental.price, rental.duration, block.timestamp);
    }

    function checkRentalStatus(uint256 rentalAssetId) external view returns (RentalStatus status) {
        return rentals[rentalAssetId].status;
    }

    ///////////////////////////////////////////////////////////
    ///                  VIEW FUNCTIONS                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Get the rental asset details.
    /// @param rentalAssetId The ID of the rental asset.
    /// @return rentalAsset The rental asset details.
    function getRentalAsset(uint256 rentalAssetId) external view returns (RentalAsset memory rentalAsset) {
        return rentals[rentalAssetId];
    }

    /// @notice Get the rental asset owner.
    /// @param rentalAssetId The ID of the rental asset.
    /// @return owner The rental asset owner.
    function getRentalAssetOwner(uint256 rentalAssetId) external view returns (address owner) {
        return rentals[rentalAssetId].owner;
    }

    /// @notice Get the rental asset renter.
    /// @param rentalAssetId The ID of the rental asset.
    /// @return renter The rental asset renter.
    function getRentalAssetRenter(uint256 rentalAssetId) external view returns (address renter) {
        return rentals[rentalAssetId].renter;
    }

    /// @notice Get the rental asset asset ID.
    /// @param rentalAssetId The ID of the rental asset.
    /// @return assetId the rental asset asset ID.
    function getRentalAssetTokenId(uint256 rentalAssetId) external view returns (uint256 assetId) {
        return rentals[rentalAssetId].assetId;
    }

    /// @notice Get the rental asset price.
    /// @param rentalAssetId The ID of the rental asset.
    /// @return price The rental asset price.
    function getRentalAssetPrice(uint256 rentalAssetId) external view returns (uint256 price) {
        return rentals[rentalAssetId].price;
    }

    /// @notice Get the rental asset duration.
    /// @param rentalAssetId The ID of the rental asset.
    /// @return duration The rental asset duration.
    function getRentalAssetDuration(uint256 rentalAssetId) external view returns (uint256 duration) {
        return rentals[rentalAssetId].duration;
    }

    /// @notice Get the rental asset expiration.
    /// @param rentalAssetId The ID of the rental asset.
    /// @return expiration The rental asset expiration.
    function getRentalAssetExpiration(uint256 rentalAssetId) external view returns (uint256 expiration) {
        return rentals[rentalAssetId].expiration;
    }

    /// @notice Get the rental asset status.
    /// @param rentalAssetId The ID of the rental asset.
    /// @return status The rental asset status.
    function getRentalAssetStatus(uint256 rentalAssetId) external view returns (RentalStatus status) {
        return rentals[rentalAssetId].status;
    }

    /// @notice Get the rented asset balance of a user.
    /// @param user The address of the user.
    /// @param assetId The ID of the asset.
    /// @return balance The rented asset balance of the user.
    function getRentedAsset(address user, uint256 assetId) external view returns (uint256 balance) {
        return rentedAssets[user][assetId];
    }

    /// @notice Get the rental asset count.
    /// @return count The rental asset count.
    function getRentalCount() external view returns (uint256 count) {
        return rentalAssetCount;
    }

    /// @notice Get the IGC token ID.
    /// @return assetId The IGC token ID.
    function getIGCTokenId() external view returns (uint8 assetId) {
        return igcTokenId;
    }

    /// @notice Get the factory contract address.
    /// @return factoryAddress The factory contract address.
    function getFactoryAddress() external view returns (address factoryAddress) {
        return address(factory);
    }

    /// @notice Get the vault contract address.
    /// @return vaultAddress The vault contract address.
    function getVaultAddress() external view returns (address vaultAddress) {
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

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
