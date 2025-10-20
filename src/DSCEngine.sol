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

pragma solidity ^0.8.19;
//looks like DSCEngine is the core logic contract for the stablecoin

///////////*imports*///////////
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// Minimal ReentrancyGuard replacement to avoid external import resolution issues.

///////////*interfaces*///////////

//////////*libraries*///////////

/////////*contracts*///////////
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) {
            revert("ReentrancyGuard: reentrant call");
        }
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract DSCEngine is ReentrancyGuard {
    ///////////*errors*///////////
    error DSCEngine_NeedMoreThanZero();
    error DSCEngine_InsufficientCollateral();
    error DSCEngine_TokenAddressesAndPriceFeedAddressesLengthMismatch();
    error DSCEngine_NotAllowedToken(address tokenAddress);
    error DSCEngine_TransferFailed();
    error DSCEngine_HealthFactorBroken(uint256 healthFactor);
    error DSCEngine_MintFailed();
    error DSCEngine_HealthFactorNotBroken(uint256 healthFactor);
    error DSCEngine_HealthFactorNotImproved(uint256 healthFactor);

    //////////*type declarations*///////////

    ///////////*state variables*///////////
    DecentralizedStableCoin private immutable i_DSC;

    //this is a constant to compute the value of the price feed
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // it means your collateral must be at least 200% of the DSC minted
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10; //this means a 10% bonus to liquidators
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    /*
     *   @param this mapping maps an ERC20 token address to its price feed address
     *   @if the price feed address is 0,then the token is not allowed as collateral
     */
    mapping(address tokenAddress => address priceFeedAddress) private s_priceFeeds;
    /*
     *   @param this mapping maps a user address to a mapping of collateral token addresses to the amount of collateral deposited
     */
    mapping(address userAddress => mapping(address collateralTokenAddress => uint256 amountCollateral)) private
        s_collateralDeposited;
    /*
     *   @param this mapping maps a user address to the amount of DSC minted by the user
     */
    mapping(address userAddress => uint256 amountDSCMinted) private s_DSCMinted;

    /*
     *   @param this array keeps track of all the collateral token addresses allowed
     */
    address[] private s_collateralTokens;

    //////////////*events*/////////////
    event CollateralDeposited(address indexed user, address indexed tokenCollateralAddress, uint256 amountCollateral);
    event CollateralRedeemed(
        address indexed userRedeemFrom,
        address indexed userRedeemTo,
        address indexed tokenCollateralAddress,
        uint256 amountCollateral
    );

    ///////////*modifiers*/////////////

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

    ///////////*functions*/////////////

    //////////*constructor*///////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address DSCAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine_TokenAddressesAndPriceFeedAddressesLengthMismatch();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_DSC = DecentralizedStableCoin(DSCAddress);
    }

    /////////*receive & fallback functions*///////////

    ///////////*external functions*/////////////

    /// @notice Deposits collateral and mints DSC simultaneously, give user a single function to interact with
    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDSCToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDSCToMint);
    }

    /// @param tokenCollateralAddress The address of the token to deposit as collateral
    /// @param amountCollateral The amount of collateral to deposit
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
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

    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDSCToBurn)
        external
        moreThanZero(amountCollateral)
        nonReentrant
    {
        burnDSC(amountDSCToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    /// @notice Redeems collateral, not burning any DSC, user must have enough collateral after redemption to maintain min health factor
    /// @param tokenCollateralAddress The address of the token to redeem as collateral
    /// @param amountCollateral The amount of collateral to redeem
    /// @dev need to let the third person call this function, if the user is undercollateralized
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    //mint数量需要<=抵押物价值*抵押率
    /*
     * @notice follows CEI
     */
    function mintDSC(uint256 amountDSCToMint) public moreThanZero(amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCToMint;

        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_DSC.mint(msg.sender, amountDSCToMint);
        if (!minted) {
            revert DSCEngine_MintFailed();
        }
    }

    function burnDSC(uint256 amountDSCToburn) public moreThanZero(amountDSCToburn) nonReentrant {
        _burnDSC(msg.sender, msg.sender, amountDSCToburn);
    }

    /**
     * @param collateral The address of the collateral token
     * @param user The address of the user to liquidate
     * @param debtToCover The amount of debt to cover
     * @notice liquidates the user's collateral if their health factor is below the minimum
     * @notice the user who calls this function will receive a discount on the collateral, as an incentive
     * @notice follows CEI
     * @dev there is a question here: how to trigger the liquidation? periodically?
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine_HealthFactorNotBroken(userHealthFactor);
        }

        // Calculate the amount of collateral to liquidate
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        //caculate the bonus for the liquidator
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        //totalCollateralToRedeem is the sum of the tokenAmountFromDebtCovered and the bonusCollateral
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        _burnDSC(msg.sender, user, debtToCover);

        uint256 endingHealthFactor = _healthFactor(user);
        if (endingHealthFactor <= userHealthFactor) {
            revert DSCEngine_HealthFactorNotImproved(endingHealthFactor);
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view returns (uint256) {}

    ///////////*public functions*/////////////s
    function getAccountCollateralValue(address userAddress) public view returns (uint256 totalCollateralValueInUsd) {
        //iterate through each collateral token the user has deposited
        //calculate the value of each token and sum them up
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address tokenAddress = s_collateralTokens[i];
            uint256 amountCollateral = s_collateralDeposited[userAddress][tokenAddress];
            totalCollateralValueInUsd += getUsdValue(tokenAddress, amountCollateral);
        }
    }

    function getUsdValue(address tokenAddress, uint256 amountToken) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[tokenAddress]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        //addtional precision is 1e10 to make price 18 decimals, price feed has 8 decimals
        //precision is 1e18 to make amountToken 18 decimals
        return (uint256(price) * ADDITIONAL_FEED_PRECISION / PRECISION * amountToken);
    }

    function getTokenAmountFromUsd(address tokenAddress, uint256 usdAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[tokenAddress]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        //additional precision is 1e10 to make price 18 decimals, price feed has 8 decimals
        //usdAmount is in 18 decimals
        return (usdAmount * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    ///////////*internal functions*/////////////
    function _revertIfHealthFactorIsBroken(address userAddress) internal view {
        //calculate the user's health factor
        //if it is lower than health factor,revert
        uint256 healthFactor = _healthFactor(userAddress);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine_HealthFactorBroken(healthFactor);
        }
    }

    ///////////*private functions*/////////////
    //get total DSC minted and collateral value in USD for a user, used to calculate health factor
    function _getAccountInformation(address userAddress)
        private
        view
        returns (uint256 totalDSCMinted, uint256 totalCollateralValueInUsd)
    {
        //计算用户铸造的DSC总量
        totalDSCMinted = s_DSCMinted[userAddress];
        //计算用户抵押品的总价值(以USD计价)
        totalCollateralValueInUsd = getAccountCollateralValue(userAddress);
    }

    //caculate the user's health factor
    function _healthFactor(address userAddress) private view returns (uint256) {
        (uint256 totalDSCMinted, uint256 totalCollateralValueInUsd) = _getAccountInformation(userAddress);
        uint256 collateralAdjustedForThreshold =
            (totalCollateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return ((collateralAdjustedForThreshold * PRECISION) / totalDSCMinted);
    }

    function _redeemCollateral(
        address userRedeemFrom,
        address userRedeemTo,
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) private moreThanZero(amountCollateral) nonReentrant {
        s_collateralDeposited[userRedeemFrom][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(userRedeemFrom, userRedeemTo, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(userRedeemTo, amountCollateral);
        if (!success) {
            revert DSCEngine_TransferFailed();
        }

        _revertIfHealthFactorIsBroken(userRedeemFrom);
    }

    /// @notice burns DSC from the user, and reduces the liquidated user's minted DSC
    function _burnDSC(address userDSCProvider, address userToBurn, uint256 amountDSCToburn)
        private
        moreThanZero(amountDSCToburn)
        nonReentrant
    {
        s_DSCMinted[userToBurn] -= amountDSCToburn;
        bool burnedResult = i_DSC.transferFrom(userDSCProvider, address(this), amountDSCToburn);
        if (!burnedResult) {
            revert DSCEngine_TransferFailed();
        }
        i_DSC.burn(amountDSCToburn);
    }
}
