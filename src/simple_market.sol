pragma solidity ^0.4.13;

import "ds-math/math.sol";
import "erc20/erc20.sol";

contract EventfulMarket {
    event ItemUpdate(uint id);
    event Trade(uint pay_amt, address indexed pay_gem,
                uint buy_amt, address indexed buy_gem);

    event LogMake(
        bytes32  indexed  id,
        bytes32  indexed  pair,
        address  indexed  maker,
        ERC20             pay_gem,
        ERC20             buy_gem,
        uint128           pay_amt,
        uint128           buy_amt,
        uint64            timestamp
    );

    event LogBump(
        bytes32  indexed  id,
        bytes32  indexed  pair,
        address  indexed  maker,
        ERC20             pay_gem,
        ERC20             buy_gem,
        uint128           pay_amt,
        uint128           buy_amt,
        uint64            timestamp
    );

    event LogTake(
        bytes32           id,
        bytes32  indexed  pair,
        address  indexed  maker,
        ERC20             pay_gem,
        ERC20             buy_gem,
        address  indexed  taker,
        uint128           take_amt,
        uint128           give_amt,
        uint64            timestamp
    );

    event LogKill(
        bytes32  indexed  id,
        bytes32  indexed  pair,
        address  indexed  maker,
        ERC20             pay_gem,
        ERC20             buy_gem,
        uint128           pay_amt,
        uint128           buy_amt,
        uint64            timestamp
    );
}

