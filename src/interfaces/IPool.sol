pragma solidity ^0.8.0;

interface IWhitelistedPool{
    function addToWhitelist(address _address) external;
    function removeFromWhitelist(address _address) external;
    function transferTokens(address _to, uint256 _amount) external;
    function transferEth(address payable _to, uint256 _amount) external;
    function withdrawTokens(address _to, uint256 _amount) external;
    function withdrawETH(address payable _to, uint256 _amount) external;
    function whitelist(address _address) external view returns(bool);
}