//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Remove when deploying to a live network.
import "forge-std/console.sol";

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title NFTFactory
/// @notice This contract is a factory for creating ERC1155 tokens.
contract NFTFactory is ERC1155, Ownable {
    ///////////////////////////////////////////////////////////
    ///                      ERRORS                         ///
    ///////////////////////////////////////////////////////////

    /// Emitted when an owner tries to withdraw funds from the contract and the transfer fails.
    error NFTFactoryWithdrawalFailed(address to, uint256 amount);

    ///////////////////////////////////////////////////////////
    ///                     VARIABLES                       ///
    ///////////////////////////////////////////////////////////

    /// Mapping of the token ID to the URI of the metadata.
    mapping(uint256 tokenID => string uri) private _tokenURIs;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Initializes the contract with the provided owner.
    /// @param initialOwner The address that will be set as the owner of the contract.
    /// @dev The ERC1155 constructor is an empty string as we will be using a URI mapping instead of ID substitution.
    constructor(address initialOwner) ERC1155("") Ownable(initialOwner) { }

    ///////////////////////////////////////////////////////////
    ///                    CORE FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mints a given amount of a token.
    /// @param account Address to mint the token to.
    /// @param id ID of the token to mint.
    /// @param amount Amount of the token to mint.
    /// @param data Custom data to pass to the receiver on the mint.
    /// @dev Need to implement pricing and payment logic.
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external payable {
        // Get the price of the token.
        // Check if the msg.value is equal to the price of the token.
        // If not, revert with an error.
        // If the price is correct, mint the token.
        _mint(account, id, amount, data);
    }

    /// @notice Mints given amounts of multiple tokens.
    /// @param to Address to mint the tokens to.
    /// @param ids IDs of the tokens to mint.
    /// @param amounts Amounts of the tokens to mint.
    /// @param data Custom data to pass to the receiver on the mint.
    /// @dev The IDs and amounts arrays must be the same length.
    /// @dev Need to implement pricing and payment logic.
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        external
        payable
    {
        // Get the price of the tokens.
        // Check if the msg.value is equal to the price of the tokens.
        // If not, revert with an error.
        // If the price is correct, mint the tokens.
        _mintBatch(to, ids, amounts, data);
    }

    /// @notice Burns a given amount of a token.
    /// @param account Address to burn the token from.
    /// @param id ID of the token to burn.
    /// @param value Amount of the token to burn.
    /// @dev Need to implement balance checking.
    function burn(address account, uint256 id, uint256 value) external {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }

        // Check if the account has enough balance to burn the token.
        // If not, revert with an error.
        // If the account has enough balance, burn the token.
        _burn(account, id, value);
    }

    /// @notice Burns given amounts of multiple tokens.
    /// @param account Address to burn the tokens from.
    /// @param ids IDs of the tokens to burn.
    /// @param values Amounts of the tokens to burn.
    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) external {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }

        // Check if the account has enough balance to burn the tokens.
        // If not, revert with an error.
        // If the account has enough balance, burn the tokens.
        _burnBatch(account, ids, values);
    }

    ///////////////////////////////////////////////////////////
    ///                    OWNER FUNCTIONS                  ///
    ///////////////////////////////////////////////////////////

    /// @notice Sets the URI of the metadata for a given token ID.
    /// @param id ID of the token to set the URI for.
    /// @param uri URI of the metadata for the token.
    function setTokenURI(uint256 id, string memory uri) external onlyOwner {
        _tokenURIs[id] = uri;
    }

    /// @notice Withdraws the balance of the contract to the owner.
    /// @dev Update to allow withdrawal to a different address.
    /// @dev Update to allow withdrawal of a specific amount.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success,) = owner().call{ value: balance }("");
        if (!success) {
            revert NFTFactoryWithdrawalFailed(owner(), balance);
        }
    }
}
