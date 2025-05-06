//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import {DeployAssetFactory} from "./DeployAssetFactory.s.sol";
import {DeployAssetVault} from "./DeployAssetVault.s.sol";
import {DeployAssetTrade} from "./DeployAssetTrade.s.sol";
import {DeployAssetAuction} from "./DeployAssetAuction.s.sol";
import {DeployAssetRental} from "./DeployAssetRental.s.sol";

/**
 * @notice Main deployment script for all contracts
 * @dev Run this when you want to deploy multiple contracts at once
 *
 * Example: npm run deploy # runs this script(without`--file` flag)
 */
contract DeployScript is ScaffoldETHDeploy {
    function run() external {
        DeployAssetFactory deployAssetFactory = new DeployAssetFactory();
        deployAssetFactory.run();

        DeployAssetVault deployAssetVault = new DeployAssetVault();
        deployAssetVault.run(address(deployAssetFactory));

        DeployAssetTrade deployAssetTrade = new DeployAssetTrade();
        deployAssetTrade.run(address(deployAssetVault));

        DeployAssetAuction deployAssetAuction = new DeployAssetAuction();
        deployAssetAuction.run(address(deployAssetVault));

        DeployAssetRental deployAssetRental = new DeployAssetRental();
        deployAssetRental.run(address(deployAssetVault));
    }
}
