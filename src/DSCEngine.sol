// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts

// Layout of Contract Elements:
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functionsd

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure function

pragma solidity 0.8.19;
//looks like DSCEngine is the core logic contract for the stablecoin

contract DSCEngine {
    function depositCollateralAndMintDsc() external payable {}
    function redeemCollateralForDsc() external {}
    function burnDsc() external {}
}
