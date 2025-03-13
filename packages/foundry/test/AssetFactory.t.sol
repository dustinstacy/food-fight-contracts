//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IERC1155 } from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import { Test, console } from "forge-std/Test.sol";
import { AssetFactory } from "@contracts/AssetFactory.sol";
import { AssetFactoryHelper } from "./helpers/AssetFactoryHelper.sol";

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////
contract AssetFactoryConstructorTest is AssetFactoryHelper {
    function test_assetFactoryConstructor() public view {
        // Check the owner was set correctly
        assertEq(factory.owner(), owner);
    }
}

///////////////////////////////////////////////////////////
///                  IGC FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetFactoryIGCFunctionsTest is AssetFactoryHelper {
    function test_mintIGC() public {
        vm.prank(user1);
        factory.mintIGC(user1, ONE);

        // Check the user1's IGC balance has increased
        assertEq(factory.balanceOf(user1, IGC_TOKEN_ID), ONE);
    }

    function test_mintIGC_RevertsIf_InvalidReceiver() public {
        vm.prank(address(invalidReceiver));

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(invalidReceiver))
        );
        factory.mintIGC(address(invalidReceiver), ONE);
    }
}

///////////////////////////////////////////////////////////
///                 MINT FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetFactoryMintingFunctionsTest is AssetFactoryHelper {
    // User1's IGC balance before minting assets
    uint256 user1StartingIGCBalance;
    // Total price of minting one of asset one, five of asset two, and ten of asset three
    uint256 totalPrice = ASSET_ONE_PRICE + (ASSET_TWO_PRICE * FIVE) + (ASSET_THREE_PRICE * TEN);

    function setUp() public {
        setUpAssets();
        mintInitialIGC(user1, ONE_MILLION);

        user1StartingIGCBalance = factory.balanceOf(user1, IGC_TOKEN_ID);
    }

    function test_mintAsset_One() public {
        vm.prank(user1);
        factory.mintAsset(user1, ASSET_ONE_ID, ONE, "");

        // Check the user1's asset balance has increased
        assertEq(factory.balanceOf(user1, ASSET_ONE_ID), ONE);
        // Check the user1's IGC balance has decreased
        assertEq(factory.balanceOf(user1, IGC_TOKEN_ID), user1StartingIGCBalance - ASSET_ONE_PRICE);
    }

    function test_mintAsset_Two() public {
        vm.prank(user1);
        factory.mintAsset(user1, ASSET_TWO_ID, FIVE, "");

        // Check the user1's asset balance has increased
        assertEq(factory.balanceOf(user1, ASSET_TWO_ID), FIVE);
        // Check the user1's IGC balance has decreased
        assertEq(factory.balanceOf(user1, IGC_TOKEN_ID), user1StartingIGCBalance - (ASSET_TWO_PRICE * FIVE));
    }

    function test_mintAsset_Three() public {
        vm.prank(user1);
        factory.mintAsset(user1, ASSET_THREE_ID, TEN, "");

        // Check the user1's asset balance has increased
        assertEq(factory.balanceOf(user1, ASSET_THREE_ID), TEN);
        // Check the user1's IGC balance has decreased
        assertEq(factory.balanceOf(user1, IGC_TOKEN_ID), user1StartingIGCBalance - (ASSET_THREE_PRICE * TEN));
    }

    function test_mintAsset_EmitsEvent() public {
        vm.prank(user1);

        // Check for the TransferSingle event when minting an asset
        vm.expectEmit(true, false, false, false, address(factory));
        emit IERC1155.TransferSingle(user1, address(0), user1, ASSET_ONE_ID, ONE);
        factory.mintAsset(user1, ASSET_ONE_ID, ONE, "");
    }

    function test_mintAsset_RevertsIf_InsufficientBalance() public {
        vm.prank(user2);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, user2, 0, ASSET_ONE_PRICE, 0)
        );
        factory.mintAsset(user2, ASSET_ONE_ID, ONE, "");

        // Check the user2's IGC balance hasn't changed
        assertEq(factory.balanceOf(user2, IGC_TOKEN_ID), 0);
    }

    function test_mintAsset_RevertsIf_AddressZero() public {
        vm.prank(user1);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        factory.mintAsset(address(0), ASSET_ONE_ID, ONE, "");

        // Check the user1's IGC balance hasn't changed
        assertEq(factory.balanceOf(user1, IGC_TOKEN_ID), ONE_MILLION);
    }

    function test_mintAsset_RevertsIf_InvalidReceiver() public {
        vm.prank(user1);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(invalidReceiver))
        );
        factory.mintAsset(address(invalidReceiver), ASSET_ONE_ID, ONE, "");

        // Check the user1's IGC balance hasn't changed
        assertEq(factory.balanceOf(user1, IGC_TOKEN_ID), ONE_MILLION);
    }

    function test_mintBatch() public {
        vm.prank(user1);
        factory.mintBatch(user1, assetIds, allVarying, "");

        // Check the user1's asset balances have increased
        assertEq(factory.balanceOf(user1, ASSET_ONE_ID), ONE);
        assertEq(factory.balanceOf(user1, ASSET_TWO_ID), FIVE);
        assertEq(factory.balanceOf(user1, ASSET_THREE_ID), TEN);
        // Check the user1's IGC balance has decreased
        assertEq(factory.balanceOf(user1, IGC_TOKEN_ID), user1StartingIGCBalance - totalPrice);
    }

    function test_mintBatch_EmitsEvent() public {
        vm.prank(user1);

        // Check for the TransferBatch event when minting multiple assets
        vm.expectEmit(false, true, false, false, address(factory));
        emit IERC1155.TransferBatch(user1, address(0), user1, assetIds, allVarying);
        factory.mintBatch(user1, assetIds, allVarying, "");
    }

    function test_mintBatch_RevertsIf_InvalidArrayLength() public {
        vm.prank(user1);

        // Check that the function reverts with the ERC1155InvalidArrayLength error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidArrayLength.selector, assetIds.length, invalid.length)
        );
        factory.mintBatch(user1, assetIds, invalid, "");

        // Check the user1's IGC balance hasn't changed
        assertEq(factory.balanceOf(user1, IGC_TOKEN_ID), ONE_MILLION);
    }

    function test_mintBatch_RevertsIf_InsufficientBalance() public {
        vm.prank(user2);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, user2, 0, totalPrice, 0)
        );
        factory.mintBatch(user1, assetIds, allVarying, "");

        // Check the user2's IGC balance hasn't changed
        assertEq(factory.balanceOf(user2, IGC_TOKEN_ID), 0);
    }

    function test_mintBatch_RevertsIf_AddressZero() public {
        vm.prank(user1);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        factory.mintBatch(address(0), assetIds, all, "");

        // Check the user1's IGC balance hasn't changed
        assertEq(factory.balanceOf(user1, IGC_TOKEN_ID), ONE_MILLION);
    }

    function test_mintBatch_RevertsIf_InvalidReceiver() public {
        vm.prank(user1);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(invalidReceiver))
        );
        factory.mintBatch(address(invalidReceiver), assetIds, all, "");

        // Check the user1's IGC balance hasn't changed
        assertEq(factory.balanceOf(user1, IGC_TOKEN_ID), ONE_MILLION);
    }
}

