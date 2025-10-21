// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/////////*imports*/////////
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @dev Returns the latest price of the asset from the oracle.
 * @notice This function retrieves the latest price of the specified asset from the oracle.
 */

/////////*library*/////////
library OracleLib {
    /////////*errors*/////////
    error OracleLib_StalePrice();

    /////////*state variables*/////////
    uint256 private constant TIMEOUT = 3 hours;

    /////////*functions*/////////
    function staleCheckLastestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        //check if the price is stale
        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib_StalePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
