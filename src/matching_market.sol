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
        uint idPos       // id of tentative offer which should be the next better one (0 should be used if unknown)
    )
        public
        returns (uint)
    {
        return offer(pay_amt, pay_gem, buy_amt, buy_gem, idPos, true);
    }

    function offer(
        uint pay_amt,    // New offer pay amount
        ERC20 pay_gem,   // New offer pay token
        uint buy_amt,    // New offer buy amount
        ERC20 buy_gem,   // New offer buy token
        uint idPos,      // id of tentative offer which should be the next better one (0 should be used if unknown)
        bool rounding    // Match "close enough" orders?
    )
        public
        can_offer
        returns (uint id)
    {
        require(!locked, "Reentrancy attempt");
        require(_dust[address(pay_gem)] <= pay_amt);

        uint best;          // Best existing offer id from opposite pair (for matching)
        uint oBuyAmt;       // Existing offer buy amount from opposite pair
        uint oPayAmt;       // Existing offer pay amount from opposite pair

        uint buyAmtAux;
        uint buyAmt = buy_amt;
        uint payAmt = pay_amt;

        // There is at least one offer stored for token pair
        while (_best[address(buy_gem)][address(pay_gem)] > 0) {
            best = _best[address(buy_gem)][address(pay_gem)];
            oBuyAmt = offers[best].buy_amt;
            oPayAmt = offers[best].pay_amt;

            // Ugly hack to work around rounding errors. Based on the idea that
            // the furthest the amounts can stray from their "true" values is 1.
            // Ergo the worst case has payAmt and oPayAmt at +1 away from
            // their "correct" values and oBuyAmt and buyAmt at -1.
            // Since (c - 1) * (d - 1) > (a + 1) * (b + 1) is equivalent to
            // c * d > a * b + a + b + c + d, we write...
            if (mul(oBuyAmt, buyAmt) > mul(payAmt, oPayAmt) +
                (rounding ? oBuyAmt + buyAmt + payAmt + oPayAmt : 0))
            {
                break;
            }
            // ^ The `rounding` parameter is a compromise borne of a couple days
            // of discussion.

            // Calculate how much to buy (the minimum between the pay amount ofmatched offer and the buy amount of new offer)
            uint amtToBuy = min(oPayAmt, buyAmt);
            // Execute buy
            buy(best, amtToBuy);

            buyAmtAux = buyAmt;
            // Calculate rest amount to buy
            buyAmt = sub(buyAmt, amtToBuy);
            // Calculate rest amount to pay (rest amount to buy * price)
            payAmt = mul(buyAmt, payAmt) / buyAmtAux;

            if (payAmt == 0 || buyAmt == 0) {
                break;
            }
        }

        if (buyAmt > 0 && payAmt > 0 && payAmt >= _dust[address(pay_gem)]) {
            // New offer should be created
            id = super.offer(payAmt, pay_gem, buyAmt, buy_gem);
            // Insert offer into the sorted list
            _sort(id, idPos);
        }
    }

    // Transfers funds from caller to offer maker, and from market to caller.
    function buy(uint id, uint amount)
        public
        can_buy(id)
        returns (bool)
    {
        require(!locked, "Reentrancy attempt");
        require(isActive(id));

        if (amount == offers[id].pay_amt) {
            // offers[id] must be removed from sorted list because all of it will be bought
            _unsort(id);
        }

        // Execute buy
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
        require(isActive(id));

        // Unsort the offer
        _unsort(id);

        // Delete the offer.
        return super.cancel(id);
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

    function hasSortInfo(uint id) public view returns(bool) {
        return isActive(id) || _rank[id].next != 0 || _rank[id].prev != 0;
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

    // Find the id of the next better offer after offers[id]
    function _find(uint id)
        internal
        view
        returns (uint idPos)
    {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        uint idAux = _best[pay_gem][buy_gem];

        // Find the offer 'idPos' which is the the next better one than id
        while (idAux != 0 && _isWorseOrEq(id, idAux)) {
            idPos = idAux;
            idAux = _rank[idAux].prev;
        }
    }

    // Find the id of the next better offer after offers[id] (using an existing offers[idPos] as starting point)
    function _findpos(uint id, uint _idPos)
        internal
        view
        returns (uint idPos)
    {
        idPos = _idPos;

        // If the initial idPos is a cancelled offer, then start looking for worse offers until one is active or getting the end.
        while (idPos != 0 && !isActive(idPos)) {
            idPos = _rank[idPos].prev;
        }

        // If we got to the end of list without a single active offer
        if (idPos == 0) {
            // Then look for position from the top of the list
            idPos = _find(id);
        } else {
            // If new offer id is worse than found (idPos)
            if(_isWorseOrEq(id, idPos)) {
                uint idAux = _rank[idPos].prev;
                while (idAux != 0 && _isWorseOrEq(id, idAux)) {
                    idPos = idAux;
                    idAux = _rank[idPos].prev;
                }
            } else {
                while (idPos != 0 && !_isWorseOrEq(id, idPos)) {
                    idPos = _rank[idPos].next;
                }
            }
        }
    }

    // Return true if offers[worse] is less convinient than or equal to offers[better] (from a buyer point of view)
    function _isWorseOrEq(
        uint worse,   // worse priced offer's id
        uint better   // better priced offer's id
    )
        internal
        view
        returns (bool)
    {
        return mul(
                    offers[worse].buy_amt,
                    offers[better].pay_amt
                ) >=
                mul(
                    offers[better].buy_amt,
                    offers[worse].pay_amt
                );
    }

    // Put offer into the sorted list
    function _sort(
        uint id,        // id of offer to insert into sorted list
        uint _idPos     // id of tentative offer which should be the next better one
    )
        internal
    {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        uint idAux;

        // If pos not defined or the pos offer doesn't correspond with the id one or if there is not sort info
        uint idPos = _idPos == 0 ||
                    address(offers[_idPos].pay_gem) != pay_gem ||
                    address(offers[_idPos].buy_gem) != buy_gem ||
                    !hasSortInfo(_idPos)
        ?
            // Then is necessary to look for the position from the top of the list
            _find(id)
        :
            // Otherwise use that position for starting
            _findpos(id, _idPos);

        // If offers[id] is not the best offer
        if (idPos != 0) {
            idAux = _rank[idPos].prev;
            _rank[idPos].prev = id;
            _rank[id].next = idPos;
        } else {
            idAux = _best[pay_gem][buy_gem];
            _best[pay_gem][buy_gem] = id;
        }

        // If worse offer exists
        if (idAux != 0) {
            _rank[idAux].next = id;
            _rank[id].prev = idAux;
        }

        // Add one to the counter
        _span[pay_gem][buy_gem]++;
        emit LogSortedOffer(id);
    }

    // Remove offer from the sorted list
    function _unsort(
        uint id    // id of offer to remove from sorted list
    )
        internal
    {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);

        // If offers[id] is not the best offer
        if (id != _best[pay_gem][buy_gem]) {
            _rank[_rank[id].next].prev = _rank[id].prev;
        } else {
            _best[pay_gem][buy_gem] = _rank[id].prev;
        }

        // If offers[id] is not the worst offer
        if (_rank[id].prev != 0) {
            _rank[_rank[id].prev].next = _rank[id].next;
        }

        // Substract one to the counter
        _span[pay_gem][buy_gem]--;

        // Mark _rank[id] for deletion
        _rank[id].delb = block.number;
    }
}
