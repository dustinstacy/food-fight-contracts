//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { TestingVariables } from "./TestingVariables.sol";

/// @dev Helper contract for interacting with the AssetFactory contract.
/// @dev Is also repsonsible for extending the TestingVariables and Test contracts to all inheriting contracts.
contract AssetFactoryTestHelper is TestingVariables, Test {
    ////////////////////////////////////////////////
    /// Setter Functions                         ///
    ////////////////////////////////////////////////

    /// @dev Sets the asset data, mints IGC and assets for userA, and stores the starting balances for userA.
    function setInitialFactoryState() public {
        setAssetsTestHelper();
        mintIGCTestHelper(userA, ONE_MILLION);
        mintAssetTestHelper(userA, all);

        userAStartingFactoryIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        userAStartingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        userAStartingFactoryAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        userAStartingFactoryAssetThreeBalance = factory.balanceOf(userA, ASSET_THREE_ID);
    }

    /////////////////////////////////////////////////
    /// Contract Call Helpers                     ///
    /////////////////////////////////////////////////

    /// @dev Sets the asset data for the factory.
    //!! Modify to accept an array of asset data for custom asset data.
    function setAssetsTestHelper() public {
        vm.startPrank(owner);
        factory.setAssetData(1, "ipfs://asset1", 100);
        factory.setAssetData(2, "ipfs://asset2", 200);
        factory.setAssetData(3, "ipfs://asset3", 300);
        vm.stopPrank();
    }

    /// @dev Mints IGC for a user.
    /// @param minter The address of the user to mint IGC for.
    /// @param amount The amount of IGC to mint.
    function mintIGCTestHelper(address minter, uint256 amount) public {
        vm.prank(minter);
        factory.mintIGC(minter, amount);
    }

    /// @dev Mints assets for a user. Currently using static arrays found in TestingVariables.sol for amounts.
    /// @param minter The address of the user to mint assets for.
    /// @param amounts The amounts of each asset to mint.
    //!! Modify to accept an array of assetIds and an array of amounts for batch minting.
    function mintAssetTestHelper(address minter, uint256[] memory amounts) public {
        vm.startPrank(minter);
        factory.mintAsset(minter, ASSET_ONE_ID, amounts[0], "");
        factory.mintAsset(minter, ASSET_TWO_ID, amounts[1], "");
        factory.mintAsset(minter, ASSET_THREE_ID, amounts[2], "");
        vm.stopPrank();
    }
}
