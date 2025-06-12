// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PriceOracle is Ownable {
    error PriceOracle__PriceIsZero();

    AggregatorV3Interface private immutable i_priceFeed;

    constructor(address priceFeed) Ownable(msg.sender) {
        i_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = i_priceFeed.latestRoundData();
        if (price <= 0) {
            revert PriceOracle__PriceIsZero();
        }
        return uint256(price);
    }

    function convertoUsd(uint256 amountInUsdc) external view returns (uint256) {
        uint256 price = getLatestPrice();
        return (amountInUsdc * price) / 1e6; // 1e6 is the decimals of the USDC token
    }

}