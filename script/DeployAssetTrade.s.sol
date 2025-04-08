// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/AssetTrade.sol";

contract DeployAssetTrade is ScaffoldETHDeploy {
    function run(address vault) external ScaffoldEthDeployerRunner {
        new AssetTrade(vault);
    }
}