///////////////////////////////////////////////////////////
///                 BURN FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetFactoryBurningFunctionsTest is AssetFactoryHelper {
    // User1's IGC balance after minting assets
    uint256 user1AfterMintingAssetsIGCBalance;

    function setUp() public {
        setUpAssets();
        mintInitialIGC(user1, ONE_MILLION);
        mintInitialAssets(user1, all);

        user1AfterMintingAssetsIGCBalance = factory.balanceOf(user1, IGC_TOKEN_ID);
    }

    function test_burnAsset_Single() public {
        vm.prank(user1);
        factory.burnAsset(user1, ASSET_ONE_ID, ONE);

        // Check the user1's asset balance has decreased
        assertEq(factory.balanceOf(user1, ASSET_ONE_ID), TEN - ONE);
    }

    function test_burnAsset_Multiple() public {
        vm.prank(user1);
        factory.burnAsset(user1, ASSET_TWO_ID, FIVE);

        // Check the user1's asset balance has decreased
        assertEq(factory.balanceOf(user1, ASSET_TWO_ID), TEN - FIVE);
    }

    function test_burnAsset_IGC() public {
        vm.prank(user1);
        factory.burnAsset(user1, IGC_TOKEN_ID, ONE_THOUSAND);

        // Check the user1's IGC balance has decreased
        assertEq(factory.balanceOf(user1, IGC_TOKEN_ID), user1AfterMintingAssetsIGCBalance - ONE_THOUSAND);
    }

    function test_burnAsset_WithApproval() public {
        vm.prank(user1);
        factory.setApprovalForAll(owner, true);

        vm.prank(owner);
        factory.burnAsset(user1, ASSET_ONE_ID, ONE);

        // Check the user1's asset balance has decreased
        assertEq(factory.balanceOf(user1, ASSET_ONE_ID), TEN - ONE);
    }

    function test_burnAsset_EmitsEvent() public {
        vm.prank(user1);

        // Check for the AssetBurnt event when burning an asset
        vm.expectEmit(true, false, false, false, address(factory));
        emit AssetFactory.AssetBurnt(user1, ASSET_ONE_ID, ONE);
        factory.burnAsset(user1, ASSET_ONE_ID, ONE);
    }

    function test_burnAsset_RevertsIf_MissingApprovalForAll() public {
        vm.prank(owner);

        // Check that the function reverts with the ERC1155MissingApproval error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, owner, user1));
        factory.burnAsset(user1, ASSET_ONE_ID, ONE);

        // Check the user1's asset balance hasn't changed
        assertEq(factory.balanceOf(user1, ASSET_ONE_ID), TEN);
    }

    function test_burn_RevertsIf_InsufficientBalance() public {
        vm.prank(user1);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user1, TEN, ONE_THOUSAND, ASSET_ONE_ID
            )
        );
        factory.burnAsset(user1, ASSET_ONE_ID, ONE_THOUSAND);

        // Check the user1's asset balance hasn't changed
        assertEq(factory.balanceOf(user1, ASSET_ONE_ID), TEN);
    }

    function test_burnBatch() public {
        vm.prank(user1);
        factory.burnBatch(user1, assetIds, all);

        // Check the user1's asset balances have decreased
        assertEq(factory.balanceOf(user1, ASSET_ONE_ID), 0);
        assertEq(factory.balanceOf(user1, ASSET_TWO_ID), 0);
        assertEq(factory.balanceOf(user1, ASSET_THREE_ID), 0);
    }

    function test_burnBatch_WithApproval() public {
        vm.prank(user1);
        factory.setApprovalForAll(owner, true);

        vm.prank(owner);
        factory.burnBatch(user1, assetIds, all);

        // Check the user1's asset balances have decreased
        assertEq(factory.balanceOf(user1, ASSET_ONE_ID), 0);
        assertEq(factory.balanceOf(user1, ASSET_TWO_ID), 0);
        assertEq(factory.balanceOf(user1, ASSET_THREE_ID), 0);
    }

    function test_burnBatch_EmitsEvent() public {
        vm.prank(user1);

        // Check for the AssetsBurnt event when burning multiple assets
        vm.expectEmit(false, false, true, false, address(factory));
        emit AssetFactory.AssetsBurnt(user1, assetIds, all);
        factory.burnBatch(user1, assetIds, all);
    }

    function test_burnBatch_RevertsIf_MissingApprovalForAll() public {
        vm.prank(owner);

        // Check that the function reverts with the ERC1155MissingApproval error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, owner, user1));
        factory.burnBatch(user1, assetIds, all);

        // Check the user1's asset balances haven't changed
        assertEq(factory.balanceOf(user1, ASSET_ONE_ID), TEN);
        assertEq(factory.balanceOf(user1, ASSET_TWO_ID), TEN);
        assertEq(factory.balanceOf(user1, ASSET_THREE_ID), TEN);
    }

    function test_burnBatch_RevertsIf_InvalidArrayLength() public {
        vm.prank(user1);

        // Check that the function reverts with the ERC1155InvalidArrayLength error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidArrayLength.selector, assetIds.length, invalid.length)
        );
        factory.burnBatch(user1, assetIds, invalid);

        // Check the user1's asset balances haven't changed
        assertEq(factory.balanceOf(user1, ASSET_ONE_ID), TEN);
        assertEq(factory.balanceOf(user1, ASSET_TWO_ID), TEN);
        assertEq(factory.balanceOf(user1, ASSET_THREE_ID), TEN);
    }

    function test_burnBatch_RevertsIf_InsufficientBalance() public {
        // Change an index to a value that is greater than the user1's balance
        all[0] = ONE_THOUSAND;

        vm.prank(user1);
        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user1, TEN, ONE_THOUSAND, ASSET_ONE_ID
            )
        );
        factory.burnBatch(user1, assetIds, all);

        // Check the user1's asset balances
        assertEq(factory.balanceOf(user1, ASSET_ONE_ID), TEN);
        assertEq(factory.balanceOf(user1, ASSET_TWO_ID), TEN);
        assertEq(factory.balanceOf(user1, ASSET_THREE_ID), TEN);
    }
}

