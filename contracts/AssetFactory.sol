//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AssetFactory
/// @notice This is a factory contract for creating ERC1155 assets.
/// @notice It will handle minting the IGC (in game currency) and the game assets.
contract AssetFactory is ERC1155, IERC1155Receiver, Ownable, ReentrancyGuard {
    ///////////////////////////////////////////////////////////
    ///                  TYPE DECLARATIONS                  ///
    ///////////////////////////////////////////////////////////

    /// @notice The data structure for an asset.
    struct Asset {
        string uri;
        uint256 price;
    }

    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mapping of the asset ID to the asset data.
    mapping(uint256 assetID => Asset) private assets;

    /// @notice The current number of unique assets not including the IGC token.
    uint256 private uniqueAssets;

    /// @notice The token ID of the IGC token.
    uint8 private constant IGC_TOKEN_ID = 0;

    ///////////////////////////////////////////////////////////
    ///                     EVENTS                          ///
    ///////////////////////////////////////////////////////////

    /// @notice Emitted when the URI and price of an asset are set.
    event AssetDataSet(string uri, uint256 assetId, uint256 price);

    /// @notice Emitted when the IGC is burnt.
    event AssetMinted(address indexed account, uint256 assetId, uint256 amount);

    /// @notice Emitted when multiple assets are burnt
    event BurntBatch(address indexed account, uint256[] assetIds, uint256[] amounts);

    /// @notice Emitted when a single asset is burnt
    event BurntSingle(address indexed account, uint256 assetId, uint256 amount);

    /// @notice Emitted when the IGC is minted.
    event IGCminted(address indexed account, uint256 amount);

    ///////////////////////////////////////////////////////////
    ///                      ERRORS                         ///
    ///////////////////////////////////////////////////////////

    /// @notice Emitted when the asset ID is not found.
    error AssetFactoryAssetNotFound(uint256 assetId);

    ///////////////////////////////////////////////////////////
    ///                    CONSTRUCTOR                      ///
    ///////////////////////////////////////////////////////////

    /// @notice Construct the AssetFactory contract.
    /// @param _initialOwner The address that will be set as the owner of the contract.
    /// @dev The ERC1155 constructor is an empty string as we will be using a URI mapping instead of ID substitution.
    constructor(address _initialOwner) ERC1155("") Ownable(_initialOwner) {}

    ///////////////////////////////////////////////////////////
    ///                    MINT FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mints a given amount of IGC.
    /// @dev Simple placeholder pricing model. Needs to be updated.
    /// @param account Address to mint the IGC to.
    /// @param amount Amount of IGC to mint.
    function mintIGC(address account, uint256 amount) external payable {
        _mint(account, 0, amount, "");

        emit IGCminted(account, amount);
    }

    /// @notice Mints a given amount of an asset.
    /// @dev Simple placeholder pricing model. Needs to be updated.
    /// @param account Address to mint the asset to.
    /// @param assetId ID of the asset to mint.
    /// @param amount Amount of the asset to mint.
    /// @param data Custom data to pass to the receiver on the mint.
    function mintAsset(
        address account,
        uint256 assetId,
        uint256 amount,
        bytes memory data
    ) external nonReentrant {
        uint256 price = assets[assetId].price;
        uint256 totalPrice = price * amount;

        safeTransferFrom(_msgSender(), address(this), IGC_TOKEN_ID, totalPrice, "");

        _mint(account, assetId, amount, data);

        emit AssetMinted(account, assetId, amount);
    }

    /// @notice Mints given amounts of multiple assets.
    /// @dev Simple placeholder pricing model. Needs to be updated.
    /// @param to Address to mint the assets to.
    /// @param assetIds IDs of the assets to mint.
    /// @param amounts Amounts of the assets to mint.
    function mintBatch(
        address to,
        uint256[] memory assetIds,
        uint256[] memory amounts,
        bytes memory data
    ) external nonReentrant {
        // Precedes the array length check in _update() (nested inside _mintBatch()) to prevent reverts in the for loop.
        if (assetIds.length != amounts.length) {
            revert ERC1155InvalidArrayLength(assetIds.length, amounts.length);
        }

        uint256 totalPrice = 0;

        for (uint256 i = 0; i < assetIds.length; i++) {
            uint256 assetId = assetIds[i];
            uint256 amount = amounts[i];
            uint256 price = assets[assetId].price;

            totalPrice += price * amount;
        }

        safeTransferFrom(_msgSender(), address(this), IGC_TOKEN_ID, totalPrice, "");

        _mintBatch(to, assetIds, amounts, data);
    }

    ///////////////////////////////////////////////////////////
    ///                    BURN FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Burns a given amount of an asset.
    /// @param account Address to burn the asset from.
    /// @param assetId ID of the asset to burn.
    /// @param amount Amount of the asset to burn.
    function burnAsset(address account, uint256 assetId, uint256 amount) external {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }

        uint256 balance = balanceOf(account, assetId);

        if (balance < amount) {
            revert ERC1155InsufficientBalance(account, balance, amount, assetId);
        }

        _burn(account, assetId, amount);

        emit BurntSingle(account, assetId, amount);
    }

    /// @notice Burns given amounts of multiple assets.
    /// @param account Address to burn the assets from.
    /// @param assetIds IDs of the assets to burn.
    /// @param amounts Amounts of the assets to burn.
    function burnBatch(
        address account,
        uint256[] memory assetIds,
        uint256[] memory amounts
    ) external {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }

        // Precedes the array length check in _update() (nested inside _burnBatch()) to prevent reverts in the for loop.
        if (assetIds.length != amounts.length) {
            revert ERC1155InvalidArrayLength(assetIds.length, amounts.length);
        }

        for (uint256 i = 0; i < assetIds.length; i++) {
            uint256 assetId = assetIds[i];
            uint256 amount = amounts[i];
            uint256 balance = balanceOf(account, assetId);

            if (balance < amount) {
                revert ERC1155InsufficientBalance(account, balance, amount, assetId);
            }
        }

        _burnBatch(account, assetIds, amounts);

        emit BurntBatch(account, assetIds, amounts);
    }

    ///////////////////////////////////////////////////////////
    ///                    OWNER FUNCTIONS                  ///
    ///////////////////////////////////////////////////////////

    /// @notice Sets the URI of the metadata and the price for a given asset ID.
    /// @param assetUri URI of the metadata for the asset.
    /// @param assetPrice Price of the asset.
    function setAssetData(string memory assetUri, uint256 assetPrice) external onlyOwner {
        uniqueAssets++;

        assets[uniqueAssets].uri = assetUri;
        assets[uniqueAssets].price = assetPrice;

        emit AssetDataSet(assetUri, uniqueAssets, assetPrice);
    }

    function updateAssetData(
        uint256 assetId,
        string memory assetUri,
        uint256 assetPrice
    ) external onlyOwner {
        if (bytes(assets[assetId].uri).length == 0) {
            revert AssetFactoryAssetNotFound(assetId);
        }

        assets[assetId].uri = assetUri;
        assets[assetId].price = assetPrice;

        emit AssetDataSet(assetUri, assetId, assetPrice);
    }

    ///////////////////////////////////////////////////////////
    ///                    VIEW FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Gets the URI and price of a given asset.
    /// @param assetId ID of the asset to get the URI and price for.
    /// @return asset The asset data containing the URI and price.
    function getAsset(uint256 assetId) public view returns (Asset memory asset) {
        return assets[assetId];
    }

    /// @notice Gets the newest asset ID to be minted.
    /// @return assetId The newest asset ID to be minted.
    function getNextAssetId() public view returns (uint256 assetId) {
        return uniqueAssets + 1;
    }

    /// @notice Gets the IGC token ID.
    /// @return tokenId The IGC token ID.
    function getIGCTokenId() public pure returns (uint8 tokenId) {
        return IGC_TOKEN_ID;
    }

    /////////////////////////////////////////////////////////////
    ///               ERC1155 RECEIVER FUNCTIONS              ///
    /////////////////////////////////////////////////////////////

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*id*/,
        uint256 /*value*/,
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155BatchReceived(
        address /*operator*/,
        address /*from*/,
        uint256[] memory /*ids*/,
        uint256[] memory /*values*/,
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return
            bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }
}
