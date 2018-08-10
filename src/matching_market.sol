pragma solidity ^0.4.24;

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
    mapping(uint => uint) public near;                          // next unsorted offer id
    uint public head;                                           // first unsorted offer id
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

    // Make a new offer. Takes funds from the caller into market escrow.
    function offer(
        uint oSellAmt,                              // new offer sell amount
        ERC20 sellGem,                              // new offer sell token
        uint oBuyAmt,                               // new offer buy amount
        ERC20 buyGem,                               // new offer buy token
        uint pos                                    // position to insert offer, 0 should be used if unknown
    ) public canOffer returns (uint id) {
        require(dust[sellGem] <= oSellAmt, "Offer intends to sell less than required.");
        (uint sellAmt, uint buyAmt) = buyOffers(oSellAmt, sellGem, oBuyAmt, buyGem);

        // Create new taker offer if necessary
        if (buyAmt > 0 && sellAmt > dust[sellGem]) {
            // New offer should be created
            id = super.offer(sellAmt, sellGem, buyAmt, buyGem);
            offers[id].oSellAmt = oSellAmt;         // set original taker pay amount
            offers[id].oBuyAmt = oBuyAmt;           // set original taker buy amount
            // Insert offer into the sorted list
            _sort(id, pos);
        }
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
        require(dust[sellGem] <= sellAmt, "Offer intends to sell less than required.");
        id = super.offer(sellAmt, sellGem, buyAmt, buyGem);
        near[id] = head;
        head = id;
        emit LogUnsortedOffer(id);
    }

    // Transfers funds from caller to offer maker, and from market to caller.
    function buy(uint id, uint amount) public canBuy(id) returns (bool) {
        // If all the amount is bought, remove offer sorting data
        if (amount == offers[id].sellAmt){
            if (isOfferSorted(id)) {
                require(_unsort(id), "Offer could not be removed from sorted list.");
            } else {
                require(_hide(id), "Offer could not be removed from unsorted list.");
            }
        }
        require(super.buy(id, amount), "Too large, or too low buy quantity.");

        // If offer has become dust during buy, we cancel it
        if (isActive(id) && offers[id].sellAmt < dust[offers[id].sellGem]) {
            dustId = id; //enable current msg.sender to call cancel(id)
            cancel(id);
        }
        return true;
    }

    function buyOffers(
        uint oSellAmt,                              // taker sell amount (original value)
        ERC20 sellGem,                              // taker sell token
        uint oBuyAmt,                               // taker buy amount (original value)
        ERC20 buyGem                                // taker buy token
    ) public returns (uint sellAmt, uint buyAmt) {
        require(dust[sellGem] <= oSellAmt, "Offer sell quantity is less then required.");

        sellAmt = oSellAmt;                         // taker sell amount (countdown)
        buyAmt = oBuyAmt;                           // taker buy amount (countdown)
        uint bestMatchingId;                        // best matching id

        // There is at least one offer stored for token pair
        while ((bestMatchingId = best[buyGem][sellGem]) > 0) {
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

            uint amountToBuy = min(offers[bestMatchingId].sellAmt, buyAmt);
            buy(bestMatchingId, amountToBuy);
            buyAmt = sub(buyAmt, amountToBuy);
            sellAmt = mul(buyAmt, oSellAmt) / oBuyAmt;

            if (sellAmt == 0 || buyAmt == 0) {
                break;
            }
        }
    }

    // Cancel an offer. Refunds offer maker.
    function cancel(uint id) public canCancel(id) returns (bool success) {
        if (isOfferSorted(id)) {
            require(_unsort(id), "Offer could not be removed from sorted list.");
        } else {
            require(_hide(id), "Offer could not be removed from unsorted list.");
        }
        return super.cancel(id);        // delete the offer.
    }

    // insert offer into the sorted list
    // keepers need to use this function
    function insert(
        uint id,                        // maker (ask) id
        uint pos                        // position to insert into
    ) public returns (bool) {
        require(
            !isOfferSorted(id),         // make sure offers[id] is not yet sorted
            "Offer should not be in the sorted list."
        );
        require(
            isActive(id),               // make sure offers[id] is active
            "Offer has been canceled, taken, or never existed."
        );

        _hide(id);                      // remove offer from unsorted offers list
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
        ERC20 sellGem,                  // token to assign minimum sell amount to
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
        return rank[id].next != 0 || rank[id].prev != 0 || best[offers[id].sellGem][offers[id].buyGem] == id;
    }

    function sellAllAmount(ERC20 sellGem, uint sellAmt_, ERC20 buyGem, uint minFillAmount) public returns (uint fillAmt) {
        uint sellAmt = sellAmt_;
        uint offerId;
        while (sellAmt > 0) {                                               // while there is amount to sell
            offerId = best[buyGem][sellGem];                                // Get the best offer for the token pair
            require(
                offerId != 0,                                               // Fails if there are not more offers
                "Not enough offers in market to sell tokens."
            );

            // There is a chance that sellAmt is smaller than 1 wei of the other token
            if (sellAmt * 1 ether < wdiv(offers[offerId].oBuyAmt, offers[offerId].oSellAmt)) {
                break;                                                      // We consider that all amount is sold
            }
            // If amount to sell is higher or equal than current offer amount to buy
            if (sellAmt >= offers[offerId].buyAmt) {
                fillAmt = add(fillAmt, offers[offerId].sellAmt);            // Add amount bought to acumulator
                sellAmt = sub(sellAmt, offers[offerId].buyAmt);             // Decrease amount to sell
                buy(offerId, uint128(offers[offerId].sellAmt));             // We take the whole offer
            } else {                                                        // if lower
                uint baux = rmul(
                    sellAmt * 10 ** 9,
                    rdiv(offers[offerId].oSellAmt, offers[offerId].oBuyAmt)
                ) / 10 ** 9;
                fillAmt = add(fillAmt, baux);                               // Add amount bought to acumulator
                buy(offerId, uint128(baux));                                // We take the portion of the offer that we need
                sellAmt = 0;                                                // All amount is sold
            }
        }
        require(fillAmt >= minFillAmount, "Not enough offers in market to sell tokens.");
    }

    function buyAllAmount(ERC20 buyGem, uint buyAmt_, ERC20 sellGem, uint maxFillAmt) public returns (uint fillAmt) {
        uint buyAmt = buyAmt_;
        uint offerId;
        while (buyAmt > 0) {                                                // Meanwhile there is amount to buy
            offerId = best[buyGem][sellGem];                                // Get the best offer for the token pair
            require(offerId != 0, "Not enough offers in market to buy tokens.");

            // There is a chance that buyAmt is smaller than 1 wei of the other token
            if (buyAmt * 1 ether < wdiv(offers[offerId].oSellAmt, offers[offerId].oBuyAmt)) {
                break;                                                      // We consider that all amount is sold
            }
            // If amount to buy is higher or equal than current offer amount to sell
            if (buyAmt >= offers[offerId].sellAmt) {
                fillAmt = add(fillAmt, offers[offerId].buyAmt);             // Add amount sold to acumulator
                buyAmt = sub(buyAmt, offers[offerId].sellAmt);              // Decrease amount to buy
                buy(offerId, uint128(offers[offerId].sellAmt));             // We take the whole offer
            } else {                                                        // if lower
                fillAmt = add(
                    fillAmt,
                    rmul(
                        buyAmt * 10 ** 9,
                        rdiv(offers[offerId].oBuyAmt, offers[offerId].oSellAmt)
                    ) / 10 ** 9
                );                                                          // Add amount sold to acumulator
                buy(offerId, uint128(buyAmt));                              // We take the portion of the offer that we need
                buyAmt = 0;                                                 // All amount is bought
            }
        }
        require(fillAmt <= maxFillAmt, "Not enough offers in market to buy tokens.");
    }

    function getBuyAmount(ERC20 buyGem, ERC20 sellGem, uint sellAmt_) public view returns (uint fillAmt) {
        uint sellAmt = sellAmt_;
        uint offerId = best[buyGem][sellGem];                               // Get best offer for the token pair
        while (sellAmt > offers[offerId].buyAmt) {
            fillAmt = add(fillAmt, offers[offerId].sellAmt);                // Add amount to buy accumulator
            sellAmt = sub(sellAmt, offers[offerId].buyAmt);                 // Decrease amount to pay
            if (sellAmt > 0) {                                              // If we still need more offers
                offerId = getWorseOffer(offerId);                           // We look for the next best offer
                require(
                    offerId != 0,                                           // Fails if there are not enough offers to complete
                    "Not enough offers in market to buy tokens."
                );
            }
        }
        fillAmt = add(
            fillAmt,
            rmul(
                sellAmt * 10 ** 9,
                rdiv(offers[offerId].sellAmt, offers[offerId].buyAmt)
            ) / 10 ** 9
        );                                                                  // Add proportional amount of last offer to buy accumulator
    }

    function getPayAmount(ERC20 sellGem, ERC20 buyGem, uint buyAmt_) public view returns (uint fillAmt) {
        uint buyAmt = buyAmt_;
        uint offerId = best[buyGem][sellGem];                               // Get best offer for the token pair
        while (buyAmt > offers[offerId].sellAmt) {
            fillAmt = add(fillAmt, offers[offerId].buyAmt);                 // Add amount to pay accumulator
            buyAmt = sub(buyAmt, offers[offerId].sellAmt);                  // Decrease amount to buy
            if (buyAmt > 0) {                                               // If we still need more offers
                offerId = getWorseOffer(offerId);                           // We look for the next best offer
                require(
                    offerId != 0,                                           // Fails if there are not enough offers to complete
                    "Not enough offers in market to sell tokens."
                );
            }
        }
        fillAmt = add(
            fillAmt,
            rmul(
                buyAmt * 10 ** 9,
                rdiv(offers[offerId].buyAmt, offers[offerId].sellAmt)
            ) / 10 ** 9
        );                                                                  // Add proportional amount of last offer to pay accumulator
    }

    // ---- Internal Functions ---- //

    // Find the id of the next higher offer after offers[id]
    function _findpos(uint id) internal view returns (uint) {
        require(id > 0, "Offer id can not be 0.");

        address buyGem = address(offers[id].buyGem);
        address sellGem = address(offers[id].sellGem);
        uint top = best[sellGem][buyGem];
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

        if (pos == 0 || !isOfferSorted(pos)) {
            pos = _findpos(id);
        } else {
            pos = _findpos(id, pos);
            require(
                pos == 0 || (offers[pos].sellGem == offers[id].sellGem && offers[pos].buyGem == offers[id].buyGem),
                "Tokenpair belonging to 'id' must be the same as the one belonging to 'pos'."
            );
        }

        // Requirement below is satisfied by statements above
        // require(pos == 0 || isOfferSorted(pos));

        if (pos != 0) {                                     // offers[id] is not the highest offer
            // Requirement below is satisfied by statements above
            // require(_isPricedLtOrEq(id, pos));
            prevId = rank[pos].prev;
            rank[pos].prev = id;
            rank[id].next = pos;
        } else {                                            // offers[id] is the highest offer
            prevId = best[sellGem][buyGem];
            best[sellGem][buyGem] = id;
        }

        if (prevId != 0) {                                  // if lower offer does exist
            // Requirement below is satisfied by statements above
            // require(!_isPricedLtOrEq(id, prevId));
            rank[prevId].next = id;
            rank[id].prev = prevId;
        }

        span[sellGem][buyGem]++;
        emit LogSortedOffer(id);
    }

    // Remove offer from the sorted list (does not cancel offer)
    function _unsort(
        uint id                                             // id of maker (ask) offer to remove from sorted list
    ) internal returns (bool) {
        address buyGem = address(offers[id].buyGem);
        address sellGem = address(offers[id].sellGem);
        assert(span[sellGem][buyGem] > 0);

        require(
            isActive(id) && isOfferSorted(id),              // assert id is in the sorted list
            "Offer has been canceled, taken, or never existed, or not sorted."
        );

        if (id != best[sellGem][buyGem]) {                  // offers[id] is not the highest offer
            assert(rank[rank[id].next].prev == id);
            rank[rank[id].next].prev = rank[id].prev;
        } else {                                            // offers[id] is the highest offer
            best[sellGem][buyGem] = rank[id].prev;
        }

        if (rank[id].prev != 0) {                           // offers[id] is not the lowest offer
            assert(rank[rank[id].prev].next == id);
            rank[rank[id].prev].next = rank[id].next;
        }

        span[sellGem][buyGem]--;
        delete rank[id];
        return true;
    }

    // Hide offer from the unsorted order book (does not cancel offer)
    function _hide(
        uint id                                             // id of maker offer to remove from unsorted list
    ) internal returns (bool) {
        uint uid = head;                                    // id of an offer in unsorted offers list
        uint pre = uid;                                     // id of previous offer in unsorted offers list

        require(!isOfferSorted(id), "Offer is sorted.");    // make sure offer id is not in sorted offers list

        if (head == id) {                                   // check if offer is first offer in unsorted offers list
            head = near[id];                                // set head to new first unsorted offer
            near[id] = 0;                                   // delete order from unsorted order list
            return true;
        }
        while (uid > 0 && uid != id) {                      // find offer in unsorted order list
            pre = uid;
            uid = near[uid];
        }
        if (uid != id) {                                    // did not find offer id in unsorted offers list
            return false;
        }
        near[pre] = near[id];                               // set previous unsorted offer to point to offer after offer id
        near[id] = 0;                                       // delete order from unsorted order list
        return true;
    }
}
