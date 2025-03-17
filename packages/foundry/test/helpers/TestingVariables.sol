//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// renamed contract and variables for clarity - removed unnecessary variables - updated comments

import { ERC1155InvalidReceiverHelper } from "./ERC1155InvalidReceiverHelper.sol";
import { AssetFactory } from "@contracts/AssetFactory.sol";
import { AssetVault } from "@contracts/AssetVault.sol";

contract TestingVariables {
    // Addresses used for testing
    address owner = address(9999);
    address userA = address(1);
    address userB = address(2);
    address userC = address(3);

    // Create an instance of the AssetFactory contract that all tests will use
    AssetFactory factory = new AssetFactory(owner);
    // Create and instance of the AssetVault contract that all tests will use
    AssetVault vault = new AssetVault(address(factory));
    // Create an instance of an invalid receiver contract using the ERC1155InvalidReceiverHelper (empty contract)
    ERC1155InvalidReceiverHelper invalidReceiver = new ERC1155InvalidReceiverHelper();

    // Asset IDs
    uint256 constant IGC_TOKEN_ID = 0;
    uint256 constant ASSET_ONE_ID = 1;
    uint256 constant ASSET_TWO_ID = 2;
    uint256 constant ASSET_THREE_ID = 3;

    // Asset prices
    uint256 constant ASSET_ONE_PRICE = 100;
    uint256 constant ASSET_TWO_PRICE = 200;
    uint256 constant ASSET_THREE_PRICE = 300;

    // Constants used for testing
    uint256 constant ONE_MILLION = 1000000;
    uint256 constant ONE_ETHER = 1 ether;
    uint256 constant ONE_HOUR = 3600;

    // Used to pass in asset IDs to functions requiring an array of asset IDs
    uint256[] assetIds = [ASSET_ONE_ID, ASSET_TWO_ID, ASSET_THREE_ID];

    // Used to pass in asset amounts to functions requiring an array of asset mint amounts
    uint256[] asset1 = [10, 0, 0];
    uint256[] asset2 = [0, 10, 0];
    uint256[] asset3 = [0, 0, 10];
    uint256[] all = [10, 10, 10];
    uint256[] allVarying = [1, 5, 10];
    uint256[] invalid = [1, 5];

    // Set up single asset arrays for testing
    // depositAssets() and withdrawAssets() require arrays as arguments
    uint256[] asset1Single = [ASSET_ONE_ID];
    uint256[] asset2Single = [ASSET_TWO_ID];
    uint256[] amountSingle = [1];
}
