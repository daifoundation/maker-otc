pragma solidity ^0.4.8;

import "./expiring_market.sol";
import "ds-note/note.sol";

contract MatchingEvents {
    event LogBuyEnabled(bool isEnabled);
    event LogMinSell(address sell_which_token, uint min_amount);
    event LogMatchingEnabled(bool isEnabled);
    event LogUnsortedOffer(uint id);
    event LogSortedOffer(uint id);
}

contract MatchingMarket is MatchingEvents, ExpiringMarket, DSNote {
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
    mapping(bytes => mapping(bytes => bool)) _menu;             //whitelist tracking which token pairs can be traded
    uint _head;                                                 //first unsorted offer id

    //check if token pair is enabled
    modifier isWhitelist(bytes buy_which_token, bytes sell_which_token) {
        if(!(_menu[buy_which_token][sell_which_token] || _menu[sell_which_token][buy_which_token])) {
            throw;  //token pair is not in whitelist
        }   
        _;
    }

    //returns true if token is succesfully added to whitelist
    function addTokenWhitelist(
        bytes baseToken,
        bytes quoteToken
    )
    public
    auth
    returns (bool)
    {
        if (baseToken.length == 0 || quoteToken.length == 0) {
            throw;  //invalid token name(s)
        }
        _menu[baseToken][quoteToken] = true;
        return true;
    }

    //returns true if token is successfully removed from whitelist
    function remTokenWhitelist(
        bytes baseToken,
        bytes quoteToken
    )
    public
    auth
    returns (bool)
    {
        if (baseToken.length == 0 || quoteToken.length == 0) {
            throw;  //invalid token name(s)
        }
        delete _menu[baseToken][quoteToken];
        return true;
    }

    function MatchingMarket(uint lifetime) ExpiringMarket(lifetime) {
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
        safeMul(  
            offers[low].buy_how_much,
            offers[high].sell_how_much
        ) 
        >= 
        safeMul( 
            offers[high].buy_how_much,
            offers[low].sell_how_much
        ); 
    }

    //find the id of the next higher offer after offers[id]
    function find(uint id)
    internal
    returns (uint)
    {
        assert( id > 0 ); 
        address buy_which_token = address(offers[id].buy_which_token);
        address sell_which_token = address(offers[id].sell_which_token);
        uint top = _best[sell_which_token][buy_which_token];

        if (_span[sell_which_token][buy_which_token] > 1) {
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
            if (_best[sell_which_token][buy_which_token] == 0) {
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
        address buy_which_token = address(offers[id].buy_which_token);
        address sell_which_token = address(offers[id].sell_which_token);
        uint lid; //lower maker (ask) id
        uint hid; //higher maker (ask) id
        uint hsi; //highest maker (ask) id

        assert(isActive(id));
        if ( pos == 0
            || !isActive(pos) 
            || !isLtOrEq(id, pos)
            || (_rank[pos].prev != 0 && isLtOrEq(id, _rank[pos].prev)) 
        ) {
            //client did not provide valid position, 
            //so we have to find it 
            pos = 0;
            if( _best[sell_which_token][buy_which_token] > 0 && isLtOrEq(id, _best[sell_which_token][buy_which_token])) {
                //pos was 0 because user did not provide one  
                pos = find(id);
            }
        }
        //assert `pos` is in the sorted list or is 0
        assert(pos == 0 || _rank[pos].next != 0 || _rank[pos].prev != 0 || _best[sell_which_token][buy_which_token] == pos);
        if (pos != 0) {
            //offers[id] is not the highest offer
            assert(isLtOrEq(id, pos));
            lid = _rank[pos].prev;
            _rank[pos].prev = id;
            _rank[id].next = pos;
        } else {
            //offers[id] is the highest offer
            lid = _best[sell_which_token][buy_which_token];
            _best[sell_which_token][buy_which_token] = id;
        }
        assert(lid == 0 || offers[lid].sell_which_token 
               == offers[id].sell_which_token); 
        assert(lid == 0 || offers[lid].buy_which_token 
               == offers[id].buy_which_token);

        if ( lid != 0 ) {
            //if lower offer does exist
            assert(!isLtOrEq(id, lid)); 
            _rank[lid].next = id;
            _rank[id].prev = lid;
        }
        _span[sell_which_token][buy_which_token]++;
        LogSortedOffer(id);
    }
    // Remove offer from the sorted list.
    function unsort(
        uint id    //id of maker (ask) offer to remove from sorted list
    )
    internal
    returns (bool)
    {
        address buy_which_token = address(offers[id].buy_which_token);
        address sell_which_token = address(offers[id].sell_which_token);

        //assert id is in the sorted list
        assert(_rank[id].next != 0 || _rank[id].prev != 0 || _best[sell_which_token][buy_which_token] == id);
    
        if (id != _best[sell_which_token][buy_which_token]) {
            // offers[id] is not the highest offer
            _rank[_rank[id].next].prev = _rank[id].prev;
        } else {
            //offers[id] is the highest offer
            _best[sell_which_token][buy_which_token] = _rank[id].prev;
        }
        if (_rank[id].prev != 0) {
            //offers[id] is not the lowest offer
            _rank[_rank[id].prev].next = _rank[id].next;
        }
        assert (_span[sell_which_token][buy_which_token] > 0);
        _span[sell_which_token][buy_which_token]--;
        delete _rank[id].prev;
        delete _rank[id].next;
        return true;
    }

    //these variables are global only because of solidity local variable limit
    uint _buy_how_much;      //maker(ask) offer wants to buy this much token
    uint _sell_how_much;     //maker(ask) offer wants to sell this much token
    bool _isMatched;         //if true, taker(bid) offer should not be created, because it was already matched

    //match offers with taker(bid) offer, and execute token transactions
    function matcho( 
        uint tsh,   //taker(bid) sell how much
        ERC20 tst,  //taker(bid) sell which token
        uint tbh,   //taker(bid) buy how much
        ERC20 tbt,  //taker(bid) buy which token
        uint pos    //position id
    )
    internal
    returns (uint id)
    {
        _isMatched = false;  //taker offer should be created
        bool yet = true;    //matching not done yet
        uint mes;           //highest maker (ask) id
        uint tab;           //taker (bid) buy how much saved  
        
        //offers[pos] should buy the same token as taker 
        assert(pos == 0 
               || !isActive(pos) 
               || tbt == offers[pos].buy_which_token);

        //offers[pos] should sell the same token as taker 
        assert(pos == 0 
               || !isActive(pos) 
               || tst == offers[pos].sell_which_token);

        while (yet && _best[tbt][tst] > 0) {
            //matching is not done yet and there is at 
            //least one offer stored for token pair
            mes = _best[tbt][tst]; //store highest maker (ask) offer's id
            if (mes > 0) {
                //there is at least one maker (ask) offer stored 
                _buy_how_much = offers[mes].buy_how_much;
                _sell_how_much = offers[mes].sell_how_much;
                if (safeMul(_buy_how_much , tbh ) <= safeMul(tsh , _sell_how_much)) {
                    //maker (ask) price is lower than or equal to 
                    //taker (bid) price
                    if (_sell_how_much >= tbh) {
                        //maker (ask) wants to sell more than 
                        //taker(bid) wants to buy
                        _isMatched = true;
                        yet = false;
                        buy(mes, tbh);
                    } else {
                        //maker(ask) wants to sell less than 
                        //taker(bid) wants to buy
                        tab = tbh; 
                        tbh = safeSub(tbh, _sell_how_much);
                        tsh = safeMul(tbh, tsh) / tab;
                        buy(mes, _sell_how_much);
                    }
                } else {
                    //lowest maker (ask) price is higher than 
                    //current taker (bid) price
                    yet = false;
                }
            } else {
                //there is no maker (ask) offer to match
                yet = false;
            }
        }
        if (!_isMatched) {
            //new offer should be created            
            id = super.offer(tsh, tst, tbh, tbt);
            //insert offer into the sorted list
            sort(id, pos);
        }
    }
    // Make a new offer without putting it in the sorted list.
    // Takes funds from the caller into market escrow.
    // ****Available to authorized contracts only!**********
    // Keepers should call insert(id,pos) to put offer in the sorted list.
    function offeru( 
        uint sell_how_much,         //maker (ask) sell how much
        ERC20 sell_which_token,     //maker (ask) sell which token
        uint buy_how_much,          //maker (ask) buy how much
        ERC20 buy_which_token       //maker (ask) buy which token
    )
    auth
    internal
    /*NOT synchronized!!! */
    returns (uint id) 
    {
        id = super.offer(sell_how_much, sell_which_token, buy_how_much, buy_which_token); 
        //insert offer into the unsorted offers list
        _near[id] = _head;
        _head = id;
        LogUnsortedOffer(id);
    }

    // ---- Public entrypoints ---- //
    function make(
        ERC20    haveToken,
        ERC20    wantToken,
        uint128  haveAmount,
        uint128  wantAmount
    ) returns (bytes32 id) {
        return bytes32(offer(haveAmount, haveToken, wantAmount, wantToken));
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

    function offer( 
        uint sell_how_much,                   //maker (ask) sell how much
        ERC20 sell_which_token,     //maker (ask) sell which token
        uint buy_how_much,                   //maker (ask) buy how much
        ERC20 buy_which_token       //maker (ask) buy which token
    )
    /*NOT synchronized!!! */
    returns (uint id) 
    {
        if(_matchingEnabled) {
            //matching enabled
            id = offeru(sell_how_much, sell_which_token, buy_how_much, buy_which_token); 
        } else {
            //revert to expiring market
            id = super.offer(sell_how_much, sell_which_token, buy_how_much, buy_which_token); 
        } 
    }
    // Make a new offer. Takes funds from the caller into market escrow.
    function offer( 
        uint sell_how_much,                   //maker (ask) sell how much
        ERC20 sell_which_token,     //maker (ask) sell which token
        uint buy_how_much,                   //maker (ask) buy how much
        ERC20 buy_which_token,      //maker (ask) buy which token
        uint pos                    //position to insert offer, 0 should be used if unknown
    )
    /*NOT synchronized!!! */
    can_offer
    returns (uint id)
    {
        //make sure 'sell how much' is greater than minimum required 
        assert(_dust[sell_which_token] <= sell_how_much);
        if (_matchingEnabled) {
            //matching enabled
            id = matcho(sell_how_much, sell_which_token, buy_how_much, buy_which_token, pos);
        } else {
            //revert to expiring market
            id = super.offer(sell_how_much, sell_which_token, buy_how_much, buy_which_token);
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
            if(amount >= offers[id].sell_how_much) {
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
        address buy_which_token = address(offers[id].buy_which_token);
        address sell_which_token = address(offers[id].sell_which_token);
        uint uid; //id to search for `id` in unsorted offers list
        uint pre; //previous offer's id in unsorted offers list

        //make sure offers[id] is not yet sorted
        assert(_rank[id].next == 0);
        assert(_rank[id].prev == 0);
        assert(_best[sell_which_token][buy_which_token] != id);
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

    //set the minimum sell amount for a token
    //    Function is used to avoid "dust offers" that have 
    //    very small amount of tokens to sell, and it would 
    //    cost more gas to accept the offer, than the value 
    //    of tokens received.
    function setMinSell(
        ERC20 sell_which_token,     //token to assign minimum sell amount to
        uint dust                  //maker (ask) minimum sell amount 
    )
    auth
    note
    returns (bool suc) {
        _dust[sell_which_token] = dust;
        LogMinSell(sell_which_token, dust);
        suc = true; 
    }
    //returns the minimum sell amount for an offer
    function getMinSell(
        ERC20 sell_which_token      //token for which minimum sell amount is queried
    )
    constant
    returns (uint) {
        return _dust[sell_which_token];
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

    //set matching anabled/disabled
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
    function getBestOffer(ERC20 sell_token, ERC20 buy_token) constant returns(uint) {
        return _best[sell_token][buy_token];
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
    function getOfferCount(ERC20 sell_token, ERC20 buy_token) constant returns(uint) {
        return _span[sell_token][buy_token];
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