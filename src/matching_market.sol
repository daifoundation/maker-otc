/// matching_market.sol

//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.5.12;

import "./expiring_market.sol";
import "ds-note/note.sol";

contract MatchingEvents {
    event LogMinSell(address pay_gem, uint min_amount);
    event LogSortedOffer(uint id);
    event LogDelete(address keeper, uint id);
}

contract MatchingMarket is MatchingEvents, ExpiringMarket, DSNote {
    struct sortInfo {
        uint next;  // Points to id of next higher offer
        uint prev;  // Points to id of previous lower offer
        uint delb;  // The blocknumber where this entry was marked for delete
    }
    mapping(uint => sortInfo) public _rank;                     // Doubly linked lists of sorted offer ids
    mapping(address => mapping(address => uint)) public _best;  // id of the highest offer for a token pair
    mapping(address => mapping(address => uint)) public _span;  // Number of offers stored for token pair in sorted orderbook
    mapping(address => uint) public _dust;                      // Minimum sell amount for a token to avoid dust offers
    uint public dustId;                                         // id of the latest offer marked as dust


    constructor(uint64 close_time) ExpiringMarket(close_time) public {
    }

    // After close, anyone can cancel an offer
    modifier can_cancel(uint id) {
        require(isActive(id), "Offer was deleted or taken, or never existed.");
        require(
            isClosed() || msg.sender == getOwner(id) || id == dustId,
            "Offer can not be cancelled because user is not owner, and market is open, and offer sells required amount of tokens."
        );
        _;
    }

    // ---- Public entrypoints ---- //

    function make(
        ERC20    pay_gem,
        ERC20    buy_gem,
        uint128  pay_amt,
        uint128  buy_amt
    )
        public
        returns (bytes32)
    {
        return bytes32(offer(pay_amt, pay_gem, buy_amt, buy_gem));
    }

    function take(bytes32 id, uint128 maxTakeAmount) public {
        require(buy(uint(id), maxTakeAmount));
    }

    function kill(bytes32 id) public {
        require(cancel(uint(id)));
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    function offer(
        uint pay_amt,    // Maker (ask) sell how much
        ERC20 pay_gem,   // Maker (ask) sell which token
        uint buy_amt,    // Taker (ask) buy how much
        ERC20 buy_gem    // Taker (ask) buy which token
    )
        public
        returns (uint)
    {
        return offer(pay_amt, pay_gem, buy_amt, buy_gem, 0, true);
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    function offer(
        uint pay_amt,    // Maker (ask) sell how much
        ERC20 pay_gem,   // Maker (ask) sell which token
        uint buy_amt,    // Maker (ask) buy how much
        ERC20 buy_gem,   // Maker (ask) buy which token
        uint pos         // Position to insert offer, 0 should be used if unknown
    )
        public
        returns (uint)
    {
        return offer(pay_amt, pay_gem, buy_amt, buy_gem, pos, true);
    }

    function offer(
        uint pay_amt,    // Maker (ask) sell how much
        ERC20 pay_gem,   // Maker (ask) sell which token
        uint buy_amt,    // Maker (ask) buy how much
        ERC20 buy_gem,   // Maker (ask) buy which token
        uint pos,        // Position to insert offer, 0 should be used if unknown
        bool rounding    // Match "close enough" orders?
    )
        public
        can_offer
        returns (uint id)
    {
        require(!locked, "Reentrancy attempt");
        require(_dust[address(pay_gem)] <= pay_amt);

        uint best_maker_id;     // Highest maker id
        uint m_buy_amt;         // Maker offer wants to buy this much token
        uint m_pay_amt;         // Maker offer wants to sell this much token

        uint t_buy_amt_old;
        uint t_buy_amt = buy_amt;
        uint t_pay_amt = pay_amt;

        // There is at least one offer stored for token pair
        while (_best[address(buy_gem)][address(pay_gem)] > 0) {
            best_maker_id = _best[address(buy_gem)][address(pay_gem)];
            m_buy_amt = offers[best_maker_id].buy_amt;
            m_pay_amt = offers[best_maker_id].pay_amt;

            // Ugly hack to work around rounding errors. Based on the idea that
            // the furthest the amounts can stray from their "true" values is 1.
            // Ergo the worst case has t_pay_amt and m_pay_amt at +1 away from
            // their "correct" values and m_buy_amt and t_buy_amt at -1.
            // Since (c - 1) * (d - 1) > (a + 1) * (b + 1) is equivalent to
            // c * d > a * b + a + b + c + d, we write...
            if (mul(m_buy_amt, t_buy_amt) > mul(t_pay_amt, m_pay_amt) +
                (rounding ? m_buy_amt + t_buy_amt + t_pay_amt + m_pay_amt : 0))
            {
                break;
            }
            // ^ The `rounding` parameter is a compromise borne of a couple days
            // of discussion.
            buy(best_maker_id, min(m_pay_amt, t_buy_amt));
            t_buy_amt_old = t_buy_amt;
            t_buy_amt = sub(t_buy_amt, min(m_pay_amt, t_buy_amt));
            t_pay_amt = mul(t_buy_amt, t_pay_amt) / t_buy_amt_old;

            if (t_pay_amt == 0 || t_buy_amt == 0) {
                break;
            }
        }

        if (t_buy_amt > 0 && t_pay_amt > 0 && t_pay_amt >= _dust[address(pay_gem)]) {
            // New offer should be created
            id = super.offer(t_pay_amt, pay_gem, t_buy_amt, buy_gem);
            // Insert offer into the sorted list
            _sort(id, pos);
        }
    }

    // Transfers funds from caller to offer maker, and from market to caller.
    function buy(uint id, uint amount)
        public
        can_buy(id)
        returns (bool)
    {
        require(!locked, "Reentrancy attempt");

        if (amount == offers[id].pay_amt) {
            // offers[id] must be removed from sorted list because all of it is bought
            _unsort(id);
        }
        require(super.buy(id, amount));
        // If offer has become dust during buy, we cancel it
        if (isActive(id) && offers[id].pay_amt < _dust[address(offers[id].pay_gem)]) {
            dustId = id; // Enable current msg.sender to call cancel(id)
            cancel(id);
        }
        return true;
    }

    // Cancel an offer. Refunds offer maker.
    function cancel(uint id)
        public
        can_cancel(id)
        returns (bool success)
    {
        require(!locked, "Reentrancy attempt");
        require(_unsort(id));
        return super.cancel(id);    //delete the offer.
    }

    // Deletes _rank [id]
    // Function should be called by keepers.
    function del_rank(uint id)
        public
        returns (bool)
    {
        require(!locked, "Reentrancy attempt");
        require(!isActive(id) && _rank[id].delb != 0 && _rank[id].delb < block.number - 10);
        delete _rank[id];
        emit LogDelete(msg.sender, id);
        return true;
    }

    // Set the minimum sell amount for a token
    // Function is used to avoid "dust offers" that have
    // very small amount of tokens to sell, and it would
    // cost more gas to accept the offer, than the value
    // of tokens received.
    function setMinSell(
        ERC20 pay_gem,     // Token to assign minimum sell amount to
        uint dust          // Maker (ask) minimum sell amount
    )
        public
        auth
        note
        returns (bool)
    {
        _dust[address(pay_gem)] = dust;
        emit LogMinSell(address(pay_gem), dust);
        return true;
    }

    // Returns the minimum sell amount for an offer
    function getMinSell(
        ERC20 pay_gem      // Token for which minimum sell amount is queried
    )
        public
        view
        returns (uint)
    {
        return _dust[address(pay_gem)];
    }

    // Return the best offer for a token pair
    // the best offer is the lowest one if it's an ask,
    // and highest one if it's a bid offer
    function getBestOffer(ERC20 sell_gem, ERC20 buy_gem) public view returns(uint) {
        return _best[address(sell_gem)][address(buy_gem)];
    }

    // Return the next worse offer in the sorted list
    // the worse offer is the higher one if its an ask,
    // a lower one if its a bid offer,
    // and in both cases the newer one if they're equal.
    function getWorseOffer(uint id) public view returns(uint) {
        return _rank[id].prev;
    }

    // Return the next better offer in the sorted list
    // the better offer is in the lower priced one if its an ask,
    // the next higher priced one if its a bid offer
    // and in both cases the older one if they're equal.
    function getBetterOffer(uint id) public view returns(uint) {

        return _rank[id].next;
    }

    // Return the amount of better offers for a token pair
    function getOfferCount(ERC20 sell_gem, ERC20 buy_gem) public view returns(uint) {
        return _span[address(sell_gem)][address(buy_gem)];
    }

    function isOfferSorted(uint id) public view returns(bool) {
        return _rank[id].next != 0 ||
            _rank[id].prev != 0 ||
            _best[address(offers[id].pay_gem)][address(offers[id].buy_gem)] == id;
    }

    function sellAllAmount(ERC20 _pay_gem, uint _pay_amt, ERC20 _buy_gem, uint _min_fill_amount)
        public
        returns (uint fill_amt)
    {
        require(!locked, "Reentrancy attempt");
        uint offerId;
        uint pay_amt = _pay_amt;
        while (pay_amt > 0) {                                               // While there is amount to sell
            offerId = getBestOffer(_buy_gem, _pay_gem);                     // Get the best offer for the token pair
            require(offerId != 0);                                          // Fails if there are not more offers

            // There is a chance that pay_amt is smaller than 1 wei of the other token
            if (pay_amt * 1 ether < wdiv(offers[offerId].buy_amt, offers[offerId].pay_amt)) {
                break;                                                      // We consider that all amount is sold
            }
            if (pay_amt >= offers[offerId].buy_amt) {                       // If amount to sell is higher or equal than current offer amount to buy
                fill_amt = add(fill_amt, offers[offerId].pay_amt);          // Add amount bought to acumulator
                pay_amt = sub(pay_amt, offers[offerId].buy_amt);            // Decrease amount to sell
                take(bytes32(offerId), uint128(offers[offerId].pay_amt));   // We take the whole offer
            } else { // if lower
                uint baux = rmul(pay_amt * 10 ** 9, rdiv(offers[offerId].pay_amt, offers[offerId].buy_amt)) / 10 ** 9;
                fill_amt = add(fill_amt, baux);                             // Add amount bought to acumulator
                take(bytes32(offerId), uint128(baux));                      // We take the portion of the offer that we need
                pay_amt = 0;                                                // All amount is sold
            }
        }
        require(fill_amt >= _min_fill_amount);
    }

    function buyAllAmount(ERC20 _buy_gem, uint _buy_amt, ERC20 _pay_gem, uint _max_fill_amount)
        public
        returns (uint fill_amt)
    {
        require(!locked, "Reentrancy attempt");
        uint offerId;
        uint buy_amt = _buy_amt;
        while (buy_amt > 0) {                                               // Meanwhile there is amount to buy
            offerId = getBestOffer(_buy_gem, _pay_gem);                     // Get the best offer for the token pair
            require(offerId != 0);

            // There is a chance that buy_amt is smaller than 1 wei of the other token
            if (buy_amt * 1 ether < wdiv(offers[offerId].pay_amt, offers[offerId].buy_amt)) {
                break;                                                      // We consider that all amount is sold
            }
            if (buy_amt >= offers[offerId].pay_amt) {                       // If amount to buy is higher or equal than current offer amount to sell
                fill_amt = add(fill_amt, offers[offerId].buy_amt);          // Add amount sold to acumulator
                buy_amt = sub(buy_amt, offers[offerId].pay_amt);            // Decrease amount to buy
                take(bytes32(offerId), uint128(offers[offerId].pay_amt));   // We take the whole offer
            } else {                                                        // If lower
                fill_amt = add(fill_amt, rmul(buy_amt * 10 ** 9, rdiv(offers[offerId].buy_amt, offers[offerId].pay_amt)) / 10 ** 9); //Add amount sold to acumulator
                take(bytes32(offerId), uint128(buy_amt));                   // We take the portion of the offer that we need
                buy_amt = 0;                                                // All amount is bought
            }
        }
        require(fill_amt <= _max_fill_amount);
    }

    function getBuyAmount(ERC20 _buy_gem, ERC20 _pay_gem, uint _pay_amt) public view returns (uint fill_amt) {
        uint offerId = getBestOffer(_buy_gem, _pay_gem);            // Get best offer for the token pair
        uint pay_amt = _pay_amt;
        while (pay_amt > offers[offerId].buy_amt) {
            fill_amt = add(fill_amt, offers[offerId].pay_amt);      // Add amount to buy accumulator
            pay_amt = sub(pay_amt, offers[offerId].buy_amt);        // Decrease amount to pay
            if (pay_amt > 0) {                                      // If we still need more offers
                offerId = getWorseOffer(offerId);                   // We look for the next best offer
                require(offerId != 0);                              // Fails if there are not enough offers to complete
            }
        }
        fill_amt = add(
            fill_amt,
            rmul(pay_amt * 10 ** 9, rdiv(offers[offerId].pay_amt, offers[offerId].buy_amt)) / 10 ** 9
        ); // Add proportional amount of last offer to buy accumulator
    }

    function getPayAmount(ERC20 _pay_gem, ERC20 _buy_gem, uint _buy_amt) public view returns (uint fill_amt) {
        uint offerId = getBestOffer(_buy_gem, _pay_gem);            // Get best offer for the token pair
        uint buy_amt = _buy_amt;
        while (buy_amt > offers[offerId].pay_amt) {
            fill_amt = add(fill_amt, offers[offerId].buy_amt);      // Add amount to pay accumulator
            buy_amt = sub(buy_amt, offers[offerId].pay_amt);        // Decrease amount to buy
            if (buy_amt > 0) {                                      // If we still need more offers
                offerId = getWorseOffer(offerId);                   // We look for the next best offer
                require(offerId != 0);                              // Fails if there are not enough offers to complete
            }
        }
        fill_amt = add(
            fill_amt,
            rmul(buy_amt * 10 ** 9, rdiv(offers[offerId].buy_amt, offers[offerId].pay_amt)) / 10 ** 9
        ); // Add proportional amount of last offer to pay accumulator
    }

    // Find the id of the next higher offer after offers[id]
    function _find(uint id)
        internal
        view
        returns (uint)
    {
        require(id > 0);

        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        uint top = _best[pay_gem][buy_gem];
        uint old_top = 0;

        // Find the larger-than-id order whose successor is less-than-id.
        while (top != 0 && _isPricedLtOrEq(id, top)) {
            old_top = top;
            top = _rank[top].prev;
        }
        return old_top;
    }

    // Find the id of the next higher offer after offers[id]
    function _findpos(uint id, uint _pos)
        internal
        view
        returns (uint)
    {
        require(id > 0);
        uint pos = _pos;

        // Look for an active order.
        while (pos != 0 && !isActive(pos)) {
            pos = _rank[pos].prev;
        }

        if (pos == 0) {
            // If we got to the end of list without a single active offer
            return _find(id);

        } else {
            // If we did find a nearby active offer
            // Walk the order book down from there...
            if(_isPricedLtOrEq(id, pos)) {
                uint old_pos;

                // Guaranteed to run at least once because of
                // the prior if statements.
                while (pos != 0 && _isPricedLtOrEq(id, pos)) {
                    old_pos = pos;
                    pos = _rank[pos].prev;
                }
                return old_pos;

            // ...or walk it up.
            } else {
                while (pos != 0 && !_isPricedLtOrEq(id, pos)) {
                    pos = _rank[pos].next;
                }
                return pos;
            }
        }
    }

    // Return true if offers[low] priced less than or equal to offers[high]
    function _isPricedLtOrEq(
        uint low,   // Lower priced offer's id
        uint high   // Higher priced offer's id
    )
        internal
        view
        returns (bool)
    {
        return mul(offers[low].buy_amt, offers[high].pay_amt)
          >= mul(offers[high].buy_amt, offers[low].pay_amt);
    }

    // Put offer into the sorted list
    function _sort(
        uint id,    // Maker (ask) id
        uint _pos   // Position to insert into
    )
        internal
    {
        require(isActive(id));
        uint pos = _pos;

        ERC20 buy_gem = offers[id].buy_gem;
        ERC20 pay_gem = offers[id].pay_gem;
        uint prev_id;                                      // Maker (ask) id

        pos = pos == 0 || offers[pos].pay_gem != pay_gem || offers[pos].buy_gem != buy_gem || !isOfferSorted(pos)
        ?
            _find(id)
        :
            _findpos(id, pos);

        if (pos != 0) {                                    // offers[id] is not the highest offer
            // Requirement below is satisfied by statements above
            // require(_isPricedLtOrEq(id, pos));
            prev_id = _rank[pos].prev;
            _rank[pos].prev = id;
            _rank[id].next = pos;
        } else {                                           // offers[id] is the highest offer
            prev_id = _best[address(pay_gem)][address(buy_gem)];
            _best[address(pay_gem)][address(buy_gem)] = id;
        }

        if (prev_id != 0) {                               // If lower offer does exist
            // Requirement below is satisfied by statements above
            // require(!_isPricedLtOrEq(id, prev_id));
            _rank[prev_id].next = id;
            _rank[id].prev = prev_id;
        }

        _span[address(pay_gem)][address(buy_gem)]++;
        emit LogSortedOffer(id);
    }

    // Remove offer from the sorted list (does not cancel offer)
    function _unsort(
        uint id    // id of maker (ask) offer to remove from sorted list
    )
        internal
        returns (bool)
    {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        require(_span[pay_gem][buy_gem] > 0);

        require(_rank[id].delb == 0 && isOfferSorted(id));  // Assert id is in the sorted list

        if (id != _best[pay_gem][buy_gem]) {                // offers[id] is not the highest offer
            require(_rank[_rank[id].next].prev == id);
            _rank[_rank[id].next].prev = _rank[id].prev;
        } else {                                            // offers[id] is the highest offer
            _best[pay_gem][buy_gem] = _rank[id].prev;
        }

        if (_rank[id].prev != 0) {                          // offers[id] is not the lowest offer
            require(_rank[_rank[id].prev].next == id);
            _rank[_rank[id].prev].next = _rank[id].next;
        }

        _span[pay_gem][buy_gem]--;
        _rank[id].delb = block.number;                      // Mark _rank[id] for deletion
        return true;
    }
}
