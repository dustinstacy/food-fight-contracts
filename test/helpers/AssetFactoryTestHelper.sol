//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {TestingVariables} from "./TestingVariables.sol";

/// @dev Helper contract for interacting with the AssetFactory contract.
/// @dev Is also repsonsible for extending the TestingVariables and Test contracts to all inheriting contracts.
contract AssetFactoryTestHelper is TestingVariables, Test {
    ////////////////////////////////////////////////
    /// Setter Function                         ///
    ////////////////////////////////////////////////

    /// @dev Sets the asset data, mints IGC and assets for userA, and stores the starting balances for userA.
    function setInitialFactoryState() public {
        setAssetsTestHelper();
        mintIGCTestHelper(userA, ONE_MILLION);
        mintAssetTestHelper(userA, assetIds, all);

        // Update the starting factory balances for userA
        userAStartingFactoryIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        userAStartingFactoryAssetOneBalance = factory.balanceOf(
            userA,
            ASSET_ONE_ID
        );
        userAStartingFactoryAssetTwoBalance = factory.balanceOf(
            userA,
            ASSET_TWO_ID
        );
        userAStartingFactoryAssetThreeBalance = factory.balanceOf(
            userA,
            ASSET_THREE_ID
        );
    }

    /////////////////////////////////////////////////
    /// Contract Call Helpers                     ///
    /////////////////////////////////////////////////

    /// @dev Sets the asset data for the factory.
    function setAssetsTestHelper() public {
        vm.startPrank(owner);
        factory.setAssetData("ipfs://asset1", 100);
        factory.setAssetData("ipfs://asset2", 200);
        factory.setAssetData("ipfs://asset3", 300);
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
    /// @param assetIds The IDs of the assets to mint.
    /// @param amounts The amounts of each asset to mint.
    function mintAssetTestHelper(
        address minter,
        uint256[] memory assetIds,
        uint256[] memory amounts
    ) public {
        vm.startPrank(minter);
        for (uint256 i = 0; i < assetIds.length; i++) {
            factory.mintAsset(minter, assetIds[i], amounts[i], "");
        }
        vm.stopPrank();
    }

    /// @dev Sets the approval for all assets for a user to an operator.
    /// @param user The address of the user to set approval for.
    /// @param operator The address of the operator to set approval for.
    /// @param approved The approval status to set.
    function setApprovalForAllHelper(
        address user,
        address operator,
        bool approved
    ) public {
        vm.prank(user);
        factory.setApprovalForAll(operator, approved);
    }
}
