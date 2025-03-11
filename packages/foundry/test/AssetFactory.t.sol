//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { AssetFactory } from "@contracts/AssetFactory.sol";

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

contract AssetFactorySetAssetsTest is Test { }

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
