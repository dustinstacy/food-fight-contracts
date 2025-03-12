//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { AssetFactory } from "@contracts/AssetFactory.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IERC1155 } from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

///////////////////////////////////////////////////////////
///                      ERRORS                         ///
///////////////////////////////////////////////////////////

/// Emitted when an owner tries to withdraw more funds than the contract balance.
error AssetFactoryWithdrawalExceedsBalance(uint256 amount, uint256 balance);

/// Emitted when an owner tries to withdraw funds from the contract and the transfer fails.
error AssetFactoryWithdrawalFailed(address to, uint256 amount);

///////////////////////////////////////////////////////////
///                     EVENTS                          ///
///////////////////////////////////////////////////////////

/// Emitted when the URI of the metadata for a asset is set.
event AssetURISet(string uri, uint256 id);

/// Emitted when the price of a asset is set.
event AssetPriceSet(uint256 id, uint256 price);

/// Emitted when an assets URI and price are set.
event AssetDataSet(string uri, uint256 id, uint256 price);

/// Emitted when a asset is burnt.
event AssetBurnt(address indexed account, uint256 id, uint256 amount);

/// Emitted when assets are burnt
event AssetsBurnt(address indexed account, uint256[] ids, uint256[] amounts);

/// Emitted when an owner withdraws funds from the contract.
event Withdrawal(address indexed to, uint256 amount);

///////////////////////////////////////////////////////////
///                      HELPERS                        ///
///////////////////////////////////////////////////////////

contract AssetFactorySetupHelper is Test {
    AssetFactory factory;
    address public owner;
    address public user;

    uint256 constant IGC_TOKEN_ID = 0;
    uint256 constant ASSET_ONE_ID = 1;
    uint256 constant ASSET_TWO_ID = 2;
    uint256 constant ASSET_THREE_ID = 3;

    uint256 constant ASSET_ONE_PRICE = 100;
    uint256 constant ASSET_TWO_PRICE = 200;
    uint256 constant ASSET_THREE_PRICE = 300;

    uint256 constant MINT_1 = 1;
    uint256 constant MINT_10 = 10;
    uint256 constant MINT_100 = 100;
    uint256 constant MINT_1000 = 1000;
    uint256 constant MINT_10000 = 10000;
    uint256 constant MINT_100000 = 100000;
    uint256 constant MINT_1000000 = 1000000;

    function setUp() public {
        owner = address(1);
        user = address(2);
        factory = new AssetFactory(owner);
    }
}

/// @dev Helper contract to setup assets for testing
contract AssetFactorySetAssetsHelper is AssetFactorySetupHelper {
    // Set up assets for testing
    // Can update this function to set up more/different assets
    function setUpAssets() public {
        vm.startPrank(owner);
        factory.setAssetData(1, "ipfs://asset1", 100);
        factory.setAssetData(2, "ipfs://asset2", 200);
        factory.setAssetData(3, "ipfs://asset3", 300);
        vm.stopPrank();
    }

    // Mint initial IGC for testing
    function mintInitialIGC(address minter, uint256 amount) public {
        vm.prank(minter);
        factory.mintIGC(minter, amount);
    }

    // Mint initial assets for testing
    function mintInitialAssets(address minter, uint256 amount) public {
        vm.startPrank(minter);
        factory.mintAsset(minter, ASSET_ONE_ID, amount, "");
        factory.mintAsset(minter, ASSET_TWO_ID, amount, "");
        factory.mintAsset(minter, ASSET_THREE_ID, amount, "");
        vm.stopPrank();
    }
}

contract AssetFactoryERC1155InvalidRecieverHelper { }

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////
contract AssetFactoryConstructorTest is AssetFactorySetupHelper {
    function test_constructor() public view {
        // Check the owner was set correctly
        assertEq(factory.owner(), owner);
    }
}

