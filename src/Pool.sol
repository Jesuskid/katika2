// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract WhitelistedPool {
    address public owner;
    IERC20 public token;
    mapping(address => bool) public whitelist;

    event TokenTransferred(address indexed from, address indexed to, uint256 amount);

    constructor(address _token) {
        owner = msg.sender;
        token = IERC20(_token);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "Only whitelisted addresses can call this function");
        _;
    }

    function addToWhitelist(address _address) external onlyOwner {
        whitelist[_address] = true;
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        whitelist[_address] = false;
    }

    function transferTokens(address _to, uint256 _amount) external onlyWhitelisted{
        require(whitelist[_to], "Recipient is not whitelisted");
        require(token.transferFrom(msg.sender, _to, _amount), "Token transfer failed");
        emit TokenTransferred(msg.sender, _to, _amount);
    }

    function transferEth(address payable _to, uint256 _amount) external onlyWhitelisted {
        require(whitelist[_to], "Recipient is not whitelisted");
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function withdrawTokens(address _to, uint256 _amount) external onlyOwner {
        require(token.transfer(_to, _amount), "Token transfer failed");
        emit TokenTransferred(address(this), _to, _amount);
    }

    function withdrawETH(address payable _to, uint256 _amount) external onlyOwner {
        _to.transfer(_amount);
    }

    receive() external payable {}
}


