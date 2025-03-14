//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AssetRental } from "@contracts/AssetRental.sol";
import { AssetFactoryHelper } from "./AssetFactoryHelper.sol";

contract AssetRentalHelper is AssetFactoryHelper {
    // Create an instance of the AssetRental contract that all tests will use
    AssetRental rental = new AssetRental(address(factory));

    // Create uint256 conversion of RentalStatus enum
    uint256 availableStatus = uint256(AssetRental.RentalStatus.Available);
    uint256 rentedStatus = uint256(AssetRental.RentalStatus.Rented);
    uint256 removedStatus = uint256(AssetRental.RentalStatus.Removed);

    function setUp() public virtual {
        setAssetsHelper();
        mintIGCHelper(user1, ONE_MILLION);
        mintIGCHelper(user2, ONE_MILLION);
        mintAssetHelper(user1, all);
    }

    function createRentalHelper() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(rental), true);
        rental.createRental(ASSET_ONE_ID, TEN, ONE, ONE_HOUR, ONE_HOUR);
        vm.stopPrank();
    }

    function rentAssetHelper(address user, uint256 tokenId) public {
        vm.prank(user);
        rental.rentAsset(tokenId);
    }
}
