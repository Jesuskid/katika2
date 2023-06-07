// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {WagerDetails} from "../Structs.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWhitelistedPool} from "../interfaces/IPool.sol";
import "@chainlink/v0.6/interfaces/AggregatorV3Interface.sol";

contract Wager {
    using SafeERC20 for IERC20;
    WhitelistedPool public pool;
    

    mapping(address => Structs.TokenDetails) public tokenDetails;
    mapping(wagerId => Structs.WagerDetails) public wagerDetails;
    mapping(address=>mapping(address=>uint256)) public userBalances;

    uint256 public multiplier = 1.2e18;

    mapping(address  token => address priceFeed) public priceFeeds;

    uint256 public wagerId;

    enum Position {SHORT, LONG}

    event WagerCreated(uint256 wagerId, address indexed player, address wagerToken, address assetPairLink);
    event WagerSettled(uint256 wagerId, address indexed player, address wagerToken, address assetPairLink);
    event WagerCancelled(uint256 wagerId, uint256 penalty, address indexed player, address wagerToken, address assetPairLink);
    event WagerWithdrawn(uint256 wagerId, address indexed player, address wagerToken, address assetPairLink);
    event Deposit(address indexed sender, address indexed token, uint256 amount);
    event Withdraw(address indexed sender, address indexed token, uint256 amount);

    
    modifier isValidToken(address token) {
        require(tokenDetails[token].tokenAddress != address(0), "Token not added");
        _;
    }

    modifier onlyPlayer(uint256 wagerId_) {
        require(wagerDetails[wagerId_].player == msg.sender, "Not player");
        _;
    }


    function deposit(address token, uint256 amount_) public isValidToken(token) {
        IERC20(token).safeTransferFrom(msg.sender, pool, amount_);
        userBalances[msg.sender][token] += amount_;
        emit Deposit(msg.sender, token, amount_);
    }

    function withdraw(address token, uint256 amount_) public isValidToken(token){
        require(userBalances[msg.sender][token] >= amount_, "Insufficient balance");
        IERC20(token).safeTransferFrom(pool, msg.sender, amount_);
        userBalances[msg.sender][token] -= amount_;
        emit Withdraw(msg.sender, token, amount_);
    }
    

    function wager(address token, address wagerAsset, uint256 amount_, uint8 position_, uint256 endsIn_) public isValidPricePair(wagerAsset) isValidToken(token) {
        require(endsIn >= tokenDetails[token].minBetAmount && endsIn <= tokenDetails[token].maxBetAmount , "Invalid bet amount");
        require(position_ == 0 || position_ == 1, "Invalid position");
        //transfer token to pool
        require(userBalances[msg.sender][token] >= amount_, "Insufficient balance");

        (,int price,,,) = getLatestPrice(wagerPair);
        uint256 wagerId_ = ++wagerId;
        wagerDetails[wagerId_] = WagerDetails({
            wagerId: wagerId_,
            player: msg.sender,
            wagerToken: token,
            asset: wagerAsset,
            amount: amount_,
            priceOption: uint256(price),
            closingPrice: 0,
            payout: 0,
            startedAt: block.timestamp,
            endsOn: block.timestamp + endsIn_,
            position: position_,
            isSettled: false,
            isCancelled: false
        });
        emit WagerCreated(wagerId_, msg.sender, token, wagerAsset);
    }


    function settle(uint256 wagerId_) public {
        WagerDetails storage wager = wagerDetails[wagerId_];
        require(wager.isSettled == false, "Wager already settled");
        require(wager.isCancelled == false, "Wager already cancelled");
        require(wager.endsOn <= block.timestamp, "Wager not ended yet");

        (,int price,,,) = getLatestPrice(priceFeeds[wager.asset]);

        wager.closingPrice = uint256(price);
        wager.isSettled = true;

        if(wager.position == SHORT){
            if(wager.priceOption < uint256(price)){
                uint256 payout = (wager.amount * multiplier) / 1e18;
                wager.payout = payout;
                pool.transfer(wager.wagerToken, msg.sender, payout);
            }else{
                wager.payout = 0;
            }
        }else if(wager.position == LONG){
            if(wager.priceOption > uint256(price)){
                uint256 payout = (wager.amount * multiplier) / 1e18;
                wager.payout = payout;
                //payfrom pool
                pool.transfer(wager.wagerToken, msg.sender, payout);
            }else{
                wager.payout = 0;
            }
        }
        emit WagerSettled(wagerId_, msg.sender, wager.wagerToken, wager.asset);
    }


    function cancel() public onlyPlayer(wagerId_) {
        WagerDetails storage wager = wagerDetails[wagerId_];
        require(wager.isSettled == false, "Wager already settled");
        require(wager.isCancelled == false, "Wager already cancelled");
        require(wager.endsOn > block.timestamp, "Wager already ended");
        wager.isCancelled = true;
        uint256 timeLeft = wager.endsOn - block.timestamp;
        //check timeleft is not more than 80% of wager time
        require(timeLeft <= (wager.endsOn * 8000) / 10000, "Cannot cancel wager");
        //penalty
        uint256 penalty = wager.amount * timeLeft / wager.endsOn;
        //payfrom pool
        uint256 amount = wager.amount - penalty;
        pool.transfer(wager.wagerToken, msg.sender, amount);

        emit WagerCancelled(wagerId_, penalty, msg.sender, wager.wagerToken, wager.asset);
    }


     function getLatestPrice(address assetPair) public view returns (int) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(assetPair);
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
     }

     //
    function addToken(address token, uint256 minBetAmount_, uint256 maxBetAmount_) public onlyOwner {
        require(tokenDetails[token].tokenAddress == address(0), "Token already added");
        require(minBetAmount_ > 0 && maxBetAmount_ > minBetAmount_, "Invalid min bet amount");
        tokenDetails[token] = TokenDetails({
            tokenAddress: token,
            minBetAmount: minBetAmount_,
            maxBetAmount: maxBetAmount_
        });
    }

    function updateToken(address token, uint256 minBetAmount_, uint256 maxBetAmount_) public onlyOwner {
        require(tokenDetails[token].tokenAddress != address(0), "Token not added");
        require(minBetAmount_ > 0 && maxBetAmount_ > minBetAmount_, "Invalid min bet amount");
        tokenDetails[token].minBetAmount = minBetAmount_;
        tokenDetails[token].maxBetAmount = maxBetAmount_;
    }

    function removeToken(address token) public onlyOwner {
        require(tokenDetails[token].tokenAddress != address(0), "Token not added");
        delete tokenDetails[token];
    }


    function addPricePair(address token, address priceFeed_) public onlyOwner {
        require(pricePairs[token] == address(0), "Price pair already added");
        pricePairs[token] = priceFeed_;
    }

    function removePricePair(address token, address priceFeed_) public onlyOwner {
        require(pricePairs[token] != address(0), "Price pair not added");
        delete pricePairs[token];
    }

    modifier isValidPricePair(address assetPair) {
        require(pricePairs[token] != address(0), "Price pair not added");
        _;
    }
}
