pragma solidity ^0.4.2;

import 'simple_market.sol';

// Simple Market with a market lifetime. When the lifetime has elapsed,
// offers can only be cancelled (offer and buy will throw).

contract ExpiringMarket is SimpleMarket {
    uint public close_time;
    function ExpiringMarket(uint lifetime) {
        close_time = getTime() + lifetime;
    }
    function getTime() constant returns (uint) {
        return block.timestamp;
    }
    function isClosed() constant returns (bool closed) {
        return (getTime() > close_time);
    }

    // after market lifetime has elapsed, no new offers are allowed
    modifier can_offer {
        assert(!isClosed());
        _;
    }
    // after close, no new buys are allowed
    modifier can_buy(uint id) {
        assert(isActive(id));
        assert(!isClosed());
        _;
    }
    // after close, anyone can cancel an offer
    modifier can_cancel(uint id) {
        assert(isActive(id));
        assert(isClosed() || (msg.sender == getOwner(id)));
        _;
    }
}
