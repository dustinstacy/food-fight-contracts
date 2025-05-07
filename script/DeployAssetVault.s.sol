// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/AssetVault.sol";

contract DeployAssetVault is ScaffoldETHDeploy {
    function run(address factory) external ScaffoldEthDeployerRunner returns (AssetVault deployedVault) {
        deployedVault = new AssetVault(factory, deployer);
    }
}
