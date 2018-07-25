pragma solidity ^0.4.18;

import "ds-auth/auth.sol";

import "./simple_market.sol";

// Simple Market with a market lifetime. When the close_time has been reached,
// offers can only be cancelled (offer and buy will throw).

contract ExpiringMarket is DSAuth, SimpleMarket {
    uint64 public close_time;
    bool public stopped;

    // after close_time has been reached, no new offers are allowed
    modifier can_offer {
        require(!isClosed());
        _;
    }

    // after close, no new buys are allowed
    modifier can_buy(uint id) {
        require(isActive(id));
        require(!isClosed());
        _;
    }

    // after close, anyone can cancel an offer
    modifier can_cancel(uint id) {
        require(isActive(id));
        require(isClosed() || (msg.sender == getOwner(id)));
        _;
    }

    function ExpiringMarket(uint64 _close_time)
        public
    {
        close_time = _close_time;
    }

    function isClosed() public constant returns (bool closed) {
        return stopped || getTime() > close_time;
    }

    function getTime() public constant returns (uint64) {
        return uint64(now);
    }

    function stop() public auth {
        stopped = true;
    }
}
