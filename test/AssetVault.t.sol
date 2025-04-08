//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from "forge-std/console.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { AssetVault } from "@contracts/AssetVault.sol";
import { AssetVaultTestHelper } from "./helpers/AssetVaultTestHelper.sol";

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetVaultConstructorTest is AssetVaultTestHelper {
    function test_constructor() public view {
        // Check that the factory contract address was set correctly
        address expectedAddress = address(factory);
        address actualAddress = vault.getAssetFactoryAddress();
        assertEq(expectedAddress, actualAddress);
    }
}

///////////////////////////////////////////////////////////
///                DEPOSIT FUNCTION TESTS               ///
///////////////////////////////////////////////////////////

contract AssetVaultDepositIGCTest is AssetVaultTestHelper {
    function test_depositIGC() public {
        vm.startPrank(userA);

        // Check for the ApprovalForAll event when the user approves the vault
        vm.expectEmit(false, false, false, false, address(factory));
        emit IERC1155.ApprovalForAll(userA, address(vault), true);
        factory.setApprovalForAll(address(vault), true);

        // Check for the IGCDeposited event when the user deposits IGC
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.IGCDeposited(userA, 10);
        vault.depositIGC(10);

        vm.stopPrank();

        // Check that the user's factory balance was updated correctly
        uint256 userAEndingFactoryIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAStartingFactoryIGCBalance - 10, userAEndingFactoryIGCBalance);

        // Check that the user's vault balance was updated correctly
        uint256 userAEndingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAStartingVaultIGCBalance + 10, userAEndingVaultIGCBalance);
    }

    function test_depositIGC_RevertsIf_InsufficientBalance() public {
        setApprovalForAllHelper(userB, address(vault), true);
        vm.prank(userB);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, userB, 0, 1, IGC_TOKEN_ID)
        );
        vault.depositIGC(1);
    }

    function test_depositIGC_RevertsIf_MissingApprovalForAll() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155MissingApprovalForAll error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, address(vault), userA)
        );
        vault.depositIGC(10);
    }
}

contract AssetVaultDepositAssetsTest is AssetVaultTestHelper {
    function test_depositAssets() public {
        vm.startPrank(userA);

        // Check for the ApprovalForAll event when the user approves the vault
        vm.expectEmit(false, false, false, false, address(factory));
        emit IERC1155.ApprovalForAll(userA, address(vault), true);
        factory.setApprovalForAll(address(vault), true);

        // Check for the Assets Deposited event when the user deposits assets
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.AssetsDeposited(userA, asset1Single, amountSingle);
        // asset1Single = [ASSET_ONE_ID]
        // amountSingle = [1]
        vault.depositAssets(asset1Single, amountSingle);
        vm.stopPrank();

        // Check that the user's factory balance was updated correctly
        uint256 userAEndingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAStartingFactoryAssetOneBalance - 1, userAEndingFactoryAssetOneBalance);

        // Check that the user's vault balance was updated correctly
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAStartingVaultAssetOneBalance + 1, userAEndingVaultAssetOneBalance);
    }

    function test_depositAssets_MultipleAssets() public {
        setApprovalForAllHelper(userA, address(vault), true);
        vm.prank(userA);

        // Check for the Assets Deposited event when the user deposits multiple assets
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.AssetsDeposited(userA, assetIds, all);
        // assetIds = [ASSET_ONE_ID, ASSET_TWO_ID, ASSET_THREE_ID]
        // all = [10, 10, 10]
        vault.depositAssets(assetIds, all);

        // Check that the user's factory balances were updated correctly
        uint256 userAEndingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAStartingFactoryAssetOneBalance - 10, userAEndingFactoryAssetOneBalance);

        uint256 userAEndingFactoryAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        assertEq(userAStartingFactoryAssetTwoBalance - 10, userAEndingFactoryAssetTwoBalance);

        uint256 userAEndingFactoryAssetThreeBalance = factory.balanceOf(userA, ASSET_THREE_ID);
        assertEq(userAStartingFactoryAssetThreeBalance - 10, userAEndingFactoryAssetThreeBalance);

        // Check that the user's vault balances wer updated correctly
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAStartingVaultAssetOneBalance + 10, userAEndingVaultAssetOneBalance);

        uint256 userAEndingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        assertEq(userAStartingVaultAssetTwoBalance + 10, userAEndingVaultAssetTwoBalance);

        uint256 userAEndingVaultAssetThreeBalance = vault.balanceOf(userA, ASSET_THREE_ID);
        assertEq(userAStartingVaultAssetThreeBalance + 10, userAEndingVaultAssetThreeBalance);
    }

    function test_depositAssets_RevertsIf_InvalidArrayLength() public {
        setApprovalForAllHelper(userA, address(vault), true);
        vm.prank(userA);

        // Check that the function reverts with the AssetVaultInvalidArrayLength error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidArrayLength.selector, assetIds.length, invalid.length)
        );
        vault.depositAssets(assetIds, invalid);
        vm.stopPrank();
    }

    function test_depositAssets_RevertsIf_InsufficientBalance() public {
        setApprovalForAllHelper(userB, address(vault), true);
        vm.prank(userB);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, userB, 0, 10, ASSET_ONE_ID)
        );
        vault.depositAssets(assetIds, all);
        vm.stopPrank();
    }

    function test_depositAssets_RevertsIf_MissingApprovalForAll() public {
        vm.startPrank(userA);

        // Check that the function reverts with the ERC1155MissingApprovalForAll error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, address(vault), userA)
        );
        vault.depositAssets(assetIds, all);
        vm.stopPrank();
    }
}

