//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// restructured to match Solidity style guide - updated events - implemented functions

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { AssetVault } from "./AssetVault.sol";

/// @title AssetRental
/// @notice This contract allows users to list assets for rent and rent assets from other users.
contract AssetRental is IERC1155Receiver {
    ///////////////////////////////////////////////////////////
    ///                   TYPE DECLARATIONS                 ///
    ///////////////////////////////////////////////////////////

    /// @notice The status of the rental asset.
    enum RentalStatus {
        Available,
        Rented,
        Unavailable
    }

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
    mapping(uint256 rentalAssetId => RentalAsset) private rentalAssets;

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
    ///                      EVENTS                         ///
    ///////////////////////////////////////////////////////////

    /// @notice Emitted when an asset is posted for rent.
    event RentalAssetPosted(address rentalOwner, uint256 rentalAssetId);

    /// @notice Emitted when an asset is relisted.
    event RentalAssetRelisted(address rentalOwner, uint256 rentalAssetId);

    /// @notice Emitted when an asset is unlisted.
    event RentalAssetUnlisted(address rentalOwner, uint256 rentalAssetId);

    /// @notice Emitted when an asset is updated.
    event RentalAssetUpdated(address rentalOwner, uint256 rentalAssetId);

    /// @notice Emitted when an asset is rented.
    event RentalAssetRented(address renter, uint256 rentalAssetId, uint256 timeRented);

    ///////////////////////////////////////////////////////////
    ///                     ERRORS                          ///
    ///////////////////////////////////////////////////////////

    /// @notice Thrown when the asset is not available for rent.
    error AssetRentalNotAvailable(RentalStatus status);

    /// @notice Thrown when the asset is already available for rent.
    error AssetRentalAlreadyAvailable(RentalStatus status);

    /// @notice Thrown when the asset is not expired.
    error AssetRentalNotExpired(uint256 expiration);

    /// @notice Thrown when the caller is not the owner of the asset.
    error AssetRentalNotTheOwner(address caller, address owner);

    /// @notice Thrown when the caller is not the renter of the asset.
    error AssetRentalNotTheRenter(address caller, address renter);

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
    ///                RENTAL OWNER FUNCTIONS               ///
    ///////////////////////////////////////////////////////////

    /// @notice Post an asset for rent.
    /// @param assetId The ID of the asset to rent.
    /// @param price The price to rent the asset.
    /// @param duration The duration of the rental.
    /// @dev Will throw an error if the user lacks the required balance of the asset to post for rent. (AssetVaultInsufficientBalance).
    function createRental(uint256 assetId, uint256 price, uint256 duration) external {
        rentalAssetCount++;
        rentalAssets[rentalAssetCount] = RentalAsset({
            owner: msg.sender,
            renter: address(0),
            assetId: assetId,
            price: price,
            duration: duration,
            expiration: 0,
            status: RentalStatus.Available
        });

        vault.lockAsset(msg.sender, assetId, 1);

        emit RentalAssetPosted(msg.sender, rentalAssetCount);
    }

    function unlistRental(uint256 rentalAssetId) external {
        RentalAsset storage rental = rentalAssets[rentalAssetId];

        _checkOwnerAndAvailability(msg.sender, rental);

        rental.status = RentalStatus.Unavailable;

        vault.unlockAsset(msg.sender, rental.assetId, 1);

        emit RentalAssetUnlisted(msg.sender, rentalAssetId);
    }

    function updateRental(uint256 rentalAssetId, uint256 price, uint256 duration) external {
        RentalAsset storage rental = rentalAssets[rentalAssetId];

        _checkOwnerAndAvailability(msg.sender, rental);

        rental.price = price;
        rental.duration = duration;

        emit RentalAssetUpdated(msg.sender, rentalAssetId);
    }

    ///////////////////////////////////////////////////////////
    ///                   RENTER FUNCTIONS                  ///
    ///////////////////////////////////////////////////////////

    function rentAsset(uint256 rentalAssetId) external {
        RentalAsset storage rental = rentalAssets[rentalAssetId];

        if (rental.status != RentalStatus.Available) {
            revert AssetRentalNotAvailable(rental.status);
        }

        vault.lockAsset(msg.sender, igcTokenId, rental.price);
        vault.unlockAsset(rental.owner, igcTokenId, rental.price);

        rental.status = RentalStatus.Rented;
        rental.renter = msg.sender;
        rental.expiration = block.timestamp + rental.duration;

        rentedAssets[msg.sender][rental.assetId]++;

        emit RentalAssetRented(msg.sender, rentalAssetId, block.timestamp);
    }

    function checkRentalStatus(uint256 rentalAssetId) external returns (bool) {
        RentalAsset storage rental = rentalAssets[rentalAssetId];

        if (block.timestamp >= rental.expiration) {
            rentedAssets[rental.renter][rental.assetId]--;

            rental.status = RentalStatus.Available;
            rental.renter = address(0);
            rental.expiration = 0;

            emit RentalAssetRelisted(rental.owner, rentalAssetId);

            return false;
        }

        return true;
    }

    ///////////////////////////////////////////////////////////
    ///                INTERNAL FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    function _checkOwnerAndAvailability(address user, RentalAsset storage rentalAsset) internal view {
        if (rentalAsset.status != RentalStatus.Available) {
            revert AssetRentalNotAvailable(rentalAsset.status);
        }

        if (rentalAsset.owner != user) {
            revert AssetRentalNotTheOwner(user, rentalAsset.owner);
        }
    }

    ///////////////////////////////////////////////////////////
    ///                  VIEW FUNCTIONS                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Get the rental asset details.
    /// @param rentalAssetId The ID of the rental asset.
    /// @return rentalAsset The rental asset details.
    function getRentalAsset(uint256 rentalAssetId) public view returns (RentalAsset memory rentalAsset) {
        return rentalAssets[rentalAssetId];
    }

    /// @notice Get the rented asset balance of a user.
    /// @param user The address of the user.
    /// @param assetId The ID of the asset.
    /// @return balance The rented asset balance of the user.
    function getRentedAssetBalance(address user, uint256 assetId) public view returns (uint256 balance) {
        return rentedAssets[user][assetId];
    }

    /// @notice Get the rental asset count.
    /// @return count The rental asset count.
    function getRentalAssetCount() public view returns (uint256 count) {
        return rentalAssetCount;
    }

    /// @notice Get the IGC token ID.
    /// @return assetId The IGC token ID.
    function getIGCTokenId() public view returns (uint8 assetId) {
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

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
