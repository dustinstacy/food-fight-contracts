//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { AssetVault } from "@contracts/AssetVault.sol";
import { AssetVaultTestHelper } from "./helpers/AssetVaultTestHelper.sol";

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetVaultConstructorTest is AssetVaultTestHelper {
    function test_constructor() public view {
        address expectedAddress = address(factory);
        address actualAddress = vault.getAssetFactoryAddress();

        // Check that the factory contract address was set correctly
        assertEq(expectedAddress, actualAddress);
    }
}

///////////////////////////////////////////////////////////
///                DEPOSIT FUNCTION TESTS               ///
///////////////////////////////////////////////////////////

contract AssetVaultDepositIGCTest is AssetVaultTestHelper {
    function test_depositIGC() public {
        vm.startPrank(userA);
        factory.setApprovalForAll(address(vault), true);
        vault.depositIGC(10);
        vm.stopPrank();

        uint256 userAEndingFactoryIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        uint256 userAEndingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);

        // Check that the user's balances were updated correctly
        assertEq(userAStartingFactoryIGCBalance - 10, userAEndingFactoryIGCBalance);
        assertEq(userAStartingVaultIGCBalance + 10, userAEndingVaultIGCBalance);
    }

    function test_depositIGC_EventEmitted() public {
        vm.startPrank(userA);
        factory.setApprovalForAll(address(vault), true);

        // Check that the IGCDeposited event was emitted
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.IGCDeposited(userA, 10);
        vault.depositIGC(10);
        vm.stopPrank();
    }

    function test_depositIGC_RevertsIf_InsufficientBalance() public {
        vm.startPrank(userB);
        factory.setApprovalForAll(address(vault), true);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, userB, 0, 1, IGC_TOKEN_ID)
        );
        vault.depositIGC(1);
        vm.stopPrank();
    }

    function test_depositIGC_RevertsIf_MissingApprovalForAll() public {
        vm.startPrank(userA);

        // Check that the function reverts with the ERC1155MissingApprovalForAll error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, address(vault), userA)
        );
        vault.depositIGC(10);
        vm.stopPrank();
    }
}

