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

    /// Emitted when an owner tries to withdraw more funds than the contract balance.
    error InGameCurrencyWithdrawalExceedsBalance(uint256 amount, uint256 balance);

    /// Emitted when an owner tries to withdraw funds from the contract and the transfer fails.
    error InGameCurrencyWithdrawalFailed(address to, uint256 amount);

    ///////////////////////////////////////////////////////////
    ///                     EVENTS                          ///
    ///////////////////////////////////////////////////////////

    /// Emitted when an owner withdraws funds from the contract.
    event Withdrawal(address indexed to, uint256 amount);

    ///////////////////////////////////////////////////////////
    ///                     VARIABLES                       ///
    ///////////////////////////////////////////////////////////

    /// @notice The price of the token.
    uint256 private price;

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

    /// @notice Sets the price of the token.
    /// @param _price The new price of the token.
    function setPrice(uint256 _price) external onlyOwner {
        price = _price;
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
            revert InGameCurrencyWithdrawalExceedsBalance(amount, balance);
        }

        (bool success,) = to.call{ value: amount }("");
        if (!success) {
            revert InGameCurrencyWithdrawalFailed(to, amount);
        }

        emit Withdrawal(to, amount);
    }

    ///////////////////////////////////////////////////////////
    ///                    VIEW FUNCTIONS                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Gets the price of the token.
    /// @return The price of the token.
    function getPrice() external view returns (uint256) {
        return price;
    }
}
