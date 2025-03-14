//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Constants } from "./Constants.sol";

///////////////////////////////////////////////////////////
///                      HELPERS                        ///
///////////////////////////////////////////////////////////

/// @dev Helper contract to setup assets for testing
contract AssetFactoryHelper is Constants, Test {
    // Set up assets for testing
    // Can update this function to set up more/different assets
    function setAssetsHelper() public {
        vm.startPrank(owner);
        factory.setAssetData(1, "ipfs://asset1", 100);
        factory.setAssetData(2, "ipfs://asset2", 200);
        factory.setAssetData(3, "ipfs://asset3", 300);
        vm.stopPrank();
    }

    // Mint initial IGC for testing
    function mintIGCHelper(address minter, uint256 amount) public {
        vm.prank(minter);
        factory.mintIGC(minter, amount);
    }

    // Mint initial assets for testing
    function mintAssetHelper(address minter, uint256[] memory amounts) public {
        vm.startPrank(minter);
        factory.mintAsset(minter, ASSET_ONE_ID, amounts[0], "");
        factory.mintAsset(minter, ASSET_TWO_ID, amounts[1], "");
        factory.mintAsset(minter, ASSET_THREE_ID, amounts[2], "");
        vm.stopPrank();
    }
}