contract AssetVaultDepositAssetsTest is AssetVaultTestHelper {
    function test_depositAssets() public {
        vm.startPrank(userA);
        factory.setApprovalForAll(address(vault), true);
        // asset1Single = [ASSET_ONE_ID]
        // amountSingle = [1]
        vault.depositAssets(asset1Single, amountSingle);
        vm.stopPrank();

        uint256 userAEndingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);

        // Check that the user's balances were updated correctly
        assertEq(userAStartingFactoryAssetOneBalance - 1, userAEndingFactoryAssetOneBalance);
        assertEq(userAStartingVaultAssetOneBalance + 1, userAEndingVaultAssetOneBalance);
    }

    function test_depositAssets_MultipleAssets() public {
        vm.startPrank(userA);
        factory.setApprovalForAll(address(vault), true);
        // assetIds = [ASSET_ONE_ID, ASSET_TWO_ID, ASSET_THREE_ID]
        // all = [10, 10, 10]
        vault.depositAssets(assetIds, all);
        vm.stopPrank();

        uint256 userAEndingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        uint256 userAEndingFactoryAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        uint256 userAEndingFactoryAssetThreeBalance = factory.balanceOf(userA, ASSET_THREE_ID);
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        uint256 userAEndingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        uint256 userAEndingVaultAssetThreeBalance = vault.balanceOf(userA, ASSET_THREE_ID);

        // Check that the user's balances were updated correctly
        assertEq(userAStartingFactoryAssetOneBalance - 10, userAEndingFactoryAssetOneBalance);
        assertEq(userAStartingFactoryAssetTwoBalance - 10, userAEndingFactoryAssetTwoBalance);
        assertEq(userAStartingFactoryAssetThreeBalance - 10, userAEndingFactoryAssetThreeBalance);
        assertEq(userAStartingVaultAssetOneBalance + 10, userAEndingVaultAssetOneBalance);
        assertEq(userAStartingVaultAssetTwoBalance + 10, userAEndingVaultAssetTwoBalance);
        assertEq(userAStartingVaultAssetThreeBalance + 10, userAEndingVaultAssetThreeBalance);
    }

    function test_depositAssets_EventEmitted() public {
        vm.startPrank(userA);
        factory.setApprovalForAll(address(vault), true);

        // Check that the AssetsDeposited event was emitted
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.AssetsDeposited(userA, asset1Single, amountSingle);
        vault.depositAssets(asset1Single, amountSingle);
        vm.stopPrank();
    }

    function test_depositAssets_RevertsIf_InvalidArrayLength() public {
        vm.startPrank(userA);
        factory.setApprovalForAll(address(vault), true);

        // Check that the function reverts with the AssetVaultInvalidArrayLength error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidArrayLength.selector, assetIds.length, invalid.length)
        );
        vault.depositAssets(assetIds, invalid);
        vm.stopPrank();
    }

    function test_depositAssets_RevertsIf_InsufficientBalance() public {
        vm.startPrank(userB);
        factory.setApprovalForAll(address(vault), true);

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

        userAStartingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        userAStartingFactoryAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        userAStartingFactoryAssetThreeBalance = factory.balanceOf(userA, ASSET_THREE_ID);
        userAStartingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        userAStartingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        userAStartingVaultAssetThreeBalance = vault.balanceOf(userA, ASSET_THREE_ID);
    }

    function test_withdrawAssets() public {
        vm.prank(userA);
        vault.withdrawAssets(userA, asset1Single, amountSingle);

        uint256 userAEndingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);

        // Check that the user's balances were updated correctly
        assertEq(userAStartingFactoryAssetOneBalance + 1, userAEndingFactoryAssetOneBalance);
        assertEq(userAStartingVaultAssetOneBalance - 1, userAEndingVaultAssetOneBalance);
    }

    function test_withdrawAssets_Multiple() public {
        vm.prank(userA);
        vault.withdrawAssets(userA, assetIds, allVarying);

        uint256 userAEndingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        uint256 userAEndingFactoryAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        uint256 userAEndingFactoryAssetThreeBalance = factory.balanceOf(userA, ASSET_THREE_ID);
        uint256 userAEndingVaultAssetOneBalance = vault.balanceOf(userA, ASSET_ONE_ID);
        uint256 userAEndingVaultAssetTwoBalance = vault.balanceOf(userA, ASSET_TWO_ID);
        uint256 userAEndingVaultAssetThreeBalance = vault.balanceOf(userA, ASSET_THREE_ID);

        // Check that the user's balances were updated correctly
        assertEq(userAStartingFactoryAssetOneBalance + 1, userAEndingFactoryAssetOneBalance);
        assertEq(userAStartingFactoryAssetTwoBalance + 5, userAEndingFactoryAssetTwoBalance);
        assertEq(userAStartingFactoryAssetThreeBalance + 10, userAEndingFactoryAssetThreeBalance);
        assertEq(userAStartingVaultAssetOneBalance - 1, userAEndingVaultAssetOneBalance);
        assertEq(userAStartingVaultAssetTwoBalance - 5, userAEndingVaultAssetTwoBalance);
        assertEq(userAStartingVaultAssetThreeBalance - 10, userAEndingVaultAssetThreeBalance);
    }

    function test_withdrawAssets_EventEmitted() public {
        vm.prank(userA);

        // Check that the AssetsWithdrawn event was emitted
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.AssetsWithdrawn(userA, asset1Single, amountSingle);
        vault.withdrawAssets(userA, asset1Single, amountSingle);
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

        userAStartingFactoryIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        userAStartingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
    }

    function test_withdrawIGC() public {
        vm.prank(userA);
        vault.withdrawIGC(userA, 10);

        uint256 userAEndingFactoryIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        uint256 userAEndingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);

        // Check that the user's balances were updated correctly
        assertEq(userAStartingFactoryIGCBalance + 10, userAEndingFactoryIGCBalance);
        assertEq(userAStartingVaultIGCBalance - 10, userAEndingVaultIGCBalance);
    }

    function test_withdrawIGC_EventEmitted() public {
        vm.prank(userA);

        // Check that the IGCWithdrawn event was emitted
        vm.expectEmit(false, false, false, false, address(vault));
        emit AssetVault.IGCWithdrawn(userA, 10);
        vault.withdrawIGC(userA, 10);
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

        userAStartingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
    }

    function test_lockAsset() public {
        vm.prank(userA);
        vault.lockAsset(userA, IGC_TOKEN_ID, 10);

        uint256 userAEndingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);

        // Check that the user's balance was updated correctly
        assertEq(userAStartingVaultIGCBalance - 10, userAEndingVaultIGCBalance);
    }

    function test_lockAsset_RevertsIf_InsufficientBalance() public {
        vm.prank(userB);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(AssetVault.AssetVaultInsufficientBalance.selector, userB, 0, 1, IGC_TOKEN_ID)
        );
        vault.lockAsset(userB, IGC_TOKEN_ID, 1);
    }

    function test_unlockAsset() public {
        lockAssetTestHelper(userA, IGC_TOKEN_ID, 10);

        vm.prank(userA);
        vault.unlockAsset(userA, IGC_TOKEN_ID, 10);

        uint256 userAEndingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);

        // Check that the user's balance was updated correctly
        assertEq(userAStartingVaultIGCBalance, userAEndingVaultIGCBalance);
    }
}

