//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AssetFactoryTestHelper } from "./AssetFactoryTestHelper.sol";

/// @dev Helper contract for interacting with the AssetVault contract
contract AssetVaultTestHelper is AssetFactoryTestHelper {
    uint256 userAStartingVaultIGCBalance;
    uint256 userAStartingVaultAssetOneBalance;
    uint256 userAStartingVaultAssetTwoBalance;
    uint256 userAStartingVaultAssetThreeBalance;

    /// @dev Sets the assets, mints IGC for users, and mints assets for users.
    function setUp() public virtual {
        setInitialFactoryState();

        userAStartingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        userAStartingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        userAStartingVaultAssetThreeBalance = vault.balanceOf(userA, ASSET_THREE_ID);
    }

    /// @param user The address of the user depositing IGC.
    /// @param amount The amount of IGC to deposit.
    /// @dev Deposits IGC for a user.
    function depositIGCTestHelper(address user, uint256 amount) public {
        vm.startPrank(user);
        factory.setApprovalForAll(address(vault), true);
        vault.depositIGC(amount);
        vm.stopPrank();
    }

    /// @param user The address of the user depositing assets.
    /// @param assetIds The IDs of the asset to deposit.
    /// @param amounts The amounts of the assets to deposit.
    /// @dev Deposits an asset for a user.
    function depositAssetsTestHelper(address user, uint256[] memory assetIds, uint256[] memory amounts) public {
        vm.startPrank(user);
        factory.setApprovalForAll(address(vault), true);
        vault.depositAssets(assetIds, amounts);
        vm.stopPrank();
    }

    /// @param user The address of the user withdrawing IGC.
    /// @param to The address to withdraw the IGC to.
    /// @param amount The amount of IGC to withdraw.
    /// @dev Withdraws IGC to a target address.
    function withdrawIGCTestHelper(address user, address to, uint256 amount) public {
        vm.prank(user);
        vault.withdrawIGC(to, amount);
    }

    /// @param user The address of the user withdrawing assets.
    /// @param to The address to withdraw the assets to.
    /// @param assetIds The IDs of the assets to withdraw.
    /// @param amounts The amounts of the assets to withdraw.
    /// @dev Withdraws assets to a target address.
    function withdrawAssetsTestHelper(address user, address to, uint256[] memory assetIds, uint256[] memory amounts)
        public
    {
        vm.prank(user);
        vault.withdrawAssets(to, assetIds, amounts);
    }

    /// @param user The address of the user whose assets are being locked.
    /// @param assetId The ID of the asset to lock.
    /// @param amount The amount of the asset to lock.
    /// @dev Locks assets for a user.
    function lockAssetTestHelper(address user, uint256 assetId, uint256 amount) public {
        vm.prank(user);
        vault.lockAsset(user, assetId, amount);
    }

    /// @param user The address of the user to unlock assets for.
    /// @param assetId The ID of the asset to unlock.
    /// @param amount The amount of the asset to unlock.
    /// @dev Unlocks assets for a user.
    function unlockAssetTestHelper(address user, uint256 assetId, uint256 amount) public {
        vm.prank(user);
        vault.unlockAsset(user, assetId, amount);
    }
}