contract SimpleMarket is EventfulMarket, DSMath {

    uint public last_offer_id;

    mapping (uint => OfferInfo) public offers;

    bool locked;

    struct OfferInfo {
        uint     pay_amt;
        ERC20    pay_gem;
        uint     buy_amt;
        ERC20    buy_gem;
        address  owner;
        bool     active;
        uint64   timestamp;
    }

    modifier can_buy(uint id) {
        assert(isActive(id));
        _;
    }

    modifier can_cancel(uint id) {
        assert(isActive(id));
        assert(getOwner(id) == msg.sender);
        _;
    }

    modifier can_offer {
        _;
    }

    modifier synchronized {
        assert(!locked);
        locked = true;
        _;
        locked = false;
    }

    function isActive(uint id) constant returns (bool active) {
        return offers[id].active;
    }
    function getOwner(uint id) constant returns (address owner) {
        return offers[id].owner;
    }
    function getOffer(uint id) constant returns (uint, ERC20, uint, ERC20) {
      var offer = offers[id];
      return (offer.pay_amt, offer.pay_gem,
              offer.buy_amt, offer.buy_gem);
    }

    // ---- Public entrypoints ---- //

    function make(
        ERC20    pay_gem,
        ERC20    buy_gem,
        uint128  pay_amt,
        uint128  buy_amt
    ) returns (bytes32 id) {
        return bytes32(offer(pay_amt, pay_gem, buy_amt, buy_gem));
    }

    function take(bytes32 id, uint128 maxTakeAmount) {
        assert(buy(uint256(id), maxTakeAmount));
    }

    function kill(bytes32 id) {
        assert(cancel(uint256(id)));
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    function offer(uint pay_amt, ERC20 pay_gem, uint buy_amt, ERC20 buy_gem)
        can_offer
        synchronized
        returns (uint id)
    {
        assert(uint128(pay_amt) == pay_amt);
        assert(uint128(buy_amt) == buy_amt);
        assert(pay_amt > 0);
        assert(pay_gem != ERC20(0x0));
        assert(buy_amt > 0);
        assert(buy_gem != ERC20(0x0));
        assert(pay_gem != buy_gem);

        OfferInfo memory info;
        info.pay_amt = pay_amt;
        info.pay_gem = pay_gem;
        info.buy_amt = buy_amt;
        info.buy_gem = buy_gem;
        info.owner = msg.sender;
        info.active = true;
        info.timestamp = uint64(now);
        id = _next_id();
        offers[id] = info;

        var seller_paid = pay_gem.transferFrom(msg.sender, this, pay_amt);
        assert(seller_paid);

        ItemUpdate(id);
        LogMake(
            bytes32(id),
            sha3(pay_gem, buy_gem),
            msg.sender,
            pay_gem,
            buy_gem,
            uint128(pay_amt),
            uint128(buy_amt),
            uint64(now)
        );
    }

    function bump(bytes32 id_)
        can_buy(uint256(id_))
    {
        var id = uint256(id_);
        LogBump(
            id_,
            sha3(offers[id].pay_gem, offers[id].buy_gem),
            offers[id].owner,
            offers[id].pay_gem,
            offers[id].buy_gem,
            uint128(offers[id].pay_amt),
            uint128(offers[id].buy_amt),
            offers[id].timestamp
        );
    }

    // Accept given `quantity` of an offer. Transfers funds from caller to
    // offer maker, and from market to caller.
    function buy(uint id, uint quantity)
        can_buy(id)
        synchronized
        returns (bool success)
    {
        assert(uint128(quantity) == quantity);

        // read-only offer. Modify an offer by directly accessing offers[id]
        OfferInfo memory offer = offers[id];

        // inferred quantity that the buyer wishes to spend
        uint spend = mul(quantity, offer.buy_amt) / offer.pay_amt;
        assert(uint128(spend) == spend);

        if (spend > offer.buy_amt || quantity > offer.pay_amt) {
            // buyer buys more than is available
            success = false;
        } else if (spend == offer.buy_amt && quantity == offer.pay_amt) {
            // buyer buys exactly what is available
            delete offers[id];

            _trade(offer.owner, quantity, offer.pay_gem,
                   msg.sender, spend, offer.buy_gem);

            ItemUpdate(id);
            LogTake(
                bytes32(id),
                sha3(offer.pay_gem, offer.buy_gem),
                offer.owner,
                offer.pay_gem,
                offer.buy_gem,
                msg.sender,
                uint128(offer.pay_amt),
                uint128(offer.buy_amt),
                uint64(now)
            );

            success = true;
        } else if (spend > 0 && quantity > 0) {
            // buyer buys a fraction of what is available
            offers[id].pay_amt = sub(offer.pay_amt, quantity);
            offers[id].buy_amt = sub(offer.buy_amt, spend);

            _trade(offer.owner, quantity, offer.pay_gem,
                   msg.sender, spend, offer.buy_gem);

            ItemUpdate(id);
            LogTake(
                bytes32(id),
                sha3(offer.pay_gem, offer.buy_gem),
                offer.owner,
                offer.pay_gem,
                offer.buy_gem,
                msg.sender,
                uint128(quantity),
                uint128(spend),
                uint64(now)
            );

            success = true;
        } else {
            // buyer buys an unsatisfiable amount (less than 1 integer)
            success = false;
        }
    }

    // Cancel an offer. Refunds offer maker.
    function cancel(uint id)
        can_cancel(id)
        synchronized
        returns (bool success)
    {
        // read-only offer. Modify an offer by directly accessing offers[id]
        OfferInfo memory offer = offers[id];
        delete offers[id];

        assert( offer.pay_gem.transfer(offer.owner, offer.pay_amt) );

        ItemUpdate(id);
        LogKill(
            bytes32(id),
            sha3(offer.pay_gem, offer.buy_gem),
            offer.owner,
            offer.pay_gem,
            offer.buy_gem,
            uint128(offer.pay_amt),
            uint128(offer.buy_amt),
            uint64(now)
        );

        success = true;
    }

    function _next_id() internal returns (uint) {
        last_offer_id++; return last_offer_id;
    }

    function _trade(address seller, uint sell_amt, ERC20 sell_gem,
                    address buyer,  uint pay_amt,  ERC20 pay_gem)
        internal
    {
        assert( pay_gem.transferFrom(buyer, seller, pay_amt) );
        assert( sell_gem.transfer(buyer, sell_amt) );
        Trade(sell_amt, sell_gem, pay_amt, pay_gem);
    }
}
