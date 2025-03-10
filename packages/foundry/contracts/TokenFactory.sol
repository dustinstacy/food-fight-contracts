//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Remove when deploying to a live network.
import "forge-std/console.sol";

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenFactory
/// @notice This contract is a factory for creating ERC1155 tokens.
contract TokenFactory is ERC1155, Ownable {
    ///////////////////////////////////////////////////////////
    ///                      ERRORS                         ///
    ///////////////////////////////////////////////////////////

    /// Emitted when an owner tries to withdraw more funds than the contract balance.
    error TokenFactoryWithdrawalExceedsBalance(uint256 amount, uint256 balance);

    /// Emitted when an owner tries to withdraw funds from the contract and the transfer fails.
    error TokenFactoryWithdrawalFailed(address to, uint256 amount);

    ///////////////////////////////////////////////////////////
    ///                     EVENTS                          ///
    ///////////////////////////////////////////////////////////

    /// Emitted when the URI of the metadata for a token is set.
    event URISet(string uri, uint256 id);

    /// Emitted when the price of a token is set.
    event TokenPriceSet(uint256 id, uint256 price);

    /// Emitted when the custom ERC20 token used for payments is set.
    event PaymentTokenSet(address paymentToken);

    /// Emitted when an owner withdraws funds from the contract.
    event Withdrawal(address indexed to, uint256 amount);

    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    /// Mapping of the token ID to the URI of the metadata.
    mapping(uint256 tokenID => string uri) private tokenURIs;

    /// Mapping of the token ID to the price of the token.
    mapping(uint256 tokenID => uint256 price) private tokenPrices;

    /// Custom ERC20 token to use for payments.
    IERC20 private paymentToken;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Initializes the contract with the provided owner.
    /// @param _owner The address that will be set as the owner of the contract.
    /// @param _paymentToken The address of the custom ERC20 token to use for payments.
    /// @dev The ERC1155 constructor is an empty string as we will be using a URI mapping instead of ID substitution.
    constructor(address _owner, address _paymentToken) ERC1155("") Ownable(_owner) {
        paymentToken = IERC20(_paymentToken);
    }

    ///////////////////////////////////////////////////////////
    ///                    CORE FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mints a given amount of a token.
    /// @param account Address to mint the token to.
    /// @param id ID of the token to mint.
    /// @param amount Amount of the token to mint.
    /// @param data Custom data to pass to the receiver on the mint.
    /// @dev Simple placehold pricing model. Needs to be updated.
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external {
        uint256 price = tokenPrices[id];
        uint256 totalPrice = price * amount;

        //!! Approval needed from ERC20 contract
        paymentToken.transferFrom(_msgSender(), address(this), totalPrice);

        _mint(account, id, amount, data);
    }

    /// @notice Mints given amounts of multiple tokens.
    /// @param to Address to mint the tokens to.
    /// @param ids IDs of the tokens to mint.
    /// @param amounts Amounts of the tokens to mint.
    /// @param data Custom data to pass to the receiver on the mint.
    /// @dev The IDs and amounts arrays must be the same length.
    /// @dev Simple placehold pricing model. Needs to be updated.
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external {
        if (ids.length != amounts.length) {
            revert ERC1155InvalidArrayLength(ids.length, amounts.length);
        }

        uint256 totalPrice;

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 price = tokenPrices[id];

            totalPrice += price * amount;
        }

        //!! Approval needed from ERC20 contract
        paymentToken.transferFrom(_msgSender(), address(this), totalPrice);

        _mintBatch(to, ids, amounts, data);
    }

    /// @notice Burns a given amount of a token.
    /// @param account Address to burn the token from.
    /// @param id ID of the token to burn.
    /// @param amount Amount of the token to burn.
    /// @dev Need to implement balance checking.
    function burn(address account, uint256 id, uint256 amount) external {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }

        uint256 balance = balanceOf(account, id);

        if (balance < amount) {
            revert ERC1155InsufficientBalance(account, balance, amount, id);
        }

        _burn(account, id, amount);
    }

    /// @notice Burns given amounts of multiple tokens.
    /// @param account Address to burn the tokens from.
    /// @param ids IDs of the tokens to burn.
    /// @param amounts Amounts of the tokens to burn.
    function burnBatch(address account, uint256[] memory ids, uint256[] memory amounts) external {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
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
    }

    ///////////////////////////////////////////////////////////
    ///                    OWNER FUNCTIONS                  ///
    ///////////////////////////////////////////////////////////

    /// @notice Sets the URI of the metadata for a given token ID.
    /// @param id ID of the token to set the URI for.
    /// @param uri URI of the metadata for the token.
    function setTokenURI(uint256 id, string memory uri) external onlyOwner {
        tokenURIs[id] = uri;

        emit URISet(uri, id);
    }

    /// @notice Sets the price of a given token.
    /// @param id ID of the token to set the price for.
    /// @param price Price of the token.
    function setTokenPrice(uint256 id, uint256 price) external onlyOwner {
        tokenPrices[id] = price;

        emit TokenPriceSet(id, price);
    }

    /// @notice Sets the custom ERC20 token to use for payments.
    /// @param _paymentToken The address of the custom ERC20 token to use for payments.
    function setPaymentToken(address _paymentToken) external onlyOwner {
        paymentToken = IERC20(_paymentToken);

        emit PaymentTokenSet(_paymentToken);
    }

    /// @notice Withdraws the balance of the contract to the owner.
    /// @param to The address to send the funds to.
    /// @param amount The amount of funds to send.
    function withdraw(address to, uint256 amount) external onlyOwner {
        // If no address is provided, send the funds to the owner.
        if (to == address(0)) {
            to = owner();
        }

        uint256 balance = address(this).balance;

        if (amount > balance) {
            revert TokenFactoryWithdrawalExceedsBalance(amount, balance);
        }

        (bool success,) = to.call{ value: amount }("");
        if (!success) {
            revert TokenFactoryWithdrawalFailed(to, amount);
        }

        emit Withdrawal(to, amount);
    }

    ///////////////////////////////////////////////////////////
    ///                    VIEW FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Gets the URI of the metadata for a given token ID.
    /// @param id ID of the token to get the URI for.
    /// @return The URI of the metadata for the token.
    function getTokenURI(uint256 id) public view returns (string memory) {
        return tokenURIs[id];
    }

    /// @notice Gets the price of a given token.
    /// @param id ID of the token to get the price for.
    /// @return The price of the token.
    function getTokenPrice(uint256 id) public view returns (uint256) {
        return tokenPrices[id];
    }

    /// @notice Gets the custom ERC20 token used for payments.
    /// @return The address of the custom ERC20 token used for payments.
    function getPaymentToken() public view returns (address) {
        return address(paymentToken);
    }
}
