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
// Function

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

///////////imports///////////
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//////////interfaces///////////

//////////libraries///////////

contract DSCEngine is ReentrancyGuard {
    ///////////errors///////////
    error DSCEngine_NeedMoreThanZero();
    error DSCEngine_InsufficientCollateral();
    error DSCEngine_TokenAddressesAndPriceFeedAddressesLengthMismatch();
    error DSCEngine_NotAllowedToken(address tokenAddress);
    error DSCEngine_TransferFailed();

    //////////type declarations///////////

    ///////////state variables///////////
    DecentralizedStableCoin private immutable i_dsc;

    /*
    *   @param this mapping maps an ERC20 token address to its price feed address
    *   @if the price feed address is 0,then the token is not allowed as collateral
    */
    mapping(address tokenAddress => address priceFeedAddress) private s_priceFeeds;
    mapping(address userAdddress => mapping(address collateralTokenAddress => uint256 amountCollateral)) private
        s_collateralDeposited;

    //////////////events///////////
    event CollateralDeposited(address indexed user, address indexed tokenCollateralAddress, uint256 amountCollateral);

    ///////////modifiers///////////
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine_NeedMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert DSCEngine_NotAllowedToken(tokenAddress);
        }
        _;
    }

    ///////////functions///////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine_TokenAddressesAndPriceFeedAddressesLengthMismatch();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////external functions///////////
    function depositCollateralAndMintDsc() external payable {}

    /*
    *   @param tokenCollateralAddress The address of the token to deposit as collateral
    *   @param amountCollateral The amount of collateral to deposit
    */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        payable
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = ERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine_TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view returns (uint256) {}
}
