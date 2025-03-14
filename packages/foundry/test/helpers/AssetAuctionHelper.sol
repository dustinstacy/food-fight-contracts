//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AssetAuction } from "@contracts/AssetAuction.sol";
import { AssetFactoryHelper } from "./AssetFactoryHelper.sol";

contract AssetAuctionHelper is AssetFactoryHelper {
    // Create an instance of the AssetAuction contract that all tests will use
    AssetAuction auction = new AssetAuction(address(factory));

    // Create uint256 conversion of AuctionStatus enum
    uint256 openStatus = uint256(AssetAuction.AuctionStatus.Open);
    uint256 canceledStatus = uint256(AssetAuction.AuctionStatus.Canceled);
    uint256 endedStatus = uint256(AssetAuction.AuctionStatus.Ended);
    uint256 reserveNotMetStatus = uint256(AssetAuction.AuctionStatus.ReserveNotMet);
    uint256 claimedStatus = uint256(AssetAuction.AuctionStatus.Claimed);

    // Create uint256 conversion of Style enum
    uint256 englishStyle = uint256(AssetAuction.Style.English);
    uint256 dutchStyle = uint256(AssetAuction.Style.Dutch);
    uint256 blindStyle = uint256(AssetAuction.Style.Blind);
    uint256 candleStyle = uint256(AssetAuction.Style.Candle);

    uint256 constant ONE_HOUR = 3600;

    // Set up the testing environment using the AssetFactoryHelper functions
    function setUp() public virtual {
        setUpAssets();
        mintInitialIGC(user1, ONE_MILLION);
        mintInitialIGC(user2, ONE_MILLION);
        mintInitialIGC(user3, ONE_MILLION);
        mintInitialAssets(user1, all);
    }

    function createAuction() public {
        vm.startPrank(user1);
        factory.setApprovalForAll(address(auction), true);
        auction.createAuction(ASSET_ONE_ID, TEN, ONE_HOUR, AssetAuction.Style.English);
        vm.stopPrank();
    }
}
