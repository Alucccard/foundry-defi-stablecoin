// SPDX-License-Identifier: MIT

// Layout of Script:
// version
// imports
// interfaces, libraries, contracts

// Layout of Contract Elements:
// errors
// Type declarations
// State variables
// Events
// Modifiers

// Functions
// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure function

//////////*version*///////////
pragma solidity ^0.8.19;

//////////*imports*///////////
import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

//////////*interfaces*///////////

//////////*libraries*///////////

/////////*contracts*///////////
contract DeployDSC is Script {
    address[] public tokenAddress;
    address[] public priceFeedAddress;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (address wethUsdPriceFeed, address weth, address wbtcUsdPriceFeed, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        tokenAddress = [weth, wbtc];
        priceFeedAddress = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast();
        DecentralizedStableCoin dSC = new DecentralizedStableCoin();
        DSCEngine dSCEngine = new DSCEngine(tokenAddress, priceFeedAddress, address(dSC));
        vm.stopBroadcast();
        return (dSC, dSCEngine, helperConfig);
    }
}

/////////*errors*///////////

/////////*Type declarations*///////////

//////////*State variables*///////////

/////////*Events*///////////

/////////*Modifiers*///////////

///////////*Functions*///////////

//////////*constructor*///////////

/////////*receive function*///////////

/////////*fallback function*///////////

/////////*external function*///////////

/////////*public function*///////////

/////////*internal function*///////////

/////////*private function*///////////