///////////////////////////////////////////////////////////
///               SETTER FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetFactorySetterFunctionsTest is AssetFactoryHelper {
    string newURI = "ipfs://asset1NewURI";

    function test_setAssetURI() public {
        vm.prank(owner);
        factory.setAssetURI(ASSET_ONE_ID, newURI);

        // Check the URI was set correctly
        assertEq(factory.getAssetURI(ASSET_ONE_ID), newURI);
    }

    function test_setAssetURI_EmitsEvent() public {
        vm.prank(owner);

        // Check for the URISet event when setting the new URI
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetFactory.AssetURISet(newURI, ASSET_ONE_ID);
        factory.setAssetURI(ASSET_ONE_ID, newURI);
    }

    function test_setAssetURI_ReverstIf_NotTheOwner() public {
        vm.prank(user1);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
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
        vm.prank(user1);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
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
        vm.prank(user1);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        factory.setAssetData(ASSET_ONE_ID, newURI, ONE_MILLION);
    }
}

///////////////////////////////////////////////////////////
///                 VIEW FUNCTION TESTS                 ///
///////////////////////////////////////////////////////////

contract AssetFactoryViewFunctionsTest is AssetFactoryHelper {
    function test_getAssetUri() public {
        setUpAssets();

        // Check the URI of the asset
        assertEq(factory.getAssetURI(ASSET_ONE_ID), "ipfs://asset1");
    }

    function test_getAssetPrice() public {
        setUpAssets();

        // Check the price of the asset
        assertEq(factory.getAssetPrice(ASSET_ONE_ID), ASSET_ONE_PRICE);
    }
}

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetFactoryERC1155ReceiverTest is AssetFactoryHelper {
    function test_onERC1155Received() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        bytes4 returnedSelector = factory.onERC1155Received(address(0), address(0), 0, 0, "");

        assertEq(returnedSelector, expectedSelector);
    }

    function test_onERC1155BatchReceived() public view {
        bytes4 expectedSelector = bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
        bytes4 returnedSelector =
            factory.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");

        assertEq(returnedSelector, expectedSelector);
    }
}
