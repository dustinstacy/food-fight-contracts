//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import { DeployAssetFactory } from "./DeployAssetFactory.s.sol";
import { DeployAssetVault } from "./DeployAssetVault.s.sol";
import { DeployAssetTrade } from "./DeployAssetTrade.s.sol";
import { DeployAssetAuction } from "./DeployAssetAuction.s.sol";
import { DeployAssetRental } from "./DeployAssetRental.s.sol";
import { AssetFactory } from "../contracts/AssetFactory.sol";
import { AssetVault } from "../contracts/AssetVault.sol";

/**
 * @notice Main deployment script for all contracts
 * @dev Run this when you want to deploy multiple contracts at once
 *
 * Example: npm run deploy # runs this script(without`--file` flag)
 */
contract DeployScript is ScaffoldETHDeploy {
    function run() external {
        DeployAssetFactory deployAssetFactory = new DeployAssetFactory();
        AssetFactory deployedAssetFactory = deployAssetFactory.run();

        DeployAssetVault deployAssetVault = new DeployAssetVault();
        AssetVault deployedAssetVault = deployAssetVault.run(address(deployedAssetFactory));

        DeployAssetTrade deployAssetTrade = new DeployAssetTrade();
        deployAssetTrade.run(address(deployedAssetVault));

        DeployAssetAuction deployAssetAuction = new DeployAssetAuction();
        deployAssetAuction.run(address(deployedAssetVault));

        DeployAssetRental deployAssetRental = new DeployAssetRental();
        deployAssetRental.run(address(deployedAssetVault));
    }
}