///////////////////////////////////////////////////////////
///               WITHDRAW FUNCTION TESTS               ///
///////////////////////////////////////////////////////////

contract AssetVaultWithdrawAssetsTest is AssetVaultTestHelper {
    function setUp() public override {
        super.setUp();
        depositAssetsTestHelper(userA, assetIds, all);

        // Update the starting factory balances for userA
        userAStartingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        userAStartingFactoryAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        userAStartingFactoryAssetThreeBalance = factory.balanceOf(userA, ASSET_THREE_ID);

        // Update the starting vault balances for userA
        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        userAStartingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        userAStartingVaultAssetThreeBalance = vault.balanceOf(userA, ASSET_THREE_ID);
    }

    function test_withdrawAssets() public {
        vm.prank(userA);

        // Check for the AssetsWithdrawn event when the user withdraws assets
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.AssetsWithdrawn(userA, asset1Single, amountSingle);
        vault.withdrawAssets(userA, asset1Single, amountSingle);

        // Check that the user's factory balance was updated correctly
        uint256 userAEndingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAStartingFactoryAssetOneBalance + 1, userAEndingFactoryAssetOneBalance);

        // Check that the user's vault balance was updated correctly
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAStartingVaultAssetOneBalance - 1, userAEndingVaultAssetOneBalance);
    }

    function test_withdrawAssets_Multiple() public {
        vm.prank(userA);

        // Check for the AssetsWithdrawn event when the user withdraws multiple assets
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.AssetsWithdrawn(userA, assetIds, allVarying);
        vault.withdrawAssets(userA, assetIds, allVarying);

        // Check that the user's factory balances were updated correctly
        uint256 userAEndingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAStartingFactoryAssetOneBalance + 1, userAEndingFactoryAssetOneBalance);

        uint256 userAEndingFactoryAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        assertEq(userAStartingFactoryAssetTwoBalance + 5, userAEndingFactoryAssetTwoBalance);

        uint256 userAEndingFactoryAssetThreeBalance = factory.balanceOf(userA, ASSET_THREE_ID);
        assertEq(userAStartingFactoryAssetThreeBalance + 10, userAEndingFactoryAssetThreeBalance);

        // Check that the user's vault balances were updated correctly
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAStartingVaultAssetOneBalance - 1, userAEndingVaultAssetOneBalance);

        uint256 userAEndingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        assertEq(userAStartingVaultAssetTwoBalance - 5, userAEndingVaultAssetTwoBalance);

        uint256 userAEndingVaultAssetThreeBalance = vault.balanceOf(userA, ASSET_THREE_ID);
        assertEq(userAStartingVaultAssetThreeBalance - 10, userAEndingVaultAssetThreeBalance);
    }

    function test_withdrawAssets_RevertsIf_ArrayLengthMismatch() public {
        vm.prank(userA);

        // Check that the function reverts with the AssetVaultrrayLengthMistmatch error
        vm.expectRevert(
            abi.encodeWithSelector(AssetVault.AssetVaultArraysLengthMismatch.selector, assetIds.length, invalid.length)
        );
        vault.withdrawAssets(userA, assetIds, invalid);
    }

    function test_withdrawAssets_RevertsIf_InsufficientBalance() public {
        vm.prank(userB);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(AssetVault.AssetVaultInsufficientBalance.selector, userB, 0, 1, ASSET_ONE_ID)
        );
        vault.withdrawAssets(userB, asset1Single, amountSingle);
    }

    function test_withdrawAssets_RevertsIf_AddressZero() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        vault.withdrawAssets(address(0), asset1Single, amountSingle);
    }

    function test_withdrawAssets_RevertsIf_InvalidReceiver() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(invalidReceiver))
        );
        vault.withdrawAssets(address(invalidReceiver), asset1Single, amountSingle);
    }
}

