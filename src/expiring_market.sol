pragma solidity ^0.4.13;

import "ds-auth/auth.sol";
import "ds-warp/warp.sol";

import "./simple_market.sol";

// Simple Market with a market lifetime. When the lifetime has elapsed,
// offers can only be cancelled (offer and buy will throw).

contract ExpiringMarket is DSAuth, SimpleMarket, DSWarp {
    uint64 public lifetime;
    uint64 public close_time;
    bool public stopped;

    function stop() auth {
        stopped = true;
    }

    function ExpiringMarket(uint64 lifetime_, uint64 era_) {
        warp(era_);
        lifetime = lifetime_;
        close_time = era() + lifetime_;
        assert(close_time > era());
    }

    function isClosed() constant returns (bool closed) {
        return stopped || era() > close_time;
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
