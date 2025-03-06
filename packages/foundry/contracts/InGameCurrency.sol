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
}