///////////////////////////////////////////////////////////
///                  SET ASSETS TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetFactorySetAssetsTest is AssetFactorySetAssetsHelper {
    function test_setAssetURI_RevertIf_NotTheOwner() public {
        string memory newURI = "ipfs://asset1NewURI";

        vm.prank(user);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.setAssetURI(1, newURI);
    }

    function test_setAssetURI() public {
        string memory newURI = "ipfs://asset1NewURI";

        vm.prank(owner);

        // Check for the URISet event when setting the new URI
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetURISet(newURI, 1);
        factory.setAssetURI(1, newURI);

        // Check the URI was set correctly
        assertEq(factory.getAssetURI(1), newURI);
    }

    function test_setAssetPrice_RevertIf_NotTheOwner() public {
        uint256 newPrice = 1000;

        vm.prank(user);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.setAssetPrice(1, newPrice);
    }

    function test_setAssetPrice() public {
        uint256 newPrice = 1000;

        vm.prank(owner);

        // Check for the AssetPriceSet event when setting the new price
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetPriceSet(1, newPrice);
        factory.setAssetPrice(1, newPrice);

        // Check the price was set correctly
        assertEq(factory.getAssetPrice(1), newPrice);
    }

    function test_setAssetData_RevertIf_NotTheOwner() public {
        string memory newURI = "ipfs://asset1NewURI";
        uint256 newPrice = 1000;

        vm.prank(user);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.setAssetData(1, newURI, newPrice);
    }

    function test_setAssetData() public {
        string memory newURI = "ipfs://asset1NewURI";
        uint256 newPrice = 1000;

        vm.prank(owner);

        // Check for the AssetDataSet event when setting the new URI and price
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetDataSet(newURI, 1, newPrice);
        factory.setAssetData(1, newURI, newPrice);

        // Check the URI and price were set correctly
        assertEq(factory.getAssetURI(1), newURI);
        assertEq(factory.getAssetPrice(1), newPrice);
    }
}

///////////////////////////////////////////////////////////
///                     IGC TESTS                       ///
///////////////////////////////////////////////////////////

contract AssetFactoryIGCTest is AssetFactorySetupHelper {
    function test_mintIGC() public {
        vm.prank(user);
        factory.mintIGC(user, MINT_1000);

        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), MINT_1000);
    }

    function test_mintIGC_RevertIf_InvalidReceiver() public {
        AssetFactoryERC1155InvalidRecieverHelper invalidReceiver = new AssetFactoryERC1155InvalidRecieverHelper();

        vm.prank(address(invalidReceiver));

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(invalidReceiver))
        );
        factory.mintIGC(address(invalidReceiver), MINT_1000);
    }
}

///////////////////////////////////////////////////////////
///                  MINTING TESTS                      ///
///////////////////////////////////////////////////////////

