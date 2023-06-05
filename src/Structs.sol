// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct WagerDetails{
    uint256 wagerId;
    address player;
    address wagerToken;
    address asset;
    uint256 amount;
    uint256 priceOption;
    uint256 closingPrice;
    uint256 payout;
    uint256 startedAt;
    uint256 endsOn;
    bool position;
    bool isSettled;
    bool isCancelled;
}

struct TokenDetails{
    address tokenAddress;
    uint256 maxBetAmount;
    uint256 minBetAmount;
}