//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IERC1155 } from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { AssetFactory } from "@contracts/AssetFactory.sol";
import { AssetFactoryTestHelper } from "./helpers/AssetFactoryTestHelper.sol";

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////
contract AssetFactoryConstructorTest is AssetFactoryTestHelper {
    function test_assetFactoryConstructor() public view {
        // Check that the owner is set correctly
        address expectedOwner = owner;
        address actualOwner = factory.owner();
        assertEq(actualOwner, expectedOwner);
    }
}

///////////////////////////////////////////////////////////
///                  IGC FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetFactoryIGCFunctionsTest is AssetFactoryTestHelper {
    function test_mintIGC() public {
        vm.prank(userA);

        // Check for the MintIGC event when minting IGC
        vm.expectEmit(true, false, false, false, address(factory));
        emit AssetFactory.IGCminted(userA, 1);
        factory.mintIGC(userA, 1);

        // Check that userA's IGC balance has increased
        uint256 userAEndingIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAEndingIGCBalance, userAStartingFactoryIGCBalance + 1);
    }

    function test_mintIGC_RevertsIf_InvalidReceiver() public {
        vm.prank(address(invalidReceiver));

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(invalidReceiver))
        );
        factory.mintIGC(address(invalidReceiver), 1);
    }
}

///////////////////////////////////////////////////////////
///                 MINT FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetFactoryMintingFunctionsTest is AssetFactoryTestHelper {
    uint256 mintBatchTotalCost;

    function setUp() public {
        setAssetsTestHelper();
        mintIGCTestHelper(userA, ONE_MILLION);

        // Update the starting factory balances for userA
        userAStartingFactoryIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        userAStartingFactoryAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        userAStartingFactoryAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        userAStartingFactoryAssetThreeBalance = factory.balanceOf(userA, ASSET_THREE_ID);

        // Calculate mint cost based on the allVarying array found in TestingVariables ( [1, 5, 10] )
        mintBatchTotalCost = ASSET_ONE_PRICE + (ASSET_TWO_PRICE * 5) + (ASSET_THREE_PRICE * 10);
    }

    function test_mintAsset() public {
        vm.prank(userA);

        // Check for the AssetMinted event when minting an asset
        vm.expectEmit(true, false, false, false, address(factory));
        emit AssetFactory.AssetMinted(userA, ASSET_ONE_ID, 1);
        factory.mintAsset(userA, ASSET_ONE_ID, 1, "");

        // Check that userA's asset balance has increased
        uint256 userAEndingAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAEndingAssetOneBalance, userAStartingFactoryAssetOneBalance + 1);

        // Check that userA's IGC balance has decreased
        uint256 userAEndingIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAEndingIGCBalance, userAStartingFactoryIGCBalance - ASSET_ONE_PRICE);
    }

    function test_mintAsset_RevertsIf_InsufficientBalance() public {
        vm.prank(userB);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, userB, 0, ASSET_ONE_PRICE, 0)
        );
        factory.mintAsset(userB, ASSET_ONE_ID, 1, "");
    }

    function test_mintAsset_RevertsIf_AddressZero() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        factory.mintAsset(address(0), ASSET_ONE_ID, 1, "");
    }

    function test_mintAsset_RevertsIf_InvalidReceiver() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(invalidReceiver))
        );
        factory.mintAsset(address(invalidReceiver), ASSET_ONE_ID, 1, "");
    }

    function test_mintBatch() public {
        vm.prank(userA);

        // Check for the TransferBatch event when minting multiple assets
        vm.expectEmit(false, true, false, false, address(factory));
        emit IERC1155.TransferBatch(userA, address(0), userA, assetIds, allVarying);
        // assetIds = [ASSET_ONE_ID, ASSET_TWO_ID, ASSET_THREE_ID]
        // allVarying = [1, 5, 10]
        factory.mintBatch(userA, assetIds, allVarying, "");

        // Check that userA's IGC balance has decreased
        uint256 userAEndingIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAEndingIGCBalance, userAStartingFactoryIGCBalance - mintBatchTotalCost);

        // Check that userA's asset balances have increased
        uint256 userAEndingAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAEndingAssetOneBalance, userAStartingFactoryAssetOneBalance + 1);

        uint256 userAEndingAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        assertEq(userAEndingAssetTwoBalance, userAStartingFactoryAssetTwoBalance + 5);

        uint256 userAEndingAssetThreeBalance = factory.balanceOf(userA, ASSET_THREE_ID);
        assertEq(userAEndingAssetThreeBalance, userAStartingFactoryAssetThreeBalance + 10);
    }

    function test_mintBatch_RevertsIf_InvalidArrayLength() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InvalidArrayLength error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidArrayLength.selector, assetIds.length, invalid.length)
        );
        factory.mintBatch(userA, assetIds, invalid, "");
    }

    function test_mintBatch_RevertsIf_InsufficientBalance() public {
        vm.prank(userB);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, userB, 0, mintBatchTotalCost, 0)
        );
        factory.mintBatch(userA, assetIds, allVarying, "");
    }

    function test_mintBatch_RevertsIf_AddressZero() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        factory.mintBatch(address(0), assetIds, allVarying, "");
    }

    function test_mintBatch_RevertsIf_InvalidReceiver() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(invalidReceiver))
        );
        factory.mintBatch(address(invalidReceiver), assetIds, allVarying, "");
    }
}

