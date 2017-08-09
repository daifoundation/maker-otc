pragma solidity ^0.4.13;

import "./expiring_market.sol";
import "ds-note/note.sol";

contract MatchingEvents {
    event LogBuyEnabled(bool isEnabled);
    event LogMinSell(address pay_gem, uint min_amount);
    event LogMatchingEnabled(bool isEnabled);
    event LogUnsortedOffer(uint id);
    event LogSortedOffer(uint id);
    event LogAddTokenPairWhitelist(ERC20 baseToken, ERC20 quoteToken);
    event LogRemTokenPairWhitelist(ERC20 baseToken, ERC20 quoteToken);
}

contract MatchingMarket is MatchingEvents, ExpiringMarket {
    bool public _buyEnabled = true;      //buy enabled
    bool public _matchingEnabled = true; //true: enable matching,
                                         //false: revert to expiring market
    struct sortInfo {
        uint next;  //points to id of next higher offer
        uint prev;  //points to id of previous lower offer
    }
    mapping(uint => sortInfo) public _rank;                     //doubly linked list of sorted offer ids
    mapping(address => mapping(address => uint)) public _best;  //id of the highest offer for a token pair
    mapping(address => mapping(address => uint)) public _span;  //number of offers stored for token pair
    mapping(address => uint) public _dust;                      //minimum sell amount for a token to avoid dust offers
    mapping(uint => uint) public _near;                         //next unsorted offer id
    mapping(bytes32 => bool) public _menu;                      //whitelist tracking which token pairs can be traded
    uint _head;                                                 //first unsorted offer id

    //check if token pair is enabled
    modifier isWhitelist(ERC20 buy_gem, ERC20 pay_gem) {
        if (!(_menu[sha3(buy_gem, pay_gem)] || _menu[sha3(pay_gem, buy_gem)])) {
            revert();  //token pair is not in whitelist
        }
        _;
    }

    function MatchingMarket(uint lifetime) ExpiringMarket(lifetime, 0) {
    }

    //return true if offers[low] priced less than or equal to offers[high]
    function isLtOrEq(
        uint low,   //lower priced offer's id
        uint high   //higher priced offer's id
    )
    internal
    returns (bool)
    {
        return
        mul(
            offers[low].buy_amt,
            offers[high].pay_amt
        )
        >=
        mul(
            offers[high].buy_amt,
            offers[low].pay_amt
        );
    }

    //find the id of the next higher offer after offers[id]
    function find(uint id)
    internal
    returns (uint)
    {
        assert( id > 0 );
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        uint top = _best[pay_gem][buy_gem];

        if (_span[pay_gem][buy_gem] > 1) {
            //there are at least two offers stored for token pair
            if (!isLtOrEq(id, top)) {
                //No  offer that has higher or equal price than offers[id]
                return 0;
            } else {
                //offers[top] is higher or equal priced than offers[id]

                //cycle through all offers for token pair to find the id
                //that is the next higher or equal to offers[id]
                while (_rank[top].prev != 0 && isLtOrEq(id, _rank[top].prev)) {
                    top = _rank[top].prev;
                }
                return top;
            }
        } else {
            //there is maximum one offer stored
            if (_best[pay_gem][buy_gem] == 0) {
                //there is no offer stored yet
                return 0;
            }
            if (isLtOrEq(id, top)) {
                //there is exactly one offer stored,
                //and it is higher or equal than offers[id]
                return top;
            } else {
                //there is exatly one offer stored, but lower than offers[id]
                return 0;
            }
        }
    }

    //put offer into the sorted list
    function sort(
        uint id,    //maker (ask) id
        uint pos    //position to insert into
    )
    internal
    {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        uint lid; //lower maker (ask) id

        assert(isActive(id));
        if (pos == 0
            || !isActive(pos)
            || !isLtOrEq(id, pos)
            || (_rank[pos].prev != 0 && isLtOrEq(id, _rank[pos].prev))
        ) {
            //client did not provide valid position,
            //so we have to find it
            pos = 0;
            if (_best[pay_gem][buy_gem] > 0 && isLtOrEq(id, _best[pay_gem][buy_gem])) {
                //pos was 0 because user did not provide one
                pos = find(id);
            }
        }
        //assert `pos` is in the sorted list or is 0
        assert(pos == 0 || _rank[pos].next != 0 || _rank[pos].prev != 0 || _best[pay_gem][buy_gem] == pos);
        if (pos != 0) {
            //offers[id] is not the highest offer
            assert(isLtOrEq(id, pos));
            lid = _rank[pos].prev;
            _rank[pos].prev = id;
            _rank[id].next = pos;
        } else {
            //offers[id] is the highest offer
            lid = _best[pay_gem][buy_gem];
            _best[pay_gem][buy_gem] = id;
        }
        assert(lid == 0 || offers[lid].pay_gem
               == offers[id].pay_gem);
        assert(lid == 0 || offers[lid].buy_gem
               == offers[id].buy_gem);

        if (lid != 0) {
            //if lower offer does exist
            assert(!isLtOrEq(id, lid));
            _rank[lid].next = id;
            _rank[id].prev = lid;
        }
        _span[pay_gem][buy_gem]++;
        LogSortedOffer(id);
    }
    // Remove offer from the sorted list.
    function unsort(
        uint id    //id of maker (ask) offer to remove from sorted list
    )
    internal
    returns (bool)
    {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);

        //assert id is in the sorted list
        assert(_rank[id].next != 0 || _rank[id].prev != 0 || _best[pay_gem][buy_gem] == id);

        if (id != _best[pay_gem][buy_gem]) {
            // offers[id] is not the highest offer
            _rank[_rank[id].next].prev = _rank[id].prev;
        } else {
            //offers[id] is the highest offer
            _best[pay_gem][buy_gem] = _rank[id].prev;
        }
        if (_rank[id].prev != 0) {
            //offers[id] is not the lowest offer
            _rank[_rank[id].prev].next = _rank[id].next;
        }
        assert (_span[pay_gem][buy_gem] > 0);
        _span[pay_gem][buy_gem]--;
        delete _rank[id].prev;
        delete _rank[id].next;
        return true;
    }

    //these variables are global only because of solidity local variable limit
    uint m_buy_amt;            //maker offer wants to buy this much token
    uint m_pay_amt;           //maker offer wants to sell this much token
    bool isMatched;                //if true, taker offer should not be created, because it was already matched

    //match offers with taker offer, and execute token transactions
    function matcho(
        uint t_pay_amt,       //taker sell how much
        ERC20 t_pay_gem,   //taker sell which token
        uint t_buy_amt,        //taker buy how much
        ERC20 t_buy_gem,    //taker buy which token
        uint pos                    //position id
    )
    internal
    returns (uint id)
    {
        isMatched = false;          //taker offer should be created
        bool isTakerFilled = false; //has the taker offer been filled
        uint best_maker_id;         //highest maker id
        uint tab;                   //taker buy how much saved

        //offers[pos] should buy the same token as taker
        assert(pos == 0
               || !isActive(pos)
               || (t_buy_gem == offers[pos].buy_gem) && t_pay_gem == offers[pos].pay_gem);

        while (!isTakerFilled && _best[t_buy_gem][t_pay_gem] > 0) {
            //matching is not done yet and there is at
            //least one offer stored for token pair
            best_maker_id = _best[t_buy_gem][t_pay_gem]; //store highest maker offer's id
            if (best_maker_id > 0) {
                //there is at least one maker offer stored
                m_buy_amt = offers[best_maker_id].buy_amt;
                m_pay_amt = offers[best_maker_id].pay_amt;
                if (mul(m_buy_amt , t_buy_amt) <= mul(t_pay_amt , m_pay_amt)
		    + m_buy_amt + t_buy_amt + t_pay_amt + m_pay_amt ) {
                    //maker price is lower than or equal to taker price + round-off error
                    if (m_pay_amt >= t_buy_amt) {
                        //maker wants to sell more than taker wants to buy
                        isMatched = true;
                        isTakerFilled = true;
                        buy(best_maker_id, t_buy_amt);
                    } else {
                        //maker wants to sell less than taker wants to buy
                        tab = t_buy_amt;
                        t_buy_amt = sub(t_buy_amt, m_pay_amt);
                        t_pay_amt = mul(t_buy_amt, t_pay_amt) / tab;
                        buy(best_maker_id, m_pay_amt);
                    }
                } else {
                    //lowest maker price is higher than current taker price
                    isTakerFilled = true;
                }
            } else {
                //there is no maker offer to match
                isTakerFilled = true;
            }
        }
        if (!isMatched) {
            //new offer should be created
            id = super.offer(t_pay_amt, t_pay_gem, t_buy_amt, t_buy_gem);
            //insert offer into the sorted list
            sort(id, pos);
        }
    }
    // Make a new offer without putting it in the sorted list.
    // Takes funds from the caller into market escrow.
    // ****Available to authorized contracts only!**********
    // Keepers should call insert(id,pos) to put offer in the sorted list.
    function offeru(
        uint pay_amt,         //maker (ask) sell how much
        ERC20 pay_gem,     //maker (ask) sell which token
        uint buy_amt,          //maker (ask) buy how much
        ERC20 buy_gem       //maker (ask) buy which token
    )
    auth
    internal
    /*NOT synchronized!!! */
    returns (uint id)
    {
        id = super.offer(pay_amt, pay_gem, buy_amt, buy_gem);
        //insert offer into the unsorted offers list
        _near[id] = _head;
        _head = id;
        LogUnsortedOffer(id);
    }

    // ---- Public entrypoints ---- //

    function make(
        ERC20    pay_gem,
        ERC20    buy_gem,
        uint128  pay_amt,
        uint128  buy_amt
    )
    returns (bytes32 id) {
        return bytes32(offer(pay_amt, pay_gem, buy_amt, buy_gem));
    }

    function take(bytes32 id, uint128 maxTakeAmount) {
        assert(buy(uint256(id), maxTakeAmount));
    }

    function kill(bytes32 id) {
        assert(cancel(uint256(id)));
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    //
    // If matching is enabled:
    //     * creates new offer without putting it in
    //       the sorted list.
    //     * available to authorized contracts only!
    //     * keepers should call insert(id,pos)
    //       to put offer in the sorted list.
    // If matching is disabled:
    //     * calls expiring market's offer().
    //     * available to everyone without authorization.
    //     * no sorting is done.
    /*NOT synchronized!!! */
    function offer(
        uint pay_amt,         //maker (ask) sell how much
        ERC20 pay_gem,     //maker (ask) sell which token
        uint buy_amt,          //maker (ask) buy how much
        ERC20 buy_gem       //maker (ask) buy which token
    )
    isWhitelist(pay_gem, buy_gem)
    returns (uint id)
    {
        if(_matchingEnabled) {
            //matching enabled
            id = offeru(pay_amt, pay_gem, buy_amt, buy_gem);
        } else {
            //revert to expiring market
            id = super.offer(pay_amt, pay_gem, buy_amt, buy_gem);
        }
    }
    // Make a new offer. Takes funds from the caller into market escrow.
    /*NOT synchronized!!! */
    function offer(
        uint pay_amt,         //maker (ask) sell how much
        ERC20 pay_gem,     //maker (ask) sell which token
        uint buy_amt,          //maker (ask) buy how much
        ERC20 buy_gem,      //maker (ask) buy which token
        uint pos                    //position to insert offer, 0 should be used if unknown
    )
    isWhitelist(pay_gem, buy_gem)
    can_offer
    returns (uint id)
    {
        //make sure 'sell how much' is greater than minimum required
        assert(_dust[pay_gem] <= pay_amt);
        if (_matchingEnabled) {
            //matching enabled
            id = matcho(pay_amt, pay_gem, buy_amt, buy_gem, pos);
        } else {
            //revert to expiring market
            id = super.offer(pay_amt, pay_gem, buy_amt, buy_gem);
        }
    }
    //Transfers funds from caller to offer maker, and from market to caller.
    function buy(
        uint id,        //maker (ask) offer's id that is to be bought
        uint amount     //quantity of token to buy
    )
    /*NOT synchronized!!! */
    can_buy(id)
    returns (bool success)
    {
        if (_matchingEnabled) {
            //matching enabled
            assert(_buyEnabled);     //buy enabled
            if(amount >= offers[id].pay_amt) {
                //offers[id] must be removed from sorted list because all of it is bought
                unsort(id);
            }
            assert(super.buy(id, amount));
            success = true;
        } else {
            //revert to expiring market
            success = super.buy(id, amount);
        }
    }
    // Cancel an offer. Refunds offer maker.
    function cancel(uint id)
    /*NOT synchronized!!! */
    can_cancel(id)
    returns (bool success)
    {
        if (_matchingEnabled) {
            //matching enabled
            unsort(id);
        }
        return super.cancel(id);
    }
    //insert offer into the sorted list
    //keepers need to use this function
    function insert(
        uint id,   //maker (ask) id
        uint pos    //position to insert into
                   )
    returns (bool)
    {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        uint uid; //id to search for `id` in unsorted offers list
        uint pre; //previous offer's id in unsorted offers list

        //make sure offers[id] is not yet sorted
        assert(_rank[id].next == 0);
        assert(_rank[id].prev == 0);
        assert(_best[pay_gem][buy_gem] != id);
        assert(isActive(id));
        assert(pos == 0 || isActive(pos));

        //take offer out of list of unsorted offers
        uid = _head;
        pre = 0;

        //find `id` in the unsorted list of offers
        while(uid > 0 && uid != id) {
            //while not found `id`
            pre = uid;
            uid = _near[uid];
        }
        if (pre == 0) {
            //uid was the first in the unsorted offers list
            if (uid == id) {
                //uid was the first in unsorted offers list
                _head = _near[uid];
                _near[uid] = 0;
                sort(id, pos);
                return true;
            }
            //there were no offers in the unsorted list
            return false;
        } else {
            //uid was not the first in the unsorted offers list
            if (uid == id) {
                //uid was not the first in the list but we found id
                _near[pre] = _near[uid];
                _near[uid] = 0;
                sort(id, pos);
                return true;
            }
            //did not find id
            return false;
        }
    }

    //returns true if token is succesfully added to whitelist
    //  Function is used to add a token pair to the whitelist
    //  All incoming offers are checked against the whitelist.
    function addTokenPairWhitelist(
        ERC20 baseToken,
        ERC20 quoteToken
    )
    public
    auth
    note
    returns (bool)
    {
        if (address(baseToken) == 0x0 || address(quoteToken) == 0x0) {
            revert();  //invalid ERC20 token address
        }
        if (isTokenPairWhitelisted(baseToken, quoteToken)) {
            revert();  //token pair already in whitelist
        }
        _menu[sha3(baseToken, quoteToken)] = true;
        LogAddTokenPairWhitelist(baseToken, quoteToken);
        if (_menu[sha3(baseToken, quoteToken)]) return true;
        else revert(); //unexepected error with checking added token pair
    }

    //returns true if token is successfully removed from whitelist
    //  Function is used to remove a token pair from the whitelist.
    //  All incoming offers are checked against the whitelist.
    function remTokenPairWhitelist(
        ERC20 baseToken,
        ERC20 quoteToken
    )
    public
    auth
    note
    returns (bool)
    {
        if (address(baseToken) == 0x0 || address(quoteToken) == 0x0) {
            revert();  //invalid ERC20 token address
        }
        if (!(_menu[sha3(baseToken, quoteToken)] || _menu[sha3(quoteToken, baseToken)])) {
            revert();  //whitelist does not contain token pair
        }
        delete _menu[sha3(baseToken, quoteToken)];
        delete _menu[sha3(quoteToken, baseToken)];
        LogRemTokenPairWhitelist(baseToken, quoteToken);
        return true;
    }

    function isTokenPairWhitelisted(
        ERC20 baseToken,
        ERC20 quoteToken
    )
    public
    constant
    returns (bool)
    {
        return (_menu[sha3(baseToken, quoteToken)] || _menu[sha3(quoteToken, baseToken)]);
    }

    //set the minimum sell amount for a token
    //    Function is used to avoid "dust offers" that have
    //    very small amount of tokens to sell, and it would
    //    cost more gas to accept the offer, than the value
    //    of tokens received.
    function setMinSell(
        ERC20 pay_gem,     //token to assign minimum sell amount to
        uint dust                  //maker (ask) minimum sell amount
    )
    auth
    note
    returns (bool suc) {
        _dust[pay_gem] = dust;
        LogMinSell(pay_gem, dust);
        suc = true;
    }
    //returns the minimum sell amount for an offer
    function getMinSell(
        ERC20 pay_gem      //token for which minimum sell amount is queried
    )
    constant
    returns (uint) {
        return _dust[pay_gem];
    }

    //the call of buy() function is enabled (offer sniping)
    //    Returns true, if users can click and buy any arbitrary offer,
    //    not only the lowest one. Users can also buy unsorted offers as
    //    well.
    //    Returns false, if users are not allowed to buy arbitrary offers.
    function isBuyEnabled() constant returns (bool) {
        return _buyEnabled;
    }

    //set buy functionality enabled/disabled
    function setBuyEnabled(bool buyEnabled) auth note returns (bool) {
        _buyEnabled = buyEnabled;
        LogBuyEnabled(_buyEnabled);
        return true;
    }

    //is otc offer matching enabled?
    //      Returns true if offers will be matched if possible.
    //      Returns false if contract is reverted to ExpiringMarket
    //      and no matching is done for new offers.
    function isMatchingEnabled() constant returns (bool) {
        return _matchingEnabled;
    }

    //set matching enabled/disabled
    //    If matchingEnabled true(default), then inserted offers are matched.
    //    Except the ones inserted by contracts, because those end up
    //    in the unsorted list of offers, that must be later sorted by
    //    keepers using insert().
    //    If matchingEnabled is false then MatchingMarket is reverted to ExpiringMarket,
    //    and matching is not done, and sorted lists are disabled.
    function setMatchingEnabled(bool matchingEnabled) auth note returns (bool) {
        _matchingEnabled = matchingEnabled;
        LogMatchingEnabled(_matchingEnabled);
        return true;
    }

    //return the best offer for a token pair
    //      the best offer is the lowest one if it's an ask,
    //      and highest one if it's a bid offer
    function getBestOffer(ERC20 sell_gem, ERC20 buy_gem) constant returns(uint) {
        return _best[sell_gem][buy_gem];
    }

    //return the next worse offer in the sorted list
    //      the worse offer is the higher one if its an ask,
    //      and lower one if its a bid offer
    function getWorseOffer(uint id) constant returns(uint) {
        return _rank[id].prev;
    }

    //return the next better offer in the sorted list
    //      the better offer is in the lower priced one if its an ask,
    //      and next higher priced one if its a bid offer
    function getBetterOffer(uint id) constant returns(uint) {
        return _rank[id].next;
    }

    //return the amount of better offers for a token pair
    function getOfferCount(ERC20 sell_gem, ERC20 buy_gem) constant returns(uint) {
        return _span[sell_gem][buy_gem];
    }

    //get the first unsorted offer that was inserted by a contract
    //      Contracts can't calculate the insertion position of their offer because it is not an O(1) operation.
    //      Their offers get put in the unsorted list of offers.
    //      Keepers can calculate the insertion position offchain and pass it to the insert() function to insert
    //      the unsorted offer into the sorted list. Unsorted offers will not be matched, but can be bought with buy().
    function getFirstUnsortedOffer() constant returns(uint) {
        return _head;
    }

    //get the next unsorted offer
    //      Can be used to cycle through all the unsorted offers.
    function getNextUnsortedOffer(uint id) constant returns(uint) {
        return _near[id];
    }
}
