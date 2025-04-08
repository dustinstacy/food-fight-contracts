// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/AssetRental.sol";

contract DeployAssetRental is ScaffoldETHDeploy {
    function run(address vault) external ScaffoldEthDeployerRunner {
        new AssetRental(vault);
    }
}