contract AssetVaultWithdrawIGCTest is AssetVaultTestHelper {
    function setUp() public override {
        super.setUp();
        depositIGCTestHelper(userA, 10);

        // Update the starting factory balance for userA
        userAStartingFactoryIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);

        // Update the starting vault balance for userA
        userAStartingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
    }

    function test_withdrawIGC() public {
        vm.prank(userA);

        // Check for the IGCWithdrawn event when the user withdraws IGC
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.IGCWithdrawn(userA, 10);
        vault.withdrawIGC(userA, 10);

        // Check that the user's factory balance was updated correctly
        uint256 userAEndingFactoryIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAStartingFactoryIGCBalance + 10, userAEndingFactoryIGCBalance);

        // Check that the user's vault balance was updated correctly
        uint256 userAEndingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAStartingVaultIGCBalance - 10, userAEndingVaultIGCBalance);
    }

    function test_withdrawIGC_RevertsIf_InsufficientBalance() public {
        vm.prank(userB);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(AssetVault.AssetVaultInsufficientBalance.selector, userB, 0, 1, IGC_TOKEN_ID)
        );
        vault.withdrawIGC(userB, 1);
    }

    function test_withdrawIGC__RevertsIf_AddressZero() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        vault.withdrawIGC(address(0), 10);
    }

    function test_withdrawIGC_RevertsIf_InvalidReceiver() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(invalidReceiver))
        );
        vault.withdrawIGC(address(invalidReceiver), 10);
    }
}

///////////////////////////////////////////////////////////
///                  LOCK FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetVaultLockFunctionsTest is AssetVaultTestHelper {
    function setUp() public override {
        super.setUp();
        depositIGCTestHelper(userA, 10);

        // Update the starting vault balance for userA
        userAStartingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
    }

    function test_lockAsset() public {
        vm.prank(approvedCaller);

        // Check for the AssetLocked event when the user locks an asset
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.AssetLocked(userA, IGC_TOKEN_ID, 10);
        vault.lockAsset(userA, IGC_TOKEN_ID, 10);

        // Check that the user's balance was updated correctly
        uint256 userAEndingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAStartingVaultIGCBalance - 10, userAEndingVaultIGCBalance);
    }

    function test_lockAsset_RevertsIf_InsufficientBalance() public {
        vm.prank(approvedCaller);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(AssetVault.AssetVaultInsufficientBalance.selector, userB, 0, 1, IGC_TOKEN_ID)
        );
        vault.lockAsset(userB, IGC_TOKEN_ID, 1);
    }

    function test_lockAsset_RevertsIf_UnauthorizedCaller() public {
        vm.prank(userA);

        // Check that the function reverts with the AssetVaultUnauthorizedCaller error
        vm.expectRevert(abi.encodeWithSelector(AssetVault.AssetVaultUnauthorizedCaller.selector, userA));
        vault.lockAsset(userA, IGC_TOKEN_ID, 10);
    }

    function test_unlockAsset() public {
        lockAssetTestHelper(approvedCaller, userA, IGC_TOKEN_ID, 10);

        console.log("vault balance of IGC: ", factory.balanceOf(address(vault), IGC_TOKEN_ID));

        vm.prank(approvedCaller);

        // Check for the AssetUnlocked event when the user unlocks an asset
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.AssetUnlocked(userA, IGC_TOKEN_ID, 10);
        vault.unlockAsset(userA, IGC_TOKEN_ID, 10);

        // Check that the user's balance was updated correctly
        uint256 userAEndingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAStartingVaultIGCBalance, userAEndingVaultIGCBalance);
    }

    function test_unlockAsset_RevertsIf_InsufficientBalance() public {
        vm.prank(approvedCaller);

        // Check that the function reverts with the AssetVaultInsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetVault.AssetVaultInsufficientBalance.selector, address(vault), 0, 1, ASSET_ONE_ID
            )
        );
        vault.unlockAsset(userA, ASSET_ONE_ID, 1);
    }

    function test_unlockAsset_RevertsIf_UnauthorizedCaller() public {
        vm.prank(userA);

        // Check that the function reverts with the AssetVaultUnauthorizedCaller error
        vm.expectRevert(abi.encodeWithSelector(AssetVault.AssetVaultUnauthorizedCaller.selector, userA));
        vault.unlockAsset(userA, IGC_TOKEN_ID, 10);
    }
}

