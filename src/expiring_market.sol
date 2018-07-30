pragma solidity ^0.4.18;

import "ds-auth/auth.sol";

import "./simple_market.sol";

// Simple Market with a market lifetime. When the close_time has been reached,
// offers can only be cancelled (offer and buy will throw).

contract ExpiringMarket is DSAuth, SimpleMarket {
    uint64 public close_time;

    // after close_time has been reached, no new offers are allowed
    modifier canOffer {
        require(!isClosed());
        _;
    }

    // after close, no new buys are allowed
    modifier canBuy(uint id) {
        require(isActive(id));
        require(!isClosed());
        _;
    }

    // after close, anyone can cancel an offer
    modifier canCancel(uint id) {
        require(isActive(id));
        require(isClosed() || (msg.sender == getOwner(id)));
        _;
    }

    constructor(uint64 _close_time)
        public
    {
        close_time = _close_time;
    }

    function isClosed() public view returns (bool closed) {
        return getTime() > close_time;
    }

    function getTime() public view returns (uint64) {
        return uint64(now);
    }
}