contract AssetFactoryAssetMintingTest is AssetFactorySetAssetsHelper {
    function test_mintAsset1() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000);

        uint256 userIGCBalance = factory.balanceOf(user, IGC_TOKEN_ID);

        vm.prank(user);
        factory.mintAsset(user, ASSET_ONE_ID, MINT_1, "");

        // Check the user's asset balance
        assertEq(factory.balanceOf(user, ASSET_ONE_ID), MINT_1);
        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), userIGCBalance - ASSET_ONE_PRICE);
    }

    function test_mintAsset2() public {
        setUpAssets();
        mintInitialIGC(user, MINT_10000);

        uint256 userIGCBalance = factory.balanceOf(user, IGC_TOKEN_ID);

        vm.prank(user);
        factory.mintAsset(user, ASSET_TWO_ID, MINT_10, "");

        // Check the user's asset balance
        assertEq(factory.balanceOf(user, ASSET_TWO_ID), MINT_10);
        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), userIGCBalance - (ASSET_TWO_PRICE * MINT_10));
    }

    function test_mintAsset3() public {
        setUpAssets();
        mintInitialIGC(user, MINT_100000);

        uint256 userIGCBalance = factory.balanceOf(user, IGC_TOKEN_ID);

        vm.prank(user);
        factory.mintAsset(user, ASSET_THREE_ID, MINT_100, "");

        // Check the user's asset balance
        assertEq(factory.balanceOf(user, ASSET_THREE_ID), MINT_100);
        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), userIGCBalance - (ASSET_THREE_PRICE * MINT_100));
    }

    function test_mintAssetEmitEvent() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000);

        vm.prank(user);

        // Check for the TransferSingle event when minting an asset
        vm.expectEmit(true, false, false, false, address(factory));
        emit IERC1155.TransferSingle(user, address(0), user, ASSET_ONE_ID, MINT_1);
        factory.mintAsset(user, ASSET_ONE_ID, MINT_1, "");
    }

    function test_mintAsset_RevertIf_NotEnoughIGC() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1);

        vm.prank(user);

        // Check that the function reverts with the AssetFactoryNotEnoughIGC error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, user, 1, 100, 0));
        factory.mintAsset(user, ASSET_ONE_ID, MINT_1, "");

        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), MINT_1);
    }

    function test_mintAsset_RevertIf_AddressZero() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000);

        vm.prank(user);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        factory.mintAsset(address(0), ASSET_ONE_ID, MINT_1, "");

        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), MINT_1000);
    }

    function test_mintAsset_RevertIf_InvalidReceiver() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000);

        AssetFactoryERC1155InvalidRecieverHelper invalidReceiver = new AssetFactoryERC1155InvalidRecieverHelper();

        vm.prank(user);

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(invalidReceiver))
        );
        factory.mintAsset(address(invalidReceiver), ASSET_ONE_ID, MINT_1, "");

        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), MINT_1000);
    }

    function test_mintBatch() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000000);

        uint256 userIGCBalance = factory.balanceOf(user, IGC_TOKEN_ID);

        vm.prank(user);

        // Set up arrays for minting multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_1;
        amounts[1] = MINT_10;
        amounts[2] = MINT_100;

        uint256 totalPrice = ASSET_ONE_PRICE + (ASSET_TWO_PRICE * MINT_10) + (ASSET_THREE_PRICE * MINT_100);

        factory.mintBatch(user, assetIds, amounts, "");

        // Check the user's asset balances
        assertEq(factory.balanceOf(user, ASSET_ONE_ID), MINT_1);
        assertEq(factory.balanceOf(user, ASSET_TWO_ID), MINT_10);
        assertEq(factory.balanceOf(user, ASSET_THREE_ID), MINT_100);
        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), userIGCBalance - totalPrice);
    }

    function test_mintBatchEmitEvent() public {
        // Set up assets for testing
        setUpAssets();

        // Mint IGC for the user
        mintInitialIGC(user, MINT_100000);

        // Set user as the caller
        vm.prank(user);

        // Set up arrays for minting multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_1;
        amounts[1] = MINT_10;
        amounts[2] = MINT_100;

        // Check for the TransferBatch event when minting multiple assets
        vm.expectEmit(false, true, false, false, address(factory));
        emit IERC1155.TransferBatch(user, address(0), user, assetIds, amounts);
        factory.mintBatch(user, assetIds, amounts, "");
    }

    function test_mintBatch_RevertIf_ArraysNotSamelength() public {
        setUpAssets();
        mintInitialIGC(user, MINT_100000);

        vm.prank(user);

        // Set up different length arrays for minting multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](2);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_1;
        amounts[1] = MINT_10;

        // Check that the function reverts with the ERC1155InvalidArrayLength error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidArrayLength.selector, assetIds.length, amounts.length)
        );
        factory.mintBatch(user, assetIds, amounts, "");

        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), MINT_100000);
    }

    function test_mintBatch_RevertIf_NotEnoughIGC() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1);

        vm.prank(user);

        // Set up arrays for minting multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_1;
        amounts[1] = MINT_10;
        amounts[2] = MINT_100;

        uint256 totalPrice = ASSET_ONE_PRICE + (ASSET_TWO_PRICE * MINT_10) + (ASSET_THREE_PRICE * MINT_100);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, user, 1, totalPrice, 0)
        );
        factory.mintBatch(user, assetIds, amounts, "");

        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), MINT_1);
    }

    function test_mintBatch_RevertIf_AddressZero() public {
        setUpAssets();
        mintInitialIGC(user, MINT_100000);

        vm.prank(user);

        // Set up arrays for minting multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_1;
        amounts[1] = MINT_10;
        amounts[2] = MINT_100;

        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        factory.mintBatch(address(0), assetIds, amounts, "");

        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), MINT_100000);
    }

    function test_mintBatch_RevertIf_InvalidReceiver() public {
        setUpAssets();
        mintInitialIGC(user, MINT_100000);

        AssetFactoryERC1155InvalidRecieverHelper invalidReceiver = new AssetFactoryERC1155InvalidRecieverHelper();

        // Set up arrays for minting multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_1;
        amounts[1] = MINT_10;
        amounts[2] = MINT_100;

        vm.prank(user);
        // Check that the function reverts with the ERC1155InvalidReceiver error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(invalidReceiver))
        );
        factory.mintBatch(address(invalidReceiver), assetIds, amounts, "");

        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), MINT_100000);
    }
}

