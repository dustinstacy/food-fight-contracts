//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { AssetFactory } from "@contracts/AssetFactory.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

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

/// Emitted when an owner withdraws funds from the contract.
event Withdrawal(address indexed to, uint256 amount);

///////////////////////////////////////////////////////////
///                      HELPERS                        ///
///////////////////////////////////////////////////////////

/// @dev Helper contract to setup assets for testing
contract AssetFactorySetAssetsHelper is Test { }

///////////////////////////////////////////////////////////
///                 CONSTRUCTOR TESTS                   ///
///////////////////////////////////////////////////////////
contract AssetFactoryConstructorTest is Test {
    AssetFactory factory;
    address public owner;

    function setUp() public {
        owner = address(1);
        factory = new AssetFactory(owner);
    }

    function test_constructor() public view {
        // Check the owner was set correctly
        assertEq(factory.owner(), owner);
    }
}

///////////////////////////////////////////////////////////
///                  SET ASSETS TESTS                   ///
///////////////////////////////////////////////////////////

contract AssetFactorySetAssetsTest is Test {
    AssetFactory factory;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(1);
        user = address(2);
        factory = new AssetFactory(owner);
    }

    function test_setAssetURI_RevertIf_NotTheOwner() public {
        // Store new URI
        string memory newURI = "ipfs://asset1NewURI";

        // Set user as the caller
        vm.prank(user);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.setAssetURI(1, newURI);
    }

    function test_setAssetURI() public {
        // Store new URI
        string memory newURI = "ipfs://asset1NewURI";

        // Set owner as the caller
        vm.prank(owner);

        // Check for the URISet event when setting the new URI
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetURISet(newURI, 1);
        factory.setAssetURI(1, newURI);

        // Check the URI was set correctly
        assertEq(factory.getAssetURI(1), newURI);
    }

    function test_setAssetPrice_RevertIf_NotTheOwner() public {
        // Store new price
        uint256 newPrice = 1000;

        // Set user as the caller
        vm.prank(user);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.setAssetPrice(1, newPrice);
    }

    function test_setAssetPrice() public {
        // Store new price
        uint256 newPrice = 1000;

        // Set owner as the caller
        vm.prank(owner);

        // Check for the AssetPriceSet event when setting the new price
        vm.expectEmit(false, false, false, false, address(factory));
        emit AssetPriceSet(1, newPrice);
        factory.setAssetPrice(1, newPrice);

        // Check the price was set correctly
        assertEq(factory.getAssetPrice(1), newPrice);
    }

    function test_setAssetData_RevertIf_NotTheOwner() public {
        // Store new URI and price
        string memory newURI = "ipfs://asset1NewURI";
        uint256 newPrice = 1000;

        // Set user as the caller
        vm.prank(user);

        // Check that the function reverts with the OwnableUnauthorizedAccount error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.setAssetData(1, newURI, newPrice);
    }

    function test_setAssetData() public {
        // Store new URI and price
        string memory newURI = "ipfs://asset1NewURI";
        uint256 newPrice = 1000;

        // Set owner as the caller
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

contract AssetFactoryIGCTest is Test { }

///////////////////////////////////////////////////////////
///                  MINTING TESTS                      ///
///////////////////////////////////////////////////////////

contract AssetFactoryAssetMintingTest is Test { }

///////////////////////////////////////////////////////////
///                  BURNING TESTS                      ///
///////////////////////////////////////////////////////////

contract AssetFactoryAssetBurnTest is Test { }

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
