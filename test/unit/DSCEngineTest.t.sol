// SPDX-License-Identifier: MIT

// Layout of Script:
// version
pragma solidity ^0.8.19;

// imports
import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

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

//////////*imports*///////////

//////////*interfaces*///////////

//////////*libraries*///////////

/////////*contracts*///////////
contract DSCEngineTest is Test {
    //DeployDSC script to deploy DSC and DSCEngine
    DeployDSC deployer;
    //the contracts to be tested
    DecentralizedStableCoin dSC;
    DSCEngine dSCEngine;
    HelperConfig helperConfig;
    address wethUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    //setup function to deploy the contracts

    /////////*errors*///////////

    /////////*Type declarations*///////////

    //////////*State variables*///////////

    /////////*Events*///////////

    /////////*Modifiers*///////////

    ///////////*Functions*///////////
    function setUp() public {
        deployer = new DeployDSC();
        (dSC, dSCEngine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, weth,,,) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsdValue = 30000e18;
        uint256 actualUsdValue = dSCEngine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsdValue, actualUsdValue);
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dSCEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine_NeedMoreThanZero.selector);
        dSCEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    //////////*constructor*///////////

    /////////*receive function*///////////

    /////////*fallback function*///////////

    /////////*external function*///////////

    /////////*public function*///////////

    /////////*internal function*///////////

    /////////*private function*///////////
}
