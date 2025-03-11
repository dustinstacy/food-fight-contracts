//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @title AssetRental
/// @notice A contract that allows users to put their assets up for rent and allows other users to rent them.
contract AssetRental {
    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    IERC1155 private assetsContract;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @param _assetsContractAddress The address of the ERC1155 contract.
    constructor(address _assetsContractAddress) {
        assetsContract = IERC1155(_assetsContractAddress);
    }
}
