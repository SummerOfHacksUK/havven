/*
-----------------------------------------------------------------
FILE INFORMATION
-----------------------------------------------------------------

file:       ExternStateToken.sol
version:    1.3
author:     Anton Jurisevic
            Dominic Romanowski

date:       2018-05-29

-----------------------------------------------------------------
MODULE DESCRIPTION
-----------------------------------------------------------------

A partial ERC20 token contract, designed to operate with a proxy.
To produce a complete ERC20 token, transfer and transferFrom
tokens must be implemented, using the provided _byProxy internal
functions.
This contract utilises an external state for upgradeability.

-----------------------------------------------------------------
*/

pragma solidity 0.4.24;


import "contracts/SafeDecimalMath.sol";
import "contracts/SelfDestructible.sol";
import "contracts/TokenState.sol";


/**
 * @title ERC20 Token contract, with detached state and designed to operate behind a proxy.
 */
contract ExternStateToken is SafeDecimalMath, SelfDestructible {

    /* ========== STATE VARIABLES ========== */

    /* Stores balances and allowances. */
    TokenState public tokenState;

    /* Other ERC20 fields.
     * Note that the decimals field is defined in SafeDecimalMath.*/
    string public name;
    string public symbol;
    uint public totalSupply;

    /**
     * @dev Constructor.
     * @param _name Token's ERC20 name.
     * @param _symbol Token's ERC20 symbol.
     * @param _totalSupply The total supply of the token.
     * @param _tokenState The TokenState contract address.
     * @param _owner The owner of this contract.
     */
    constructor(string _name, string _symbol, uint _totalSupply,
                TokenState _tokenState, address _owner)
        SelfDestructible(_owner)
        public
    {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        tokenState = _tokenState;
   }

    /* ========== VIEWS ========== */

    /**
     * @notice Returns the ERC20 allowance of one party to spend on behalf of another.
     * @param owner The party authorising spending of their funds.
     * @param spender The party spending tokenOwner's funds.
     */
    function allowance(address owner, address spender)
        public
        view
        returns (uint)
    {
        return tokenState.allowance(owner, spender);
    }

    /**
     * @notice Returns the ERC20 token balance of a given account.
     */
    function balanceOf(address account)
        public
        view
        returns (uint)
    {
        return tokenState.balanceOf(account);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Set the address of the TokenState contract.
     * @dev This can be used to "pause" transfer functionality, by pointing the tokenState at 0x000..
     * as balances would be unreachable.
     */ 
    function setTokenState(TokenState _tokenState)
        external
        onlyOwner
    {
        tokenState = _tokenState;
        emit TokenStateUpdated(_tokenState);
    }

    function _internalTransfer(address from, address to, uint value) 
        internal
        returns (bool)
    { 
        /* Disallow transfers to irretrievable-addresses. */
        require(to != address(0));
        require(to != address(this));

        /* Insufficient balance will be handled by the safe subtraction. */
        tokenState.setBalanceOf(from, safeSub(tokenState.balanceOf(from), value));
        tokenState.setBalanceOf(to, safeAdd(tokenState.balanceOf(to), value));

        emit Transfer(from, to, value);

        return true;
    }

    /**
     * @dev Perform an ERC20 token transferFrom. Designed to be called by transferFrom functions
     * possessing the optionalProxy or optionalProxy modifiers.
     */
    function _transferFrom(address sender, address from, address to, uint value)
        internal
        returns (bool)
    {
        /* Insufficient allowance will be handled by the safe subtraction. */
        tokenState.setAllowance(from, sender, safeSub(tokenState.allowance(from, sender), value));
        return _internalTransfer(from, to, value);
    }

    /**
     * @notice Approves spender to transfer on the message sender's behalf.
     */
    function approve(address spender, uint value)
        public
        returns (bool)
    {
        tokenState.setAllowance(msg.sender, spender, value);
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /* ========== EVENTS ========== */

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event TokenStateUpdated(address newTokenState);
}
