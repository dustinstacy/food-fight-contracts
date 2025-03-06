//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Remove when deploying to a live network.
import "forge-std/console.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title InGameCurrency
/// @notice This contract is an ERC20 token for in-game currency.
contract InGameCurrency is ERC20, Ownable {
    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Initializes the contract with the provided owner.
    /// @param initialOwner The address that will be set as the owner of the contract.
    constructor(address initialOwner) ERC20("InGameCurrency", "IGC") Ownable(initialOwner) { }

    ///////////////////////////////////////////////////////////
    ///                    CORE FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mints the specified amount of tokens to the provided address.
    /// @param to The address that will receive the minted tokens.
    /// @param amount The amount of tokens to mint.
    /// @dev Need to implement pricing and payment logic.
    function mint(address to, uint256 amount) external payable {
        // Get the price of the token.
        // Check if the msg.value is equal to the price of the token.
        // If not, revert with an error.
        // If the price is correct, mint the token.
        _mint(to, amount);
    }

    /// @notice Burns the specified amount of tokens from the caller's balance.
    /// @param value The amount of tokens to burn.
    /// @dev Need to implement balance checking.
    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }
}
