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

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin

/*
* @Decentralized Stable Coin (DSC)
* @author Alucccard gloomwing
* @Collateral: Exogenous Crypto Assets(e.g., ETH, BTC, etc.)
* @Pegged to: USD
* @Volatility: Low
*/

contract DecentralizedStableCoin is ERC20Burnable {
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance(uint256 balance, uint256 burnAmount);
    error DecentralizedStableCoin__MintToZeroAddress();
    //ERC20Burnable is ERC20,so constructor of ERC20 needs to be called

    constructor() ERC20("Decentralized Stable Coin", "DSC") {}

    //onlyOwner is a modifier from Ownable.sol?
    //owner can burn tokens
    function burn(uint256 _amount) override publick onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance(balance, _amount);
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (_to == address(0)) {
            revert DecentralizedStableCoin__MintToZeroAddress();
        }
        _mint(_to, _amount);
    }
}