///////////////////////////////////////////////////////////
///              APPROVAL FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetVaultApproveFunctionsTest is AssetVaultTestHelper {
    function test_approveCaller() public {
        vm.prank(owner);

        // Check for the ApprovedCaller event when the owner approves a caller
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.ApprovedCaller(userA);
        vault.approveCaller(userA);

        // Check that the approved caller was set correctly
        assertEq(vault.getIsApprovedCaller(userA), true);
    }

    function test_approveCaller_RevertsIf_NotTheOwner() public {
        vm.prank(userA);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));
        vault.approveCaller(userA);
    }

    function test_revokeCaller() public {
        approveCallerHelper(userA);

        vm.prank(owner);
        // Check for the RevokedCaller event when the owner revokes a caller
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.RevokedCaller(userA);
        vault.revokeCaller(userA);

        // Check that the approved caller was revoked correctly
        assertEq(vault.getIsApprovedCaller(userA), false);
    }

    function test_revokeCaller_RevertsIf_NotTheOwner() public {
        vm.prank(userA);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));
        vault.revokeCaller(userA);
    }
}

///////////////////////////////////////////////////////////
///                  VIEW FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetVaultViewFunctionsTest is AssetVaultTestHelper {
    function setUp() public override {
        super.setUp();
        depositIGCTestHelper(userA, 10);

        // Update the starting vault balance for userA
        userAStartingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
    }

    function test_balanceOf() public view {
        // Check that the user's balance was returned correctly
        uint256 userAVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAStartingVaultIGCBalance, userAVaultIGCBalance);
    }

    function test_getAssetFactoryAddress() public view {
        // Check that the factory contract address was returned correctly
        address factoryAddress = vault.getAssetFactoryAddress();
        assertEq(address(factory), factoryAddress);
    }

    function test_getIGCTokenId() public view {
        // Check that the IGC token ID was returned correctly
        uint256 igcTokenId = vault.getIGCTokenId();
        assertEq(igcTokenId, IGC_TOKEN_ID);
    }

    function test_getIsApprovedCaller() public view {
        // Check that the approved caller was returned correctly
        bool isApproved = vault.getIsApprovedCaller(approvedCaller);
        assertEq(isApproved, true);
    }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetVaultERC1155ReceiverTest is AssetVaultTestHelper {
    function test_onERC1155Received() public view {
        // Check that the correct selector was returned
        bytes4 expectedSelector = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        bytes4 returnedSelector = vault.onERC1155Received(address(0), address(0), 0, 0, "");
        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        // Check that the correct selector was returned
        bytes4 expectedSelector = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        bytes4 returnedSelector =
            vault.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");
        assertEq(returnedSelector, expectedSelector);
    }
}

///////////////////////////////////////////////////////////
///               IERC165 INTERFACE TESTS               ///
///////////////////////////////////////////////////////////

contract AssetVaultERC165Test is AssetVaultTestHelper {
    function test_supportsInterfaceIdIERC165() public view {
        // Check that the contract supports the IERC165 interface
        bytes4 expectedSelector = 0x01ffc9a7;
        bool returnedSelector = vault.supportsInterface(expectedSelector);
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceIdIERC1155Receiver() public view {
        // Check that the contract supports the IERC1155Receiver interface
        bytes4 expectedSelector = 0x4e2312e0;
        bool returnedSelector = vault.supportsInterface(expectedSelector);
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceBadSelector() public view {
        // Check that the contract throws false for an unsupported interface
        bytes4 badSelector = bytes4(keccak256("badSelector"));
        bool returnedSelector = vault.supportsInterface(badSelector);
        assertEq(returnedSelector, false);
    }
}
