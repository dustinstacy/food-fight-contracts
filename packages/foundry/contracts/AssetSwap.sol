//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract AssetSwap {
    IERC1155 public assetsContract;

    /// @param _assetsContractAddress The address of the ERC1155 contract
    constructor(address _assetsContractAddress) {
        assetsContract = IERC1155(_assetsContractAddress);
    }
}
