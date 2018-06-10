/*
-----------------------------------------------------------------
FILE INFORMATION
-----------------------------------------------------------------

file:       Nomin.sol
version:    1.2
author:     Anton Jurisevic
            Mike Spain
            Dominic Romanowski
            Kevin Brown

date:       2018-05-29

-----------------------------------------------------------------
MODULE DESCRIPTION
----------------------------------------------------------------    -

Ether-backed nomin stablecoin contract.

This contract issues nomins, which are tokens worth 1 USD each.

Nomins are issuable by Havven holders who have to lock up some
value of their havvens to issue H * Cmax nomins. Where Cmax is
some value less than 1.

A configurable fee is charged on nomin transfers and deposited
into a common pot, which havven holders may withdraw from once per
fee period.

-----------------------------------------------------------------
*/

pragma solidity 0.4.24;


import "contracts/FeeToken.sol";
import "contracts/TokenState.sol";
import "contracts/Court.sol";
import "contracts/Havven.sol";

contract Nomin is FeeToken {

    /* ========== STATE VARIABLES ========== */

    // The address of the contract which manages confiscation votes.
    Court public court;
    Havven public havven;

    // Accounts which have lost the privilege to transact in nomins.
    mapping(address => bool) public frozen;

    // Nomin transfers incur a 15 bp fee by default.
    uint constant TRANSFER_FEE_RATE = 15 * UNIT / 10000;
    string constant TOKEN_NAME = "Nomin USD";
    string constant TOKEN_SYMBOL = "nUSD";

    /* ========== CONSTRUCTOR ========== */

    constructor(Havven _havven, address _owner)
        FeeToken(TOKEN_NAME, TOKEN_SYMBOL, 0, // Zero nomins initially exist.
                 TRANSFER_FEE_RATE,
                 _havven, // The havven contract is the fee authority.
                 _owner)
        public
    {
        require(address(_havven) != 0 && _owner != 0);
        // It should not be possible to transfer to the nomin contract itself.
        frozen[this] = true;
        havven = _havven;
    }

    /* ========== SETTERS ========== */

    function setCourt(Court _court)
        external
        onlyOwner
    {
        court = _court;
        emit CourtUpdated(_court);
    }

    function setHavven(Havven _havven)
        external
        onlyOwner
    {
        // havven should be set as the feeAuthority after calling this depending on
        // havven's internal logic
        havven = _havven;
        setFeeAuthority(_havven);
        emit HavvenUpdated(_havven);
    }


    /* ========== MUTATIVE FUNCTIONS ========== */

    /* Override ERC20 transfer function in order to check
     * whether the recipient account is frozen. Note that there is
     * no need to check whether the sender has a frozen account,
     * since their funds have already been confiscated,
     * and no new funds can be transferred to it.*/
    function transfer(address to, uint value)
        public
        returns (bool)
    {
        require(!frozen[to]);
        return _transfer(msg.sender, to, value);
    }

    /* Override ERC20 transferFrom function in order to check
     * whether the recipient account is frozen. */
    function transferFrom(address from, address to, uint value)
        public
        returns (bool)
    {
        require(!frozen[to]);
        return _transferFrom(msg.sender, from, to, value);
    }

    function transferSenderPaysFee(address to, uint value)
        public
        returns (bool)
    {
        require(!frozen[to]);
        return _transferSenderPaysFee(msg.sender, to, value);
    }

    function transferFromSenderPaysFee(address from, address to, uint value)
        public
        returns (bool)
    {
        require(!frozen[to]);
        return _transferFromSenderPaysFee(msg.sender, from, to, value);
    }

    /* If a confiscation court motion has passed and reached the confirmation
     * state, the court may transfer the target account's balance to the fee pool
     * and freeze its participation in further transactions. */
    function freezeAndConfiscate(address target)
        external
        onlyCourt
    {
        
        // A motion must actually be underway.
        uint motionID = court.targetMotionID(target);
        require(motionID != 0);

        // These checks are strictly unnecessary,
        // since they are already checked in the court contract itself.
        require(court.motionConfirming(motionID));
        require(court.motionPasses(motionID));
        require(!frozen[target]);

        // Confiscate the balance in the account and freeze it.
        uint balance = tokenState.balanceOf(target);
        tokenState.setBalanceOf(address(this), safeAdd(tokenState.balanceOf(address(this)), balance));
        tokenState.setBalanceOf(target, 0);
        frozen[target] = true;
        emit AccountFrozen(target, balance);
        emit Transfer(target, address(this), balance);
    }

    /* The owner may allow a previously-frozen contract to once
     * again accept and transfer nomins. */
    function unfreezeAccount(address target)
        external
        onlyOwner
    {
        require(frozen[target] && target != address(this));
        frozen[target] = false;
        emit AccountUnfrozen(target);
    }

    /* Allow havven to issue a certain number of
     * nomins from an account. */
    function issue(address account, uint amount)
        external
        onlyHavven
    {
        tokenState.setBalanceOf(account, safeAdd(tokenState.balanceOf(account), amount));
        totalSupply = safeAdd(totalSupply, amount);
        emit Transfer(address(0), account, amount);
        emit Issued(account, amount);
    }

    /* Allow havven to burn a certain number of
     * nomins from an account. */
    function burn(address account, uint amount)
        external
        onlyHavven
    {
        tokenState.setBalanceOf(account, safeSub(tokenState.balanceOf(account), amount));
        totalSupply = safeSub(totalSupply, amount);
        emit Transfer(account, address(0), amount);
        emit Burned(account, amount);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyHavven() {
        require(Havven(msg.sender) == havven);
        _;
    }

    modifier onlyCourt() {
        require(Court(msg.sender) == court);
        _;
    }

    /* ========== EVENTS ========== */

    event CourtUpdated(address newCourt);
    event HavvenUpdated(address newHavven);
    event AccountFrozen(address indexed target, uint balance);
    event AccountUnfrozen(address indexed target);
    event Issued(address indexed account, uint amount);
    event Burned(address indexed account, uint amount);
}
