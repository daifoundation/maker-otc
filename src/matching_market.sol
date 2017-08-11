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
    bool public buyEnabled = true;      //buy enabled
    bool public matchingEnabled = true; //true: enable matching,
                                         //false: revert to expiring market
    struct sortInfo {
        uint next;  //points to id of next higher offer
        uint prev;  //points to id of previous lower offer
    }
    mapping(uint => sortInfo) public _rank;                     //doubly linked list of sorted offer ids
    mapping(address => mapping(address => uint)) public _best;  //id of the highest offer for a token pair
    mapping(address => mapping(address => uint)) public _span;  //number of offers stored for token pair
    mapping(address => uint) public _dust;                      //minimum sell amount for a token to avoid dust offers
    mapping(uint => uint) public _near;         //next unsorted offer id
    mapping(bytes32 => bool) public _menu;      //whitelist tracking which token pairs can be traded
    uint _head;                                 //first unsorted offer id

    //check if token pair is enabled
    modifier isWhitelist(ERC20 buy_gem, ERC20 pay_gem) {
        require(_menu[sha3(buy_gem, pay_gem)] || _menu[sha3(pay_gem, buy_gem)]);
        _;
    }

    function MatchingMarket(uint64 lifetime) ExpiringMarket(lifetime, 0) {
    }

    // ---- Public entrypoints ---- //

    function make(
        ERC20    pay_gem,
        ERC20    buy_gem,
        uint128  pay_amt,
        uint128  buy_amt
    )
    returns (bytes32) {
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
    //
    // If matching is disabled:
    //     * calls expiring market's offer().
    //     * available to everyone without authorization.
    //     * no sorting is done.
    //
    function offer(
        uint pay_amt,    //maker (ask) sell how much
        ERC20 pay_gem,   //maker (ask) sell which token
        uint buy_amt,    //taker (ask) buy how much
        ERC20 buy_gem    //taker (ask) buy which token
    )
    isWhitelist(pay_gem, buy_gem)
    /* NOT synchronized!!! */
    returns (uint)
    {
        var fn = matchingEnabled ? _offeru : super.offer;
        return fn(pay_amt, pay_gem, buy_amt, buy_gem);
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    function offer(
        uint pay_amt,    //maker (ask) sell how much
        ERC20 pay_gem,   //maker (ask) sell which token
        uint buy_amt,    //maker (ask) buy how much
        ERC20 buy_gem,   //maker (ask) buy which token
        uint pos         //position to insert offer, 0 should be used if unknown
    )
    isWhitelist(pay_gem, buy_gem)
    /*NOT synchronized!!! */
    can_offer
    returns (uint)
    {
        require(_dust[pay_gem] <= pay_amt);

        if (matchingEnabled) {
          return _matcho(pay_amt, pay_gem, buy_amt, buy_gem, pos);
        }
        return super.offer(pay_amt, pay_gem, buy_amt, buy_gem);
    }

    //Transfers funds from caller to offer maker, and from market to caller.
    function buy(uint id, uint amount)
    /*NOT synchronized!!! */
    can_buy(id)
    returns (bool)
    {
        var fn = matchingEnabled ? _buys : super.buy;
        return fn(id, amount);
    }

    // Cancel an offer. Refunds offer maker.
    function cancel(uint id)
    /*NOT synchronized!!! */
    can_cancel(id)
    returns (bool success)
    {
        if (matchingEnabled) {
            _unsort(id);
        }
        return super.cancel(id);
    }

    //insert offer into the sorted list
    //keepers need to use this function
    function insert(
        uint id,   //maker (ask) id
        uint pos   //position to insert into
    )
    returns (bool)
    {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);

        //make sure offers[id] is not yet sorted
        require(_rank[id].next == 0);
        require(_rank[id].prev == 0);
        require(_best[pay_gem][buy_gem] != id);
        require(isActive(id));
        require(pos == 0 || isActive(pos));

        //take offer out of list of unsorted offers
        uint uid = _head; //id to search for `id` in unsorted offers list
        uint pre = 0;     //previous offer's id in unsorted offers list

        //find `id` in the unsorted list of offers
        while (uid > 0 && uid != id) {
            pre = uid;
            uid = _near[uid]; // _near is a chain of ids.
        }

        if (uid != id) {
            //did not find id
            return false;
        }

        if (_head == id) {
            _head = _near[id];
        } else {
            _near[pre] = _near[id];
        }

        _near[id] = 0;
        _sort(id, pos);

        return true;
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
        require(!isTokenPairWhitelisted(baseToken, quoteToken));
        require(address(baseToken) != 0x0 && address(quoteToken) != 0x0);

        _menu[sha3(baseToken, quoteToken)] = true;
        LogAddTokenPairWhitelist(baseToken, quoteToken);
        return true;
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
        require(isTokenPairWhitelisted(baseToken, quoteToken));

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
        uint dust          //maker (ask) minimum sell amount
    )
    auth
    note
    returns (bool)
    {
        _dust[pay_gem] = dust;
        LogMinSell(pay_gem, dust);
        return true;
    }

    //returns the minimum sell amount for an offer
    function getMinSell(
        ERC20 pay_gem      //token for which minimum sell amount is queried
    )
    constant
    returns (uint) {
        return _dust[pay_gem];
    }

    //set buy functionality enabled/disabled
    function setBuyEnabled(bool buyEnabled_) auth note returns (bool) {
        buyEnabled = buyEnabled_;
        LogBuyEnabled(buyEnabled);
        return true;
    }

    //set matching enabled/disabled
    //    If matchingEnabled true(default), then inserted offers are matched.
    //    Except the ones inserted by contracts, because those end up
    //    in the unsorted list of offers, that must be later sorted by
    //    keepers using insert().
    //    If matchingEnabled is false then MatchingMarket is reverted to ExpiringMarket,
    //    and matching is not done, and sorted lists are disabled.
    function setMatchingEnabled(bool matchingEnabled_) auth note returns (bool) {
        matchingEnabled = matchingEnabled_;
        LogMatchingEnabled(matchingEnabled);
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


    // ---- Internal Functions ---- //


    function _buys(uint id, uint amount)
    internal
    returns (bool)
    {
        require(buyEnabled);

        if (amount == offers[id].pay_amt) {
            //offers[id] must be removed from sorted list because all of it is bought
            _unsort(id);
        }
        assert(super.buy(id, amount));
        return true;
    }

    //find the id of the next higher offer after offers[id]
    function _find(uint id)
    internal
    returns (uint)
    {
        require( id > 0 );

        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        uint top = _best[pay_gem][buy_gem];

        if (_span[pay_gem][buy_gem] > 1) {
            //there are at least two offers stored for token pair
            if (!_isLtOrEq(id, top)) {
                //No  offer that has higher or equal price than offers[id]
                return 0;
            } else {
                //offers[top] is higher or equal priced than offers[id]

                //cycle through all offers for token pair to find the id
                //that is the next higher or equal to offers[id]
                while (_rank[top].prev != 0 && _isLtOrEq(id, _rank[top].prev)) {
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
            if (_isLtOrEq(id, top)) {
                //there is exactly one offer stored,
                //and it is higher or equal than offers[id]
                return top;
            } else {
                //there is exatly one offer stored, but lower than offers[id]
                return 0;
            }
        }
    }

    //return true if offers[low] priced less than or equal to offers[high]
    function _isLtOrEq(
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

    //these variables are global only because of solidity local variable limit
    uint m_buy_amt;        //maker offer wants to buy this much token
    uint m_pay_amt;        //maker offer wants to sell this much token
    bool isMatched;        //if true, taker offer should not be created, because it was already matched

    //match offers with taker offer, and execute token transactions
    function _matcho(
        uint t_pay_amt,    //taker sell how much
        ERC20 t_pay_gem,   //taker sell which token
        uint t_buy_amt,    //taker buy how much
        ERC20 t_buy_gem,   //taker buy which token
        uint pos           //position id
    )
    internal
    returns (uint id)
    {
        isMatched = false;          //taker offer should be created
        bool isTakerFilled = false; //has the taker offer been filled
        uint best_maker_id;         //highest maker id
        uint tab;                   //taker buy how much saved

        //offers[pos] should buy the same token as taker
        require(pos == 0
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
            _sort(id, pos);
        }
    }

    // Make a new offer without putting it in the sorted list.
    // Takes funds from the caller into market escrow.
    // ****Available to authorized contracts only!**********
    // Keepers should call insert(id,pos) to put offer in the sorted list.
    function _offeru(
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

    //put offer into the sorted list
    function _sort(
        uint id,    //maker (ask) id
        uint pos    //position to insert into
    )
    internal
    {
        require(isActive(id));

        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        uint lid; //lower maker (ask) id

        if (pos == 0
            || !isActive(pos)
            || !_isLtOrEq(id, pos)
            || (_rank[pos].prev != 0 && _isLtOrEq(id, _rank[pos].prev))
        ) {
            //client did not provide valid position,
            //so we have to find it
            pos = 0;
            if (_best[pay_gem][buy_gem] > 0 && _isLtOrEq(id, _best[pay_gem][buy_gem])) {
                //pos was 0 because user did not provide one
                pos = _find(id);
            }
        }

        //assert `pos` is in the sorted list or is 0
        require(pos == 0 || _rank[pos].next != 0 || _rank[pos].prev != 0 || _best[pay_gem][buy_gem] == pos);
        if (pos != 0) {
            //offers[id] is not the highest offer
            require(_isLtOrEq(id, pos));
            lid = _rank[pos].prev;
            _rank[pos].prev = id;
            _rank[id].next = pos;
        } else {
            //offers[id] is the highest offer
            lid = _best[pay_gem][buy_gem];
            _best[pay_gem][buy_gem] = id;
        }
        require(lid == 0 || offers[lid].pay_gem
               == offers[id].pay_gem);
        require(lid == 0 || offers[lid].buy_gem
               == offers[id].buy_gem);

        if (lid != 0) {
            //if lower offer does exist
            require(!_isLtOrEq(id, lid));
            _rank[lid].next = id;
            _rank[id].prev = lid;
        }
        _span[pay_gem][buy_gem]++;
        LogSortedOffer(id);
    }

    // Remove offer from the sorted list.
    function _unsort(
        uint id    //id of maker (ask) offer to remove from sorted list
    )
    internal
    returns (bool)
    {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);

        //assert id is in the sorted list
        require(_rank[id].next != 0 || _rank[id].prev != 0 || _best[pay_gem][buy_gem] == id);

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
        require(_span[pay_gem][buy_gem] > 0);
        _span[pay_gem][buy_gem]--;
        delete _rank[id].prev;
        delete _rank[id].next;
        return true;
    }
}
