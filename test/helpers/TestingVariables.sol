//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155InvalidReceiverHelper} from "./ERC1155InvalidReceiverHelper.sol";
import {AssetFactory} from "@contracts/AssetFactory.sol";
import {AssetVault} from "@contracts/AssetVault.sol";

/// @dev Helper contract that stores variables used across multiple test files.
contract TestingVariables {
    ///////////////////////////////////////////////
    /// Addresses                               ///
    ///////////////////////////////////////////////

    // Addresses used in tests
    address owner = address(9999);
    address approvedCaller = address(9998);
    address userA = address(1);
    address userB = address(2);
    address userC = address(3);

    ///////////////////////////////////////////////
    /// Contracts                               ///
    ///////////////////////////////////////////////

    // Create an instance of the AssetFactory contract that all tests will use
    AssetFactory factory = new AssetFactory(owner);
    // Create and instance of the AssetVault contract that all tests will use
    AssetVault vault = new AssetVault(address(factory), owner);
    // Create an instance of an invalid receiver contract using the ERC1155InvalidReceiverHelper (empty contract)
    ERC1155InvalidReceiverHelper invalidReceiver = new ERC1155InvalidReceiverHelper();

    /////////////////////////////////////////////////
    /// Constant Numerical Values                 ///
    /////////////////////////////////////////////////

    uint256 constant ONE_MILLION = 1000000;
    uint256 constant ONE_ETHER = 1 ether;
    uint256 constant ONE_HOUR_IN_BLOCKS = 300;

    ////////////////////////////////////////////////
    /// Asset Data                               ///
    ////////////////////////////////////////////////

    // Asset IDs
    uint256 constant IGC_TOKEN_ID = 0;
    uint256 constant ASSET_ONE_ID = 1;
    uint256 constant ASSET_TWO_ID = 2;
    uint256 constant ASSET_THREE_ID = 3;

    // Asset prices
    uint256 constant ASSET_ONE_PRICE = 100;
    uint256 constant ASSET_TWO_PRICE = 200;
    uint256 constant ASSET_THREE_PRICE = 300;

    /////////////////////////////////////////////////
    /// Stored Asset Arrays                       ///
    /////////////////////////////////////////////////

    // Used to pass in an array of all the asset IDs to functions requiring an array of asset IDs
    uint256[] assetIds = [ASSET_ONE_ID, ASSET_TWO_ID, ASSET_THREE_ID];

    // Used to pass in a single asset to functions requiring an array of asset IDs
    uint256[] asset1Single = [ASSET_ONE_ID];
    uint256[] asset2Single = [ASSET_TWO_ID];
    uint256[] asset3Single = [ASSET_THREE_ID];
    uint256[] amountSingle = [1];

    // Used to pass in various amounts of assets to functions requiring an array of asset IDs
    uint256[] asset1 = [10, 0, 0];
    uint256[] asset2 = [0, 10, 0];
    uint256[] asset3 = [0, 0, 10];
    uint256[] all = [10, 10, 10];
    uint256[] allVarying = [1, 5, 10];

    // Used to pass in an invalid array length to test revert statements
    uint256[] invalid = [1, 5];

    ////////////////////////////////////////////////
    /// User Starting Factory Balances         ///
    ////////////////////////////////////////////////

    // Initialize storage variables for users' Factory balances
    uint256 userAStartingFactoryIGCBalance;
    uint256 userAStartingFactoryAssetOneBalance;
    uint256 userAStartingFactoryAssetTwoBalance;
    uint256 userAStartingFactoryAssetThreeBalance;

    uint256 userBStartingFactoryIGCBalance;
    uint256 userBStartingFactoryAssetOneBalance;
    uint256 userBStartingFactoryAssetTwoBalance;
    uint256 userBStartingFactoryAssetThreeBalance;

    uint256 userCStartingFactoryIGCBalance;
    uint256 userCStartingFactoryAssetOneBalance;
    uint256 userCStartingFactoryAssetTwoBalance;
    uint256 userCStartingFactoryAssetThreeBalance;

    ////////////////////////////////////////////////
    /// User Starting Vault Balances             ///
    ////////////////////////////////////////////////

    // Initialize storage variables for users' Vault balances
    uint256 userAStartingVaultIGCBalance;
    uint256 userAStartingVaultAssetOneBalance;
    uint256 userAStartingVaultAssetTwoBalance;
    uint256 userAStartingVaultAssetThreeBalance;

    uint256 userBStartingVaultIGCBalance;
    uint256 userBStartingVaultAssetOneBalance;
    uint256 userBStartingVaultAssetTwoBalance;
    uint256 userBStartingVaultAssetThreeBalance;

    uint256 userCStartingVaultIGCBalance;
    uint256 userCStartingVaultAssetOneBalance;
    uint256 userCStartingVaultAssetTwoBalance;
    uint256 userCStartingVaultAssetThreeBalance;
}
