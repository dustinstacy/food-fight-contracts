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
    ///                      ERRORS                         ///
    ///////////////////////////////////////////////////////////

    /// Emitted when an owner tries to withdraw funds from the contract and the transfer fails.
    error InGameCurrencyWithdrawalFailed(address to, uint256 amount);

    ///////////////////////////////////////////////////////////
    ///                     VARIABLES                       ///
    ///////////////////////////////////////////////////////////

    /// @notice The price of the token.
    uint256 public price;

    /// @notice The number of decimals for the token.
    uint256 constant WAD = 10 ** 18;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Initializes the contract with the provided owner.
    /// @param _initialOwner The address that will be set as the owner of the contract.
    constructor(address _initialOwner, uint256 _initialPrice) ERC20("InGameCurrency", "IGC") Ownable(_initialOwner) {
        price = _initialPrice;
    }

    ///////////////////////////////////////////////////////////
    ///                    CORE FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mints the specified amount of tokens to the provided address.
    /// @param to The address that will receive the minted tokens.
    /// @dev Simple placeholder pricing model. Needs to be updated.
    function mint(address to) external payable {
        //!! This is a placeholder pricing model. Update to a more complex model.
        uint256 scaledAmount = msg.value * WAD / price;
        uint256 amount = scaledAmount / WAD;

        _mint(to, amount);
    }

    ///////////////////////////////////////////////////////////
    ///                    OWNER FUNCTIONS                  ///
    ///////////////////////////////////////////////////////////

    /// @notice Withdraws the balance of the contract to the owner.
    /// @dev Update to allow withdrawal to a different address.
    /// @dev Update to allow withdrawal of a specific amount.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success,) = owner().call{ value: balance }("");
        if (!success) {
            revert InGameCurrencyWithdrawalFailed(owner(), balance);
        }
    }
}
