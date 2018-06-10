/*
-----------------------------------------------------------------
FILE INFORMATION
-----------------------------------------------------------------

file:       FeeToken.sol
version:    1.3
author:     Anton Jurisevic
            Dominic Romanowski
            Kevin Brown

date:       2018-05-29

-----------------------------------------------------------------
MODULE DESCRIPTION
-----------------------------------------------------------------

A token which also has a configurable fee rate
charged on its transfers. This is designed to be overridden in
order to produce an ERC20-compliant token.

These fees accrue into a pool, from which a nominated authority
may withdraw.

This contract utilises an external state for upgradeability.

-----------------------------------------------------------------
*/

pragma solidity 0.4.24;


import "contracts/ExternStateToken.sol";


/**
 * @title ERC20 Token contract, with detached state.
 * Additionally charges fees on each transfer.
 */
contract FeeToken is ExternStateToken {

    /* ========== STATE VARIABLES ========== */

    /* ERC20 members are declared in ExternStateToken. */

    /* A percentage fee charged on each transfer. */
    uint public transferFeeRate;
    /* Fee may not exceed 10%. */
    uint constant MAX_TRANSFER_FEE_RATE = UNIT / 10;
    /* The address with the authority to distribute fees. */
    address public feeAuthority;


    /* ========== CONSTRUCTOR ========== */

    /**
     * @dev Constructor.
     * @param _name Token's ERC20 name.
     * @param _symbol Token's ERC20 symbol.
     * @param _totalSupply The total supply of the token.
     * @param _transferFeeRate The fee rate to charge on transfers.
     * @param _feeAuthority The address which has the authority to withdraw fees from the accumulated pool.
     * @param _owner The owner of this contract.
     */
    constructor(string _name, string _symbol, uint _totalSupply,
                uint _transferFeeRate, address _feeAuthority, address _owner)
        ExternStateToken(_name, _symbol, _totalSupply,
                         new TokenState(_owner, address(this)),
                         _owner)
        public
    {
        feeAuthority = _feeAuthority;

        /* Constructed transfer fee rate should respect the maximum fee rate. */
        require(_transferFeeRate <= MAX_TRANSFER_FEE_RATE);
        transferFeeRate = _transferFeeRate;
    }

    /* ========== SETTERS ========== */

    /**
     * @notice Set the transfer fee, anywhere within the range 0-10%.
     * @dev The fee rate is in decimal format, with UNIT being the value of 100%.
     */
    function setTransferFeeRate(uint _transferFeeRate)
        external
    {
        require(_transferFeeRate <= MAX_TRANSFER_FEE_RATE);
        transferFeeRate = _transferFeeRate;
        emit TransferFeeRateUpdated(_transferFeeRate);
    }

    /**
     * @notice Set the address of the user/contract responsible for collecting or
     * distributing fees.
     */
    function setFeeAuthority(address _feeAuthority)
        public
    {
        feeAuthority = _feeAuthority;
        emit FeeAuthorityUpdated(_feeAuthority);
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Calculate the Fee charged on top of a value being sent
     * @return Return the fee charged
     */
    function transferFeeIncurred(uint value)
        public
        view
        returns (uint)
    {
        return safeMul_dec(value, transferFeeRate);
        /* Transfers less than the reciprocal of transferFeeRate should be completely eaten up by fees.
         * This is on the basis that transfers less than this value will result in a nil fee.
         * Probably too insignificant to worry about, but the following code will achieve it.
         *      if (fee == 0 && transferFeeRate != 0) {
         *          return _value;
         *      }
         *      return fee;
         */
    }

    /**
     * @notice The value that you would need to send so that the recipient receives
     * a specified value.
     */
    function transferPlusFee(uint value)
        external
        view
        returns (uint)
    {
        return safeAdd(value, transferFeeIncurred(value));
    }

    /**
     * @notice The amount the recipient will receive if you send a certain number of tokens.
     */
    function amountReceived(uint value)
        public
        view
        returns (uint)
    {
        return safeDiv_dec(value, safeAdd(UNIT, transferFeeRate));
    }

    /**
     * @notice Collected fees sit here until they are distributed.
     * @dev The balance of the nomin contract itself is the fee pool.
     */
    function feePool()
        external
        view
        returns (uint)
    {
        return tokenState.balanceOf(address(this));
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Base of transfer functions
     */
    function _internalTransfer(address from, address to, uint amount, uint fee)
        internal
        returns (bool)
    {
        /* Disallow transfers to irretrievable-addresses. */
        require(to != address(0));
        require(to != address(this));

        /* Insufficient balance will be handled by the safe subtraction. */
        tokenState.setBalanceOf(from, safeSub(tokenState.balanceOf(from), safeAdd(amount, fee)));
        tokenState.setBalanceOf(to, safeAdd(tokenState.balanceOf(to), amount));
        tokenState.setBalanceOf(address(this), safeAdd(tokenState.balanceOf(address(this)), fee));

        /* Emit events for both the transfer itself and the fee. */
        emit Transfer(from, to, amount);
        emit Transfer(from, address(this), fee);

        return true;
    }

    /**
     * @notice ERC20 friendly transfer function.
     */
    function _transfer(address sender, address to, uint value)
        internal
        returns (bool)
    {
        uint received = amountReceived(value);
        uint fee = safeSub(value, received);

        return _internalTransfer(sender, to, received, fee);
    }

    /**
     * @notice ERC20 friendly transferFrom function.
     */
    function _transferFrom(address sender, address from, address to, uint value)
        internal
        returns (bool)
    {
        /* The fee is deducted from the amount sent. */
        uint received = amountReceived(value);
        uint fee = safeSub(value, received);

        /* Reduce the allowance by the amount we're transferring.
         * The safeSub call will handle an insufficient allowance. */
        tokenState.setAllowance(from, sender, safeSub(tokenState.allowance(from, sender), value));

        return _internalTransfer(from, to, received, fee);
    }

    /**
     * @notice Ability to transfer where the sender pays the fees (not ERC20)
     */
    function _transferSenderPaysFee(address sender, address to, uint value)
        internal
        returns (bool)
    {
        /* The fee is added to the amount sent. */
        uint fee = transferFeeIncurred(value);
        return _internalTransfer(sender, to, value, fee);
    }

    /**
     * @notice Ability to transferFrom where they sender pays the fees (not ERC20).
     */
    function _transferFromSenderPaysFee(address sender, address from, address to, uint value)
        internal
        returns (bool)
    {
        /* The fee is added to the amount sent. */
        uint fee = transferFeeIncurred(value);
        uint total = safeAdd(value, fee);

        /* Reduce the allowance by the amount we're transferring. */
        tokenState.setAllowance(from, sender, safeSub(tokenState.allowance(from, sender), total));

        return _internalTransfer(from, to, value, fee);
    }

    /**
     * @notice Withdraw tokens from the fee pool into a given account.
     * @dev Only the fee authority may call this.
     */
    function withdrawFees(address account, uint value)
        external
        onlyFeeAuthority
        returns (bool)
    {
        require(account != address(0));

        /* 0-value withdrawals do nothing. */
        if (value == 0) {
            return false;
        }

        /* Safe subtraction ensures an exception is thrown if the balance is insufficient. */
        tokenState.setBalanceOf(address(this), safeSub(tokenState.balanceOf(address(this)), value));
        tokenState.setBalanceOf(account, safeAdd(tokenState.balanceOf(account), value));

        emit FeesWithdrawn(account, value);
        emit Transfer(address(this), account, value);

        return true;
    }

    /**
     * @notice Donate tokens from the sender's balance into the fee pool.
     */
    function donateToFeePool(uint n)
        external
        returns (bool)
    {
        /* Empty donations are disallowed. */
        uint balance = tokenState.balanceOf(msg.sender);
        require(balance != 0);

        /* safeSub ensures the donor has sufficient balance. */
        tokenState.setBalanceOf(msg.sender, safeSub(balance, n));
        tokenState.setBalanceOf(address(this), safeAdd(tokenState.balanceOf(address(this)), n));

        emit FeesDonated(msg.sender, n);
        emit Transfer(msg.sender, address(this), n);

        return true;
    }


    /* ========== MODIFIERS ========== */

    modifier onlyFeeAuthority
    {
        require(msg.sender == feeAuthority);
        _;
    }


    /* ========== EVENTS ========== */

    event TransferFeeRateUpdated(uint newFeeRate);
    event FeeAuthorityUpdated(address newFeeAuthority);
    event FeesWithdrawn(address indexed account, uint value);
    event FeesDonated(address indexed donor, uint value);
}