///////////////////////////////////////////////////////////
///                  VIEW FUNCTION TESTS                ///
///////////////////////////////////////////////////////////

contract AssetVaultViewFunctionsTest is AssetVaultTestHelper {
    function setUp() public override {
        super.setUp();
        depositIGCTestHelper(userA, 10);

        userAStartingVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);
    }

    function test_balanceOf() public view {
        uint256 userAVaultIGCBalance = vault.balanceOf(userA, IGC_TOKEN_ID);

        // Check that the user's balance was returned correctly
        assertEq(userAStartingVaultIGCBalance, userAVaultIGCBalance);
    }

    function test_getAssetFactoryAddress() public view {
        address factoryAddress = vault.getAssetFactoryAddress();

        // Check that the factory contract address was returned correctly
        assertEq(address(factory), factoryAddress);
    }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetVaultERC1155ReceiverTest is AssetVaultTestHelper {
    function test_onERC1155Received() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        bytes4 returnedSelector = vault.onERC1155Received(address(0), address(0), 0, 0, "");

        // Check that the correct selector was returned
        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        bytes4 returnedSelector =
            vault.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");

        // Check that the correct selector was returned
        assertEq(returnedSelector, expectedSelector);
    }
}

///////////////////////////////////////////////////////////
///               IERC165 INTERFACE TESTS               ///
///////////////////////////////////////////////////////////

contract AssetVaultERC165Test is AssetVaultTestHelper {
    function test_supportsInterfaceIdIERC165() public view {
        bytes4 expectedSelector = 0x01ffc9a7;
        bool returnedSelector = vault.supportsInterface(expectedSelector);

        // Check that the contract supports the IERC165 interface
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceIdIERC1155Receiver() public view {
        bytes4 expectedSelector = 0x4e2312e0;
        bool returnedSelector = vault.supportsInterface(expectedSelector);

        // Check that the contract supports the IERC1155Receiver interface
        assertEq(returnedSelector, true);
    }

    function test_supportsInterfaceBadSelector() public view {
        bytes4 badSelector = bytes4(keccak256("badSelector"));
        bool returnedSelector = vault.supportsInterface(badSelector);

        // Check that the contract throws false for an unsupported interface
        assertEq(returnedSelector, false);
    }
}
