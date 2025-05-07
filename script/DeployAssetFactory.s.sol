// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/AssetFactory.sol";

/**
 * @notice Deploy script for AssetFactory contract
 * @dev Inherits ScaffoldETHDeploy which:
 *      - Includes forge-std/Script.sol for deployment
 *      - Includes ScaffoldEthDeployerRunner modifier
 *      - Provides `deployer` variable
 * Example:
 * npm run deploy --file DeployAssetFactory.s.sol  # local anvil chain
 * npm run deploy --file DeployAssetFactory.s.sol --network optimism # live network (requires keystore)
 */
contract DeployAssetFactory is ScaffoldETHDeploy {
    function run() external ScaffoldEthDeployerRunner returns (AssetFactory deployedFactory) {
        deployedFactory = new AssetFactory(deployer);
    }
}
