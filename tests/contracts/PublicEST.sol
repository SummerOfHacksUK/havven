pragma solidity ^0.4.23;

import "contracts/ExternStateToken.sol";

contract PublicEST is ExternStateToken {
    constructor(string _name, string _symbol, uint _totalSupply,
                                   TokenState _state, address _owner)
        ExternStateToken(_name, _symbol, _totalSupply, _state, _owner)
        public
    {}

    function transfer(address to, uint value)
        external
    {
        _internalTransfer(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint value)
        external
    {
        _transferFrom(msg.sender, from, to, value);
    }
}
