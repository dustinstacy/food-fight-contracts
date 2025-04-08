// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/AssetAuction.sol";

contract DeployAssetAuction is ScaffoldETHDeploy {
    function run(address vault) external ScaffoldEthDeployerRunner {
        new AssetAuction(vault);
    }
}