///////////////////////////////////////////////////////////
///                 BURN FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetFactoryBurningFunctionsTest is AssetFactoryTestHelper {
    function setUp() public {
        setInitialFactoryState();
    }

    function test_burnAsset_IGC() public {
        vm.prank(userA);

        // Check for the BurntSingle event when burning IGC
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetFactory.BurntSingle(userA, IGC_TOKEN_ID, 1000);
        factory.burnAsset(userA, IGC_TOKEN_ID, 1000);

        // Check that userA's IGC balance has decreased
        uint256 userAEndingIGCBalance = factory.balanceOf(userA, IGC_TOKEN_ID);
        assertEq(userAEndingIGCBalance, userAStartingFactoryIGCBalance - 1000);
    }

    function test_burnAsset_Single() public {
        vm.prank(userA);

        // Check for the BurntSingle event when burning an asset
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetFactory.BurntSingle(userA, ASSET_ONE_ID, 1);
        factory.burnAsset(userA, ASSET_ONE_ID, 1);

        // Check that userA's asset balance has decreased
        uint256 userAEndingAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAEndingAssetOneBalance, userAStartingFactoryAssetOneBalance - 1);
    }

    function test_burnAsset_Multiple() public {
        vm.prank(userA);

        // Check for the BurntSingle event when burning an asset
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetFactory.BurntSingle(userA, ASSET_TWO_ID, 5);
        factory.burnAsset(userA, ASSET_TWO_ID, 5);

        // Check that userA's asset balance has decreased
        uint256 userAEndingAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        assertEq(userAEndingAssetTwoBalance, userAStartingFactoryAssetTwoBalance - 5);
    }

    function test_burnAsset_WithApproval() public {
        setApprovalForAllHelper(userA, approvedCaller, true);
        vm.prank(approvedCaller);

        // Check for the BurntSingle event when burning an asset
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetFactory.BurntSingle(userA, ASSET_ONE_ID, 1);
        factory.burnAsset(userA, ASSET_ONE_ID, 1);

        // Check that userA's asset balance has decreased
        uint256 userAEndingAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAEndingAssetOneBalance, userAStartingFactoryAssetOneBalance - 1);
    }

    function test_burnAsset_RevertsIf_MissingApprovalForAll() public {
        vm.prank(owner);

        // Check that the function reverts with the ERC1155MissingApproval error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, owner, userA));
        factory.burnAsset(userA, ASSET_ONE_ID, 1);
    }

    function test_burn_RevertsIf_InsufficientBalance() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, userA, 10, 11, ASSET_ONE_ID)
        );
        factory.burnAsset(userA, ASSET_ONE_ID, 11);
    }

    function test_burnBatch() public {
        vm.prank(userA);

        // Check for the BurntBatch event when burning multiple assets
        vm.expectEmit(false, false, true, false, address(factory));
        emit AssetFactory.BurntBatch(userA, assetIds, allVarying);
        factory.burnBatch(userA, assetIds, allVarying);

        // Check that userA's asset balances have decreased
        uint256 userAEndingAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAEndingAssetOneBalance, userAStartingFactoryAssetOneBalance - 1);

        uint256 userAEndingAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        assertEq(userAEndingAssetTwoBalance, userAStartingFactoryAssetTwoBalance - 5);

        uint256 userAEndingAssetThreeBalance = factory.balanceOf(userA, ASSET_THREE_ID);
        assertEq(userAEndingAssetThreeBalance, userAStartingFactoryAssetThreeBalance - 10);
    }

    function test_burnBatch_WithApproval() public {
        setApprovalForAllHelper(userA, approvedCaller, true);
        vm.prank(approvedCaller);

        // Check for the BurntBatch event when burning multiple assets
        vm.expectEmit(false, false, true, false, address(factory));
        emit AssetFactory.BurntBatch(userA, assetIds, allVarying);
        factory.burnBatch(userA, assetIds, allVarying);

        // Check that userA's asset balances have decreased
        uint256 userAEndingAssetOneBalance = factory.balanceOf(userA, ASSET_ONE_ID);
        assertEq(userAEndingAssetOneBalance, userAStartingFactoryAssetOneBalance - 1);

        uint256 userAEndingAssetTwoBalance = factory.balanceOf(userA, ASSET_TWO_ID);
        assertEq(userAEndingAssetTwoBalance, userAStartingFactoryAssetTwoBalance - 5);

        uint256 userAEndingAssetThreeBalance = factory.balanceOf(userA, ASSET_THREE_ID);
        assertEq(userAEndingAssetThreeBalance, userAStartingFactoryAssetThreeBalance - 10);
    }

    function test_burnBatch_RevertsIf_MissingApprovalForAll() public {
        vm.prank(owner);

        // Check that the function reverts with the ERC1155MissingApproval error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, owner, userA));
        factory.burnBatch(userA, assetIds, allVarying);
    }

    function test_burnBatch_RevertsIf_InvalidArrayLength() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InvalidArrayLength error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidArrayLength.selector, assetIds.length, invalid.length)
        );
        factory.burnBatch(userA, assetIds, invalid);
    }

    function test_burnBatch_RevertsIf_InsufficientBalance() public {
        vm.prank(userA);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, userA, 10, 11, ASSET_ONE_ID)
        );
        // all = [10, 10, 10]. Update the first index to 11 to trigger the revert
        all[0] = 11;
        factory.burnBatch(userA, assetIds, all);
    }
}

