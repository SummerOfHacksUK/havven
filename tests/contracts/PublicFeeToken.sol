pragma solidity ^0.4.23;

import "contracts/FeeToken.sol";

contract PublicFeeToken is FeeToken {
    constructor(string _name, string _symbol, uint _transferFeeRate, address _feeAuthority,
                address _owner)
        FeeToken(_name, _symbol, 0, _transferFeeRate, _feeAuthority, _owner)
        public
    {}

    function transfer(address to, uint value)
        external
    {
        _transfer(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint value)
        external
    {
        _transferFrom(msg.sender, from, to, value);
    }

    function transferSenderPaysFee(address to, uint value)
        external
    {
        _transferSenderPaysFee(msg.sender, to, value);
    }

    function transferFromSenderPaysFee(address from, address to, uint value)
        external
    {
        _transferFromSenderPaysFee(msg.sender, from, to, value);
    }

    function giveTokens(address account, uint amount)
        public
    {
        tokenState.setBalanceOf(account, safeAdd(amount, tokenState.balanceOf(account)));
        totalSupply = safeAdd(totalSupply, amount);
    }

    function clearTokens(address account)
        public
    {
        totalSupply = safeSub(totalSupply, tokenState.balanceOf(account));
        tokenState.setBalanceOf(account, 0);
    }

}
