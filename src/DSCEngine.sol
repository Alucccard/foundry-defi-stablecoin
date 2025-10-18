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

/////////// imports ///////////
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

////////// interfaces ///////////

////////// libraries ///////////

contract DSCEngine is ReentrancyGuard {
    /////////// errors ///////////
    error DSCEngine_NeedMoreThanZero();
    error DSCEngine_InsufficientCollateral();
    error DSCEngine_TokenAddressesAndPriceFeedAddressesLengthMismatch();
    error DSCEngine_NotAllowedToken(address tokenAddress);
    error DSCEngine_TransferFailed();

    //////////*type declarations*///////////

    ///////////*state variables*///////////
    DecentralizedStableCoin private immutable i_dsc;

    //this is a constant to compute the value of the price feed
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    /*
     *   @param this mapping maps an ERC20 token address to its price feed address
     *   @if the price feed address is 0,then the token is not allowed as collateral
     */
    mapping(address tokenAddress => address priceFeedAddress)
        private s_priceFeeds;
    /*
     *   @param this mapping maps a user address to a mapping of collateral token addresses to the amount of collateral deposited
     */
    mapping(address userAdddress => mapping(address collateralTokenAddress => uint256 amountCollateral))
        private s_collateralDeposited;
    /*
     *   @param this mapping maps a user address to the amount of DSC minted by the user
     */
    mapping(address userAddress => uint256 amountDSCMinted) private s_DSCMinted;

    /*
     *   @param this array keeps track of all the collateral token addresses allowed
     */
    address[] private s_collateralTokens;

    //////////////*events*/////////////
    event CollateralDeposited(
        address indexed user,
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

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine_TokenAddressesAndPriceFeedAddressesLengthMismatch();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /////////*receive & fallback functions*///////////

    ///////////*external functions*/////////////
    function depositCollateralAndMintDsc() external payable {}

    /*
     *   @param tokenCollateralAddress The address of the token to deposit as collateral
     *   @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        external
        payable
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;
        emit CollateralDeposited(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );
        bool success = ERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!success) {
            revert DSCEngine_TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    //mint数量需要<=抵押物价值*抵押率
    /*
     * @notice follows CEI
     */
    function mintDsc(
        uint256 amountDSCToMint
    ) external moreThanZero(amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCToMint;

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view returns (uint256) {}

    ///////////*public functions*/////////////s
    function getAccountCollateralValue(
        address userAddress
    ) public view returns (uint256 totalCollateralValueInUsd) {
        //iterate through each collateral token the user has deposited
        //calculate the value of each token and sum them up
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address tokenAddress = s_collateralTokens[i];
            uint256 amountCollateral = s_collateralDeposited[userAddress][
                tokenAddress
            ];
            totalCollateralValueInUsd += getUsdValue(
                tokenAddress,
                amountCollateral
            );
        }
    }

    function getUsdValue(
        address tokenAddress,
        uint256 amountToken
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[tokenAddress]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            ((uint256(price) * amountToken) / ADDITIONAL_FEED_PRECISION) /
            PRECISION;
    }

    ///////////*internal functions*/////////////
    function _revertIfHealthFactorIsBroken(address useraddress) internal view {
        //计算用户的health factor
        //如果低于最小值，revert
    }

    ///////////*private functions*/////////////
    //get total DSC minted and collateral value in USD for a user, used to calculate health factor
    function __getAccountInformation(
        address userAddress
    )
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
        (
            uint256 totalDscMinted,
            uint256 totalCollateralValueInUsd
        ) = _getAccountInformation(userAddress);
    }
}
