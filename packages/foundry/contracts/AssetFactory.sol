//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Remove when deploying to a live network.
import "forge-std/console.sol";

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title AssetFactory
/// @notice This is a factory contract for creating ERC1155 assets.
contract AssetFactory is ERC1155, IERC1155Receiver, Ownable {
    ///////////////////////////////////////////////////////////
    ///                     EVENTS                          ///
    ///////////////////////////////////////////////////////////

    /// Emitted when the URI of the metadata for a asset is set.
    event AssetURISet(string uri, uint256 id);

    /// Emitted when the price of a asset is set.
    event AssetPriceSet(uint256 id, uint256 price);

    /// Emitted when an assets URI and price are set.
    event AssetDataSet(string uri, uint256 id, uint256 price);

    /// Emitted when a asset is burnt.
    event BurntSingle(address indexed account, uint256 id, uint256 amount);

    /// Emitted when assets are burnt
    event BurntBatch(address indexed account, uint256[] ids, uint256[] amounts);

    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    /// Mapping of the asset ID to the URI of the metadata.
    mapping(uint256 assetID => string uri) private assetURIs;

    /// Mapping of the asset ID to the price of the asset.
    mapping(uint256 assetID => uint256 price) private assetPrices;

    /// ID of the IGC asset.
    uint256 private igcTokenId = 0;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Initializes the contract with the provided owner.
    /// @param _owner The address that will be set as the owner of the contract.
    /// @dev The ERC1155 constructor is an empty string as we will be using a URI mapping instead of ID substitution.
    constructor(address _owner) ERC1155("") Ownable(_owner) { }

    ///////////////////////////////////////////////////////////
    ///                    CORE FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mints a given amount of IGC.
    /// @param account Address to mint the IGC to.
    /// @param amount Amount of IGC to mint.
    //!! Simple placehold pricing model. Needs to be updated.
    function mintIGC(address account, uint256 amount) external payable {
        _mint(account, 0, amount, "");
    }

    /// @notice Mints a given amount of an asset.
    /// @param account Address to mint the asset to.
    /// @param id ID of the asset to mint.
    /// @param amount Amount of the asset to mint.
    /// @param data Custom data to pass to the receiver on the mint.
    //!! Simple placehold pricing model. Needs to be updated.
    function mintAsset(address account, uint256 id, uint256 amount, bytes memory data) external {
        uint256 price = assetPrices[id];
        uint256 totalPrice = price * amount;

        safeTransferFrom(_msgSender(), address(this), igcTokenId, totalPrice, "");

        _mint(account, id, amount, data);
    }

    /// @notice Mints given amounts of multiple assets.
    /// @param to Address to mint the assets to.
    /// @param ids IDs of the assets to mint.
    /// @param amounts Amounts of the assets to mint.
    //!! Simple placehold pricing model. Needs to be updated.
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external {
        // Precedes the array length check in _update() (nested inside _mintBatch()) to prevent reverts in the for loop.
        if (ids.length != amounts.length) {
            revert ERC1155InvalidArrayLength(ids.length, amounts.length);
        }

        uint256 totalPrice;

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 price = assetPrices[id];

            totalPrice += price * amount;
        }

        safeTransferFrom(_msgSender(), address(this), igcTokenId, totalPrice, "");

        _mintBatch(to, ids, amounts, data);
    }

    /// @notice Burns a given amount of a asset.
    /// @param account Address to burn the asset from.
    /// @param id ID of the asset to burn.
    /// @param amount Amount of the asset to burn.
    /// @dev Need to implement balance checking.
    function burnAsset(address account, uint256 id, uint256 amount) external {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }

        uint256 balance = balanceOf(account, id);

        if (balance < amount) {
            revert ERC1155InsufficientBalance(account, balance, amount, id);
        }

        _burn(account, id, amount);

        emit BurntSingle(account, id, amount);
    }

    /// @notice Burns given amounts of multiple assets.
    /// @param account Address to burn the assets from.
    /// @param ids IDs of the assets to burn.
    /// @param amounts Amounts of the assets to burn.
    function burnBatch(address account, uint256[] memory ids, uint256[] memory amounts) external {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }

        // Precedes the array length check in _update() (nested inside _burnBatch()) to prevent reverts in the for loop.
        if (ids.length != amounts.length) {
            revert ERC1155InvalidArrayLength(ids.length, amounts.length);
        }

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 balance = balanceOf(account, id);

            if (balance < amount) {
                revert ERC1155InsufficientBalance(account, balance, amount, id);
            }
        }

        _burnBatch(account, ids, amounts);

        emit BurntBatch(account, ids, amounts);
    }

    ///////////////////////////////////////////////////////////
    ///                    OWNER FUNCTIONS                  ///
    ///////////////////////////////////////////////////////////

    /// @notice Sets the URI of the metadata for a given asset ID.
    /// @param id ID of the asset to set the URI for.
    /// @param uri URI of the metadata for the asset.
    function setAssetURI(uint256 id, string memory uri) external onlyOwner {
        assetURIs[id] = uri;

        emit AssetURISet(uri, id);
    }

    /// @notice Sets the price of a given asset.
    /// @param id ID of the asset to set the price for.
    /// @param price Price of the asset.
    function setAssetPrice(uint256 id, uint256 price) external onlyOwner {
        assetPrices[id] = price;

        emit AssetPriceSet(id, price);
    }

    /// @notice Sets the URI of the metadata and the price for a given asset ID.
    /// @param id ID of the asset to set the URI and price for.
    /// @param uri URI of the metadata for the asset.
    /// @param price Price of the asset.
    function setAssetData(uint256 id, string memory uri, uint256 price) external onlyOwner {
        assetURIs[id] = uri;
        assetPrices[id] = price;

        emit AssetDataSet(uri, id, price);
    }

    ///////////////////////////////////////////////////////////
    ///                    VIEW FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Gets the URI of the metadata for a given asset ID.
    /// @param id ID of the asset to get the URI for.
    /// @return The URI of the metadata for the asset.
    function getAssetURI(uint256 id) public view returns (string memory) {
        return assetURIs[id];
    }

    /// @notice Gets the price of a given asset.
    /// @param id ID of the asset to get the price for.
    /// @return The price of the asset.
    function getAssetPrice(uint256 id) public view returns (uint256) {
        return assetPrices[id];
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
}