///////////////////////////////////////////////////////////
///                  BURNING TESTS                      ///
///////////////////////////////////////////////////////////

contract AssetFactoryAssetBurnTest is AssetFactorySetAssetsHelper {
    function test_burnIGC() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000000);

        vm.prank(user);

        factory.burn(user, IGC_TOKEN_ID, MINT_1000);

        // Check the user's IGC balance
        assertEq(factory.balanceOf(user, IGC_TOKEN_ID), MINT_1000000 - MINT_1000);
    }

    function test_burnAsset() public {
        setUpAssets();
        mintInitialIGC(user, MINT_10000);
        mintInitialAssets(user, MINT_1);

        vm.prank(user);

        factory.burn(user, ASSET_ONE_ID, MINT_1);

        // Check the user's asset balance
        assertEq(factory.balanceOf(user, ASSET_ONE_ID), 0);
    }

    function test_burnMultipleAssets() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000000);
        mintInitialAssets(user, MINT_10);

        vm.prank(user);

        factory.burn(user, ASSET_TWO_ID, MINT_10);

        // Check the user's asset balance
        assertEq(factory.balanceOf(user, ASSET_TWO_ID), 0);
    }

    function test_burn_WithApproval() public {
        setUpAssets();
        mintInitialIGC(user, MINT_100000);
        mintInitialAssets(user, MINT_1);

        vm.prank(user);
        // Set the approval for the user
        factory.setApprovalForAll(owner, true);

        vm.prank(owner);

        factory.burn(user, ASSET_ONE_ID, MINT_1);

        // Check the user's asset balance
        assertEq(factory.balanceOf(user, ASSET_ONE_ID), 0);
    }

    function test_burnEmitEvent() public {
        setUpAssets();
        mintInitialIGC(user, MINT_100000);
        mintInitialAssets(user, MINT_1);

        vm.prank(user);

        // Check for the AssetBurnt event when burning an asset
        vm.expectEmit(true, false, false, false, address(factory));
        emit AssetBurnt(user, ASSET_ONE_ID, MINT_1);
        factory.burn(user, ASSET_ONE_ID, MINT_1);
    }

    function test_burn_RevertIf_MissingApproval() public {
        setUpAssets();
        mintInitialIGC(user, MINT_100000);
        mintInitialAssets(user, MINT_1);

        vm.prank(owner);

        // Check that the function reverts with the ERC1155MissingApproval error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, owner, user));
        factory.burn(user, ASSET_ONE_ID, MINT_1);

        // Check the user's asset balance
        assertEq(factory.balanceOf(user, ASSET_ONE_ID), MINT_1);
    }

    function test_burn_RevertIf_InsufficientBalance() public {
        setUpAssets();
        mintInitialIGC(user, MINT_100000);
        mintInitialAssets(user, MINT_1);

        vm.prank(user);

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user, MINT_1, MINT_10, ASSET_ONE_ID
            )
        );
        factory.burn(user, ASSET_ONE_ID, MINT_10);

        // Check the user's asset balance
        assertEq(factory.balanceOf(user, ASSET_ONE_ID), MINT_1);
    }

    function test_burnBatch() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000000);
        mintInitialAssets(user, MINT_10);

        vm.prank(user);

        // Set up arrays for burning multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_10;
        amounts[1] = MINT_10;
        amounts[2] = MINT_10;

        factory.burnBatch(user, assetIds, amounts);

        // Check the user's asset balances
        assertEq(factory.balanceOf(user, ASSET_ONE_ID), 0);
        assertEq(factory.balanceOf(user, ASSET_TWO_ID), 0);
        assertEq(factory.balanceOf(user, ASSET_THREE_ID), 0);
    }

    function test_burnBatch_WithApproval() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000000);
        mintInitialAssets(user, MINT_10);

        vm.prank(user);
        // Set the approval for the user
        factory.setApprovalForAll(owner, true);

        vm.prank(owner);

        // Set up arrays for burning multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_10;
        amounts[1] = MINT_10;
        amounts[2] = MINT_10;

        factory.burnBatch(user, assetIds, amounts);

        // Check the user's asset balances
        assertEq(factory.balanceOf(user, ASSET_ONE_ID), 0);
        assertEq(factory.balanceOf(user, ASSET_TWO_ID), 0);
        assertEq(factory.balanceOf(user, ASSET_THREE_ID), 0);
    }

    function test_burnBatchEmitEvent() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000000);
        mintInitialAssets(user, MINT_10);

        vm.prank(user);

        // Set up arrays for burning multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_10;
        amounts[1] = MINT_10;
        amounts[2] = MINT_10;

        // Check for the AssetsBurnt event when burning multiple assets
        vm.expectEmit(false, false, true, false, address(factory));
        emit AssetsBurnt(user, assetIds, amounts);
        factory.burnBatch(user, assetIds, amounts);
    }

    function test_burnBatch_RevertIf_MissingApproval() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000000);
        mintInitialAssets(user, MINT_10);

        // Set up arrays for burning multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_10;
        amounts[1] = MINT_10;
        amounts[2] = MINT_10;

        vm.prank(owner);

        // Check that the function reverts with the ERC1155MissingApproval error
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, owner, user));
        factory.burnBatch(user, assetIds, amounts);

        // Check the user's asset balances
        assertEq(factory.balanceOf(user, ASSET_ONE_ID), MINT_10);
        assertEq(factory.balanceOf(user, ASSET_TWO_ID), MINT_10);
        assertEq(factory.balanceOf(user, ASSET_THREE_ID), MINT_10);
    }

    function test_burnBatch_RevertIf_ArraysNotSameLength() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000000);
        mintInitialAssets(user, MINT_10);

        vm.prank(user);

        // Set up arrays for burning multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](2);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_10;
        amounts[1] = MINT_10;

        // Check that the function reverts with the ERC1155InvalidArrayLength error
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidArrayLength.selector, assetIds.length, amounts.length)
        );
        factory.burnBatch(user, assetIds, amounts);

        // Check the user's asset balances
        assertEq(factory.balanceOf(user, ASSET_ONE_ID), MINT_10);
        assertEq(factory.balanceOf(user, ASSET_TWO_ID), MINT_10);
        assertEq(factory.balanceOf(user, ASSET_THREE_ID), MINT_10);
    }

    function test_burnBatch_RevertIf_InsufficientBalance() public {
        setUpAssets();
        mintInitialIGC(user, MINT_1000000);
        mintInitialAssets(user, MINT_10);

        vm.prank(user);

        // Set up arrays for burning multiple assets
        uint256[] memory assetIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        assetIds[0] = ASSET_ONE_ID;
        assetIds[1] = ASSET_TWO_ID;
        assetIds[2] = ASSET_THREE_ID;

        amounts[0] = MINT_10;
        amounts[1] = MINT_10;
        amounts[2] = MINT_100;

        // Check that the function reverts with the ERC1155InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, user, MINT_10, MINT_100, ASSET_THREE_ID
            )
        );
        factory.burnBatch(user, assetIds, amounts);

        // Check the user's asset balances
        assertEq(factory.balanceOf(user, ASSET_ONE_ID), MINT_10);
        assertEq(factory.balanceOf(user, ASSET_TWO_ID), MINT_10);
        assertEq(factory.balanceOf(user, ASSET_THREE_ID), MINT_10);
    }
}

///////////////////////////////////////////////////////////
///                  WITHDRAWAL TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetFactoryWithdrawalTest is Test { }

///////////////////////////////////////////////////////////
///                 VIEW FUNCTIONS TESTS                ///
///////////////////////////////////////////////////////////

contract AssetFactoryViewFunctionsTest is Test { }

///////////////////////////////////////////////////////////
///                ERC1155 RECEIVER TESTS               ///
///////////////////////////////////////////////////////////

contract AssetFactoryERC1155ReceiverTest is Test { }
