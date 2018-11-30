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

pragma solidity >=0.4.24;

import "./expiring_market.sol";
import "ds-note/note.sol";

contract MatchingEvents {
    event LogDustLimit(address sellGem, uint minAmount);
    event LogUnsortedOffer(uint id);
    event LogSortedOffer(uint id);
    event LogInsert(address keeper, uint id);
    event LogDelete(address keeper, uint id);
}

contract MatchingMarket is MatchingEvents, ExpiringMarket, DSNote {
    struct sortInfo {
        uint next;                                              // points to id of next higher offer
        uint prev;                                              // points to id of previous lower offer
    }
    mapping(uint => sortInfo) public rank;                      // doubly linked lists of sorted offer ids
    mapping(address => mapping(address => uint)) public best;   // id of the highest offer for a token pair
    mapping(address => mapping(address => uint)) public span;   // number of offers stored for token pair in sorted orderbook
    mapping(address => uint) public dust;                       // minimum sell amount for a token to avoid dust offers
    uint public dustId;                                         // id of the latest offer marked as dust

    constructor(uint64 closeTime) ExpiringMarket(closeTime) public {
    }

    // After close, anyone can cancel an offer
    modifier canCancel(uint id) {
        require(isActive(id), "Offer was deleted or taken, or never existed.");
        require(
            isClosed() || msg.sender == getOwner(id) || id == dustId,
            "Offer can not be cancelled because user is not owner, and market is open, and offer sells required amount of tokens."
        );
        _;
    }
    
    // ---- Public entrypoints ---- //

    function iocOffer(
        uint oSellAmt,                              // taker sell amount (original value)
        ERC20 sellGem,                              // taker sell token
        uint oBuyAmt,                               // taker buy amount (original value)
        ERC20 buyGem,                               // taker buy token
        bool forceSellAmt                           // If true, uses sellAmt as pivot, otherwise buyAmt
    ) public returns (uint sellAmt, uint buyAmt) {
        require(!locked, "Reentrancy attempt");
        require(oSellAmt >= dust[address(sellGem)], "Offer sell quantity is less then required.");

        sellAmt = oSellAmt;                         // taker sell amount (countdown)
        buyAmt = oBuyAmt;                           // taker buy amount (countdown)
        uint bestMatchingId;                        // best matching id

        // There is at least one offer stored for token pair
        while ((bestMatchingId = best[address(buyGem)][address(sellGem)]) > 0) {
            // Handle round-off error. Based on the idea that
            // the furthest the amounts can stray from their "true" values is 1.
            // Ergo the worst case has oSellAmt and offers[bestMatchingId].sellAmt at +1 away from
            // their "correct" values and offers[bestMatchingId].oBuyAmt and buyAmt at -1.
            // Since (c - 1) * (d - 1) > (a + 1) * (b + 1) is equivalent to
            // c * d > a * b + a + b + c + d, we write...
            if (mul(offers[bestMatchingId].oBuyAmt, oBuyAmt) >
                add(
                    add(
                        add(
                            add(mul(oSellAmt, offers[bestMatchingId].oSellAmt), offers[bestMatchingId].oBuyAmt),
                            oBuyAmt
                        ),
                        oSellAmt
                    ),
                    offers[bestMatchingId].oSellAmt
                )
            ) {
                break;
            }

            if (forceSellAmt) {
                uint amountToSell = min(offers[bestMatchingId].buyAmt, sellAmt);
                buy(
                    bestMatchingId,
                    min(
                        offers[bestMatchingId].sellAmt,
                        mul(amountToSell, offers[bestMatchingId].oSellAmt) / offers[bestMatchingId].oBuyAmt
                    ) // To avoid rounding issues, we check the amount to buy is not higher than the sellAmt of the offer
                );
                sellAmt = sub(sellAmt, amountToSell);
                buyAmt = mul(sellAmt, oBuyAmt) / oSellAmt;
            } else {
                uint amountToBuy = min(offers[bestMatchingId].sellAmt, buyAmt);
                buy(bestMatchingId, amountToBuy);
                buyAmt = sub(buyAmt, amountToBuy);
                sellAmt = mul(buyAmt, oSellAmt) / oBuyAmt;
            }

            if (sellAmt == 0 || buyAmt == 0) {
                break;
            }
        }
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    function limitOffer(
        uint oSellAmt,                              // new offer sell amount
        ERC20 sellGem,                              // new offer sell token
        uint oBuyAmt,                               // new offer buy amount
        ERC20 buyGem,                               // new offer buy token
        bool forceSellAmt,                          // if true, uses sellAmt as pivot, otherwise buyAmt
        uint pos                                    // position to insert offer, 0 should be used if unknown
    ) public returns (uint id) {
        id = limitOffer(oSellAmt, sellGem, oBuyAmt, buyGem, forceSellAmt, pos, msg.sender);
    }

    function limitOffer(
        uint oSellAmt,                              // new offer sell amount
        ERC20 sellGem,                              // new offer sell token
        uint oBuyAmt,                               // new offer buy amount
        ERC20 buyGem,                               // new offer buy token
        bool forceSellAmt,                          // if true, uses sellAmt as pivot, otherwise buyAmt
        uint pos,                                   // position to insert offer, 0 should be used if unknown
        address owner                               // if an order is created, defines who will be the owner
    ) public canOffer returns (uint id) {
        (uint sellAmt, uint buyAmt) = iocOffer(oSellAmt, sellGem, oBuyAmt, buyGem, forceSellAmt);

        // Create new taker offer if necessary
        if (buyAmt > 0 && sellAmt > 0 && sellAmt >= dust[address(sellGem)]) {
            // New offer should be created
            id = super.offer(sellAmt, sellGem, buyAmt, buyGem, owner);
            offers[id].oSellAmt = oSellAmt;         // set original taker pay amount
            offers[id].oBuyAmt = oBuyAmt;           // set original taker buy amount
            // Insert offer into the sorted list
            _sort(id, pos);
        }
    }

    function fokOffer(
        uint oSellAmt,                              // new offer sell amount
        ERC20 sellGem,                              // new offer sell token
        uint oBuyAmt,                               // new offer buy amount
        ERC20 buyGem,                               // new offer buy token
        bool forceSellAmt                           // if true, uses sellAmt as pivot, otherwise buyAmt
    ) public canOffer returns (uint sellAmt, uint buyAmt) {
        (sellAmt, buyAmt) = iocOffer(oSellAmt, sellGem, oBuyAmt, buyGem, forceSellAmt);

        if (forceSellAmt) {
            require(sellAmt == 0, "Not all sell amount was sold");
        } else {
            require(buyAmt == 0, "Not all buy amount was bought");
        }
    }

    function sellAllAmount(ERC20 sellGem, uint sellAmt_, ERC20 buyGem, uint minFillAmount) public returns (uint fillAmt) {
        require(!locked, "Reentrancy attempt");
        uint sellAmt = sellAmt_;
        uint offerId;
        while (sellAmt > 0) {                                               // while there is amount to sell
            offerId = best[address(buyGem)][address(sellGem)];              // Get the best offer for the token pair
            require(offerId != 0, "Not enough offers in market to sell tokens.");

            // There is a chance that sellAmt is smaller than 1 wei of the other token
            if (sellAmt * 1 ether < (offers[offerId].oBuyAmt * 1 ether / offers[offerId].oSellAmt)) {
                break;                                                      // We consider that all amount is sold
            }
            // If amount to sell is higher or equal than current offer amount to buy
            if (sellAmt >= offers[offerId].buyAmt) {
                fillAmt = add(fillAmt, offers[offerId].sellAmt);            // Add amount bought to acumulator
                sellAmt = sub(sellAmt, offers[offerId].buyAmt);             // Decrease amount to sell
                buy(offerId, offers[offerId].sellAmt);                      // We take the whole offer
            } else {                                                        // if lower
                uint baux = rmul(
                    sellAmt * 10 ** 9,
                    rdiv(offers[offerId].oSellAmt, offers[offerId].oBuyAmt)
                ) / 10 ** 9;
                fillAmt = add(fillAmt, baux);                               // Add amount bought to acumulator
                buy(offerId, baux);                                         // We take the portion of the offer that we need
                sellAmt = 0;                                                // All amount is sold
            }
        }
        require(fillAmt >= minFillAmount, "Not enough offers in market to sell tokens.");
    }

    function buyAllAmount(ERC20 buyGem, uint buyAmt_, ERC20 sellGem, uint maxFillAmt) public returns (uint fillAmt) {
        require(!locked, "Reentrancy attempt");
        uint buyAmt = buyAmt_;
        uint offerId;
        while (buyAmt > 0) {                                                // Meanwhile there is amount to buy
            offerId = best[address(buyGem)][address(sellGem)];              // Get the best offer for the token pair
            require(offerId != 0, "Not enough offers in market to buy tokens.");

            // There is a chance that buyAmt is smaller than 1 wei of the other token
            if (buyAmt * 1 ether < (offers[offerId].oSellAmt * 1 ether / offers[offerId].oBuyAmt)) {
                break;                                                      // We consider that all amount is sold
            }
            // If amount to buy is higher or equal than current offer amount to sell
            if (buyAmt >= offers[offerId].sellAmt) {
                fillAmt = add(fillAmt, offers[offerId].buyAmt);             // Add amount sold to acumulator
                buyAmt = sub(buyAmt, offers[offerId].sellAmt);              // Decrease amount to buy
                buy(offerId, offers[offerId].sellAmt);                      // We take the whole offer
            } else {                                                        // if lower
                fillAmt = add(
                    fillAmt,
                    rmul(
                        buyAmt * 10 ** 9,
                        rdiv(offers[offerId].oBuyAmt, offers[offerId].oSellAmt)
                    ) / 10 ** 9
                );                                                          // Add amount sold to acumulator
                buy(offerId, buyAmt);                                       // We take the portion of the offer that we need
                buyAmt = 0;                                                 // All amount is bought
            }
        }
        require(fillAmt <= maxFillAmt, "Not enough offers in market to buy tokens.");
    }

    // Make a new offer without putting it in the sorted list.
    // ***This function should only be called from smart contracts!***
    // ***Please call offer(,,,,uint pos) instead for placing a regular offer***
    // ***Offers created with this method will not be subject for offer matching!***
    // Takes funds from the caller into market escrow.
    // Keepers should call insert(id,pos) to put offer in the sorted list.
    function offer(
        uint sellAmt,                               // maker (ask) sell how much
        ERC20 sellGem,                              // maker (ask) sell which token
        uint buyAmt,                                // taker (ask) buy how much
        ERC20 buyGem                                // taker (ask) buy which token
    ) public returns (uint id) {
        id = offer(sellAmt, sellGem, buyAmt, buyGem, msg.sender);
    }

    function offer(
        uint sellAmt,                               // maker (ask) sell how much
        ERC20 sellGem,                              // maker (ask) sell which token
        uint buyAmt,                                // taker (ask) buy how much
        ERC20 buyGem,                               // taker (ask) buy which token
        address owner                               // owner of the offer to be created
    ) public returns (uint id) {
        require(!locked, "Reentrancy attempt");
        require(sellAmt >= dust[address(sellGem)], "Offer intends to sell less than required.");
        id = super.offer(sellAmt, sellGem, buyAmt, buyGem, owner);
        emit LogUnsortedOffer(id);
    }

    // Transfers funds from caller to offer maker, and from market to caller.
    function buy(uint id, uint amount) public canBuy(id) returns (bool) {
        require(!locked, "Reentrancy attempt");
        // If all the amount is bought, remove offer sorting data
        if (amount == offers[id].sellAmt){
            if (isOfferSorted(id)) {
                require(_unsort(id), "Offer could not be removed from sorted list.");
            }
        }
        require(super.buy(id, amount), "Too large, or too low buy quantity.");

        // If offer has become dust during buy, we cancel it
        if (isActive(id) && offers[id].sellAmt < dust[address(offers[id].sellGem)]) {
            dustId = id; //enable current msg.sender to call cancel(id)
            cancel(id);
        }
        return true;
    }

    // Cancel an offer. Refunds offer maker.
    function cancel(uint id) public canCancel(id) returns (bool success) {
        require(!locked, "Reentrancy attempt");
        if (isOfferSorted(id)) {
            require(_unsort(id), "Offer could not be removed from sorted list.");
        }
        return super.cancel(id);        // delete the offer.
    }

    // insert offer into the sorted list
    // keepers need to use this function
    function insert(
        uint id,                        // maker (ask) id
        uint pos                        // position to insert into
    ) public returns (bool) {
        require(!locked, "Reentrancy attempt");
        require(
            !isOfferSorted(id),         // make sure offers[id] is not yet sorted
            "Offer should not be in the sorted list."
        );
        require(
            isActive(id),               // make sure offers[id] is active
            "Offer has been canceled, taken, or never existed."
        );

        _sort(id, pos);                 // put offer into the sorted offers list
        emit LogInsert(msg.sender, id);
        return true;
    }

    // Set the dust limit for a token
    // Function is used to avoid "dust offers" that have
    // very small amount of tokens to sell, and it would
    // cost more gas to accept the offer, than the value
    // of tokens received.
    function setDustLimit(
        address sellGem,                // token to assign minimum sell amount to
        uint dustAmt                    // maker (ask) minimum sell amount
    ) public auth note returns (bool) {
        dust[sellGem] = dustAmt;
        emit LogDustLimit(sellGem, dustAmt);
        return true;
    }

    // Return the next worse offer in the sorted list
    // the worse offer is the higher one if its an ask,
    // a lower one if its a bid offer,
    // and in both cases the newer one if they're equal.
    function getWorseOffer(uint id) public view returns(uint) {
        return rank[id].prev;
    }

    // Return the next better offer in the sorted list
    // the better offer is in the lower priced one if its an ask,
    // the next higher priced one if its a bid offer
    // and in both cases the older one if they're equal.
    function getBetterOffer(uint id) public view returns(uint) {
        return rank[id].next;
    }

    function isOfferSorted(uint id) public view returns(bool) {
        return rank[id].next != 0 || rank[id].prev != 0 || best[address(offers[id].sellGem)][address(offers[id].buyGem)] == id;
    }

    // ---- Internal Functions ---- //

    // Find the id of the next higher offer after offers[id]
    function _findpos(uint id) internal view returns (uint) {
        require(id > 0, "Offer id can not be 0.");

        address buyGem = address(offers[id].buyGem);
        address sellGem = address(offers[id].sellGem);
        uint top = best[address(sellGem)][address(buyGem)];
        uint oldTop = 0;

        // Find the larger-than-id order whose successor is less-than-id.
        while (top != 0 && _isPricedLtOrEq(id, top)) {
            oldTop = top;
            top = rank[top].prev;
        }
        return oldTop;
    }

    // Find the id of the next higher offer after offers[id] (with initial pos to start)
    function _findpos(uint id, uint pos_) internal view returns (uint) {
        require(id > 0, "Offer id can not be 0.");

        uint pos = pos_;

        if (pos == 0) {
            // if we got to the end of list without a single active offer
            return _findpos(id);
        } else {
            // if we did find a nearby active offer
            // Walk the order book down from there...
            if(_isPricedLtOrEq(id, pos)) {
                uint oldPos;

                // Guaranteed to run at least once because of
                // the prior if statements.
                while (pos != 0 && _isPricedLtOrEq(id, pos)) {
                    oldPos = pos;
                    pos = rank[pos].prev;
                }
                return oldPos;
            // ...or walk it up.
            } else {
                while (pos != 0 && !_isPricedLtOrEq(id, pos)) {
                    pos = rank[pos].next;
                }
                return pos;
            }
        }
    }

    // Return true if offers[low] priced less than or equal to offers[high]
    function _isPricedLtOrEq(
        uint low,                                           // lower priced offer's id
        uint high                                           // higher priced offer's id
    ) internal view returns (bool) {
        return mul(offers[low].oBuyAmt, offers[high].oSellAmt) >=
        mul(offers[high].oBuyAmt, offers[low].oSellAmt);
    }

    // Put offer into the sorted list
    function _sort(
        uint id,                                            // maker (ask) id
        uint pos_                                           // position to insert into (it's an offer Id)
    ) internal {
        require(isActive(id), "Offer has been canceled, taken, or never existed.");

        uint pos = pos_;
        address buyGem = address(offers[id].buyGem);
        address sellGem = address(offers[id].sellGem);
        uint prevId;                                        // maker (ask) id

        pos = pos == 0 || address(offers[pos].sellGem) != sellGem || address(offers[pos].buyGem) != buyGem || !isOfferSorted(pos)
        ?
            _findpos(id)
        :
            _findpos(id, pos);

        if (pos != 0) {                                     // offers[id] is not the highest offer
            // Requirement below is satisfied by statements above
            // require(_isPricedLtOrEq(id, pos));
            prevId = rank[pos].prev;
            rank[pos].prev = id;
            rank[id].next = pos;
        } else {                                            // offers[id] is the highest offer
            prevId = best[address(sellGem)][address(buyGem)];
            best[address(sellGem)][address(buyGem)] = id;
        }

        if (prevId != 0) {                                  // if lower offer does exist
            // Requirement below is satisfied by statements above
            // require(!_isPricedLtOrEq(id, prevId));
            rank[prevId].next = id;
            rank[id].prev = prevId;
        }

        span[address(sellGem)][address(buyGem)]++;
        emit LogSortedOffer(id);
    }

    // Remove offer from the sorted list (does not cancel offer)
    function _unsort(
        uint id                                                 // id of maker (ask) offer to remove from sorted list
    ) internal returns (bool) {
        address buyGem = address(offers[id].buyGem);
        address sellGem = address(offers[id].sellGem);
        assert(span[address(sellGem)][address(buyGem)] > 0);

        require(
            isActive(id) && isOfferSorted(id),                  // assert id is in the sorted list
            "Offer has been canceled, taken, or never existed, or not sorted."
        );

        if (id != best[address(sellGem)][address(buyGem)]) {    // offers[id] is not the highest offer
            assert(rank[rank[id].next].prev == id);
            rank[rank[id].next].prev = rank[id].prev;
        } else {                                                // offers[id] is the highest offer
            best[address(sellGem)][address(buyGem)] = rank[id].prev;
        }

        if (rank[id].prev != 0) {                               // offers[id] is not the lowest offer
            assert(rank[rank[id].prev].next == id);
            rank[rank[id].prev].next = rank[id].next;
        }

        span[address(sellGem)][address(buyGem)]--;
        delete rank[id];
        return true;
    }
}
