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
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Initializes the contract with the provided owner.
    /// @param initialOwner The address that will be set as the owner of the contract.
    /// @dev The ERC1155 constructor is an empty string as we will be using a URI mapping instead of ID substitution.
    constructor(address initialOwner) ERC1155("") Ownable(initialOwner) { }
}
