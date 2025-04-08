//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AssetFactoryTestHelper } from "./AssetFactoryTestHelper.sol";

/// @dev Helper contract for interacting with the AssetVault contract.
/// Inheritance Tree:
/// AssetVaultTestHelper -> AssetFactoryTestHelper -> TestingVariables & Test
contract AssetVaultTestHelper is AssetFactoryTestHelper {
    ////////////////////////////////////////////////
    /// Setup Function                           ///
    ////////////////////////////////////////////////

    /// @dev Sets the assets data, mints IGC and assets for userA & userB, and stores the starting balances for userA & userB.
    function setUp() public virtual {
        // Called from AssetFactoryTestHelper
        setInitialFactoryState();

        // Set approved caller for vault lock and unlock functions
        approveCallerHelper(approvedCaller);

        // Update the starting vault balances for userA
        userAStartingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        userAStartingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        userAStartingVaultAssetThreeBalance = vault.balanceOf(userA, ASSET_THREE_ID);
    }

    ////////////////////////////////////////////////
    /// Contract Call Helpers                    ///
    ////////////////////////////////////////////////

    /// @dev Deposits IGC for a user.
    /// @param user The address of the user depositing IGC.
    /// @param amount The amount of IGC to deposit.
    function depositIGCTestHelper(address user, uint256 amount) public {
        vm.startPrank(user);
        factory.setApprovalForAll(address(vault), true);
        vault.depositIGC(amount);
        vm.stopPrank();
    }

    /// @dev Deposits an asset for a user.
    /// @param user The address of the user depositing assets.
    /// @param assetIds The IDs of the asset to deposit.
    /// @param amounts The amounts of the assets to deposit.
    function depositAssetsTestHelper(address user, uint256[] memory assetIds, uint256[] memory amounts) public {
        vm.startPrank(user);
        factory.setApprovalForAll(address(vault), true);
        vault.depositAssets(assetIds, amounts);
        vm.stopPrank();
    }

    /// @dev Withdraws IGC to a target address.
    /// @param user The address of the user withdrawing IGC.
    /// @param to The address to withdraw the IGC to.
    /// @param amount The amount of IGC to withdraw.
    function withdrawIGCTestHelper(address user, address to, uint256 amount) public {
        vm.prank(user);
        vault.withdrawIGC(to, amount);
    }

    /// @dev Withdraws assets to a target address.
    /// @param user The address of the user withdrawing assets.
    /// @param to The address to withdraw the assets to.
    /// @param assetIds The IDs of the assets to withdraw.
    /// @param amounts The amounts of the assets to withdraw.
    function withdrawAssetsTestHelper(address user, address to, uint256[] memory assetIds, uint256[] memory amounts)
        public
    {
        vm.prank(user);
        vault.withdrawAssets(to, assetIds, amounts);
    }

    /// @dev Locks assets for a user.
    /// @param caller The address of the caller that is locking the assets.
    /// @param user The address of the user whose assets are being locked.
    /// @param assetId The ID of the asset to lock.
    /// @param amount The amount of the asset to lock.
    function lockAssetTestHelper(address caller, address user, uint256 assetId, uint256 amount) public {
        vm.prank(caller);
        vault.lockAsset(user, assetId, amount);
    }

    /// @dev Unlocks assets for a user.
    /// @param caller The address of the caller that is unlocking the assets.
    /// @param user The address of the user to unlock assets for.
    /// @param assetId The ID of the asset to unlock.
    /// @param amount The amount of the asset to unlock.
    function unlockAssetTestHelper(address caller, address user, uint256 assetId, uint256 amount) public {
        vm.prank(caller);
        vault.unlockAsset(user, assetId, amount);
    }

    /// @dev Approves a caller to interact with the lock/unlock functions.
    /// @dev This function is only callable by the owner of the vault.
    /// @param caller The address of the caller to approve.
    function approveCallerHelper(address caller) public {
        vm.prank(owner);
        vault.approveCaller(caller);
    }
}
