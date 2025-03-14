//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AssetFactory } from "@contracts/AssetFactory.sol";
import { ERC1155InvalidReceiverHelper } from "./ERC1155InvalidReceiverHelper.sol";

contract Constants {
    // Create an instance of the AssetFactory contract that all tests will use
    AssetFactory factory = new AssetFactory(address(owner));
    // Create an instance of an invalid receiver contract using the ERC1155InvalidReceiverHelper (empty contract)
    ERC1155InvalidReceiverHelper invalidReceiver = new ERC1155InvalidReceiverHelper();

    address constant owner = address(101010101010101010101010101010101010101);
    address constant user1 = address(1);
    address constant user2 = address(2);
    address constant user3 = address(3);

    uint256 constant IGC_TOKEN_ID = 0;
    uint256 constant ASSET_ONE_ID = 1;
    uint256 constant ASSET_TWO_ID = 2;
    uint256 constant ASSET_THREE_ID = 3;

    uint256 constant ASSET_ONE_PRICE = 100;
    uint256 constant ASSET_TWO_PRICE = 200;
    uint256 constant ASSET_THREE_PRICE = 300;

    uint256 constant ONE = 1;
    uint256 constant FIVE = 5;
    uint256 constant TEN = 10;
    uint256 constant ONE_THOUSAND = 1000;
    uint256 constant ONE_MILLION = 1000000;
    uint256 constant ONE_ETHER = 1 ether;
    uint256 constant ONE_HOUR = 3600;

    // Used to pass in asset IDs to functions requiring an array of asset IDs
    uint256[] assetIds = [ASSET_ONE_ID, ASSET_TWO_ID, ASSET_THREE_ID];

    // Used to pass in asset amounts to functions requiring an array of asset mint amounts
    uint256[] asset1 = [TEN, 0, 0];
    uint256[] asset2 = [0, TEN, 0];
    uint256[] asset3 = [0, 0, TEN];
    uint256[] all = [TEN, TEN, TEN];
    uint256[] allVarying = [ONE, FIVE, TEN];
    uint256[] invalid = [ONE, FIVE];

    // Set up single asset arrays for testing
    // depositAssets() and withdrawAssets() require arrays as arguments
    //!! Consider creating a library of helper functions that repeat the same code
    uint256[] asset1Single = [ASSET_ONE_ID];
    uint256[] asset2Single = [ASSET_TWO_ID];
    uint256[] amountSingle = [ONE];
}