///////////////////////////////////////////////////////////
///               SETTER FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetFactorySetterFunctionsTest is AssetFactoryTestHelper {
    string newURI = "ipfs://asset1NewURI";

    function test_setAssetURI() public {
        vm.prank(owner);

        // Check for the AssetURISet event when setting the new URI
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetFactory.AssetURISet(newURI, ASSET_ONE_ID);
        factory.setAssetURI(ASSET_ONE_ID, newURI);

        // Check the URI was set correctly
        assertEq(factory.getAssetURI(ASSET_ONE_ID), newURI);
    }

    function test_setAssetURI_ReverstIf_NotTheOwner() public {
        vm.prank(userA);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));
        factory.setAssetURI(ASSET_ONE_ID, newURI);
    }

    function test_setAssetPrice() public {
        vm.prank(owner);

        // Check for the AssetPriceSet event when setting the new price
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetFactory.AssetPriceSet(ASSET_ONE_ID, ONE_MILLION);
        factory.setAssetPrice(ASSET_ONE_ID, ONE_MILLION);

        // Check the price was set correctly
        assertEq(factory.getAssetPrice(ASSET_ONE_ID), ONE_MILLION);
    }

    function test_setAssetPrice_RevertsIf_NotTheOwner() public {
        vm.prank(userA);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));
        factory.setAssetPrice(ASSET_ONE_ID, ONE_MILLION);
    }

    function test_setAssetData() public {
        vm.prank(owner);

        // Check for the AssetDataSet event when setting the new URI and price
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetFactory.AssetDataSet(newURI, ASSET_ONE_ID, ONE_MILLION);
        factory.setAssetData(ASSET_ONE_ID, newURI, ONE_MILLION);

        // Check the URI and price were set correctly
        assertEq(factory.getAssetURI(ASSET_ONE_ID), newURI);
        assertEq(factory.getAssetPrice(ASSET_ONE_ID), ONE_MILLION);
    }

    function test_setAssetData_RevertsIf_NotTheOwner() public {
        vm.prank(userA);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, userA));
        factory.setAssetData(ASSET_ONE_ID, newURI, ONE_MILLION);
    }
}

///////////////////////////////////////////////////////////
///                 VIEW FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetFactoryViewFunctionsTest is AssetFactoryTestHelper {
    function setUp() public {
        setAssetsTestHelper();
    }

    function test_getAssetUri() public view {
        // Check the URI is retrieved correctly
        string memory expectedURI = "ipfs://asset1";
        string memory actualURI = factory.getAssetURI(ASSET_ONE_ID);
        assertEq(actualURI, expectedURI);
    }

    function test_getAssetPrice() public view {
        // Check the price is retrieved correctly
        uint256 expectedPrice = ASSET_ONE_PRICE;
        uint256 actualPrice = factory.getAssetPrice(ASSET_ONE_ID);
        assertEq(actualPrice, expectedPrice);
    }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetFactoryERC1155ReceiverTest is AssetFactoryTestHelper {
    function test_onERC1155Received() public view {
        // Check the correct selector was returned
        bytes4 expectedSelector = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        bytes4 returnedSelector = factory.onERC1155Received(address(0), address(0), 0, 0, "");
        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        // Check the correct selector was returned
        bytes4 expectedSelector = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        bytes4 returnedSelector =
            factory.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");
        assertEq(returnedSelector, expectedSelector);
    }
}
