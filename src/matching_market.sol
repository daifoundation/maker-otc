pragma solidity ^0.4.8;

import "./expiring_market.sol";
import "ds-note/note.sol";

contract MatchingEvents {
    event LogBuyEnabled(bool);
    event LogMinSell(address sell_which_token, uint min_amount);
    event LogMatchingEnabled(bool);
    event LogUnsortedOffer(uint mid);
    event LogSortedOffer(uint mid);
}

contract MatchingMarket is MatchingEvents, ExpiringMarket, DSNote {
    bool public buyEnabled = true;      //buy enabled
    bool public matchingEnabled = true; //true: enable matching,
                                        //false: revert to expiring market
    struct sortInfo {
        uint next;  //points to id of next higher offer
        uint prev;  //points to id of previous lower offer
    }
    mapping(uint => sortInfo) public rank;                      //doubly linked list of sorted offer ids               
    mapping(address => mapping(address => uint)) public best;    //id of the highest offer for a token pair  
    mapping(address => mapping(address => uint)) public span;   //number of offers stored for token pair
    mapping(address => uint) public dust;                       //minimum sell amount for a token to avoid dust offers
    mapping(uint => uint) public uni;                           //next unsorted offer id
    uint ufi;                                                   //first unsorted offer id

    function MatchingMarket(uint lifetime_) ExpiringMarket(lifetime_) {
    }
    //return true if offers[loi] priced less than or equal to offers[hoi]
    function isLtOrEq(
        uint loi,       //lower priced offer's id
        uint hoi        //higher priced offer's id
    ) 
    internal
    returns (bool)
    {
        return
        safeMul(  
            offers[loi].buy_how_much, 
            offers[hoi].sell_how_much 
        ) 
        >= 
        safeMul( 
            offers[hoi].buy_how_much, 
            offers[loi].sell_how_much 
        ); 
    }

    //find the id of the next higher offer, than offers[mid]
    function find(uint mid)
    internal
    returns (uint)
    {
        assert( mid > 0 ); 
        address buy_which_token = address(offers[mid].buy_which_token);
        address sell_which_token = address(offers[mid].sell_which_token);
        uint hid = best[sell_which_token][buy_which_token];

        if (span[sell_which_token][buy_which_token] > 1) {
            //there are at least two offers stored for token pair

            if (!isLtOrEq(mid, hid)) {
                //did not find any offers that 
                //have higher or equal price than offers[mid]
                return 0;
            } else {
                //offers[hid] is higher or equal priced than offers[mid]

                //cycle through all offers for token pair to find the hid 
                //that is the next higher or equal to offers[mid]
                while (rank[hid].prev != 0 && isLtOrEq(mid, rank[hid].prev)) {
                    hid = rank[hid].prev;
                }
                return hid;
            }
        } else {
            //there is maximum one offer stored
            if (best[sell_which_token][buy_which_token] == 0) {
                //there is no offer stored yet  
                return 0;
            }
            if (isLtOrEq(mid, hid)) {
                //there is exactly one offer stored, 
                //and it IS higher or equal than offers[mid]
                return hid;
            } else {
                //there is exatly one offer stored, but lower than offers[mid]
                return 0;
            }
        }
    }

    //put offer into the sorted list
    function sort( 
        uint mid,   //maker (ask) id
        uint pos    //position to insert into
    )
    internal
    {
        address buy_which_token = address(offers[mid].buy_which_token);
        address sell_which_token = address(offers[mid].sell_which_token);
        uint lid; //lower maker (ask) id
        uint hid; //higher maker (ask) id
        uint hsi; //highest maker (ask) id

        assert(isActive(mid));
        if ( pos == 0
            || !isActive(pos) 
            || !isLtOrEq(mid, pos)
            || (rank[pos].prev != 0 && isLtOrEq(mid, rank[pos].prev)) 
        ) {
            //client did not provide valid position, 
            //so we have to find it 
            pos = 0;
            if( best[sell_which_token][buy_which_token] > 0 && isLtOrEq( mid, best[sell_which_token][buy_which_token] ) ) {
                //pos was 0 because user did not provide one  
                pos = find(mid);
            }
        }
        //assert `pos` is in the sorted list or is 0
        assert(pos == 0 || rank[pos].next != 0 || rank[pos].prev != 0 || best[sell_which_token][buy_which_token] == pos);
        if (pos != 0) {
            //offers[mid] is not the highest offer
            assert(isLtOrEq( mid, pos));
            lid = rank[pos].prev;
            rank[pos].prev = mid;
            rank[mid].next = pos;
        } else {
            //offers[mid] is the highest offer
            lid = best[sell_which_token][buy_which_token];
            best[sell_which_token][buy_which_token] = mid;
        }
        assert(lid == 0 || offers[lid].sell_which_token 
               == offers[mid].sell_which_token); 
        assert(lid == 0 || offers[lid].buy_which_token 
               == offers[mid].buy_which_token);

        if ( lid != 0 ) {
            //if lower offer does exist
            assert(!isLtOrEq(mid, lid)); 
            rank[lid].next = mid;
            rank[mid].prev = lid;
        }
        span[sell_which_token][buy_which_token]++;
        LogSortedOffer(mid);
    }
    // Remove offer from the sorted list.
    function unsort(
        uint mid    //id of maker (ask) offer to remove from sorted list
    )
    internal
    returns (bool)
    {
        address buy_which_token = address(offers[mid].buy_which_token);
        address sell_which_token = address(offers[mid].sell_which_token);

        //assert mid is in the sorted list
        assert(rank[mid].next != 0 || rank[mid].prev != 0 || best[sell_which_token][buy_which_token] == mid);
    
        if (mid != best[sell_which_token][buy_which_token]) {
            // offers[mid] is not the highest offer
            rank[rank[mid].next].prev = rank[mid].prev;
        } else {
            //offers[mid] is the highest offer
            best[sell_which_token][buy_which_token] = rank[mid].prev;
        }
        if (rank[mid].prev != 0) {
            //offers[mid] is not the lowest offer
            rank[rank[mid].prev].next = rank[mid].next;
        }
        assert (span[sell_which_token][buy_which_token] > 0);
        span[sell_which_token][buy_which_token]--;
        delete rank[mid].prev;
        delete rank[mid].next;
        return true;
    }

    //these variables are global only because of solidity local variable limit
    uint mbh;   //maker(ask) offer wants to buy this much token
    uint msh;   //maker(ask) offer wants to sell this much token
    bool toc;   //if true, taker(bid) offer should not be created, because it was already matched

    //match offers with taker(bid) offer, and execute token transactions
    function matcho( 
        uint tsh,   //taker(bid) sell how much
        ERC20 tst,  //taker(bid) sell which token
        uint tbh,   //taker(bid) buy how much
        ERC20 tbt,  //taker(bid) buy which token
        uint pos    //position id
    )
    internal
    returns(uint mid)
    {
        toc = false;        //taker offer should be created
        bool yet = true;    //matching not done yet
        uint mes;           //highest maker (ask) id
        uint tas;           //taker (bid) sell how much saved    
        
        //offers[pos] should buy the same token as taker 
        assert(pos == 0 
               || !isActive(pos) 
               || tbt == offers[pos].buy_which_token);

        //offers[pos] should sell the same token as taker 
        assert(pos == 0 
               || !isActive(pos) 
               || tst == offers[pos].sell_which_token);

        while (yet && best[tbt][tst] > 0) {
            //matching is not done yet and there is at 
            //least one offer stored for token pair
            mes = best[tbt][tst]; //store highest maker (ask) offer's id
            if (mes > 0) {
                //there is at least one maker (ask) offer stored 
                mbh = offers[mes].buy_how_much;
                msh = offers[mes].sell_how_much;
                if (safeMul( mbh , tbh ) <= safeMul(tsh , msh)) {
                    //maker (ask) price is lower than or equal to 
                    //taker (bid) price
                    if (msh >= tbh) {
                        //maker (ask) wants to sell more than 
                        //taker(bid) wants to buy
                        buy(mes, tbh);
                        toc = true;
                        yet = false;
                    } else {
                        //maker(ask) wants to sell less than 
                        //taker(bid) wants to buy
                        tas = tsh; 
                        tsh = safeSub(tsh, mbh);
                        tbh = safeMul(tsh, tbh) / tas;
                        buy(mes, msh);
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
        if (!toc) {
            //new offer should be created            
            mid = super.offer(tsh, tst, tbh, tbt);
            //insert offer into the sorted list
            sort(mid, pos);
        }
    }
    // Make a new offer without putting it in the sorted list.
    // Takes funds from the caller into market escrow.
    // ****Available to authorized contracts only!**********
    // Keepers should call insert(mid,pos) to put offer in the sorted list.
    function offeru( 
        uint msh,                   //maker (ask) sell how much
        ERC20 sell_which_token,     //maker (ask) sell which token
        uint mbh,                   //maker (ask) buy how much
        ERC20 buy_which_token       //maker (ask) buy which token
    )
    auth
    internal
    /*NOT synchronized!!! */
    returns(uint mid) 
    {
        mid = super.offer(msh, sell_which_token, mbh, buy_which_token); 
        //insert offer into the unsorted offers list
        uni[mid] = ufi;
        ufi = mid;
        LogUnsortedOffer(mid);
    }

    // ---- Public entrypoints ---- //
    function make(
        ERC20    haveToken,
        ERC20    wantToken,
        uint128  haveAmount,
        uint128  wantAmount
    ) returns (bytes32 mid) {
        return bytes32(offer(haveAmount, haveToken, wantAmount, wantToken));
    }

    function take(bytes32 mid, uint128 maxTakeAmount) {
        assert(buy(uint256(mid), maxTakeAmount));
    }

    function kill(bytes32 mid) {
        assert(cancel(uint256(mid)));
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    //
    // If matching is enabled: 
    //     * creates new offer without putting it in 
    //       the sorted list.
    //     * available to authorized contracts only! 
    //     * keepers should call insert(mid,pos) 
    //       to put offer in the sorted list.
    // If matching is disabled: 
    //     * calls expiring market's offer().
    //     * available to everyone without authorization.
    //     * no sorting is done.

    function offer ( 
        uint msh,                   //maker (ask) sell how much
        ERC20 sell_which_token,     //maker (ask) sell which token
        uint mbh,                   //maker (ask) buy how much
        ERC20 buy_which_token       //maker (ask) buy which token
    )
    /*NOT synchronized!!! */
    returns(uint mid) 
    {
        if(matchingEnabled) {
            //matching enabled
            mid = offeru(msh, sell_which_token, mbh, buy_which_token); 
        } else {
            //revert to expiring market
            mid = super.offer(msh, sell_which_token, mbh, buy_which_token); 
        } 
    }
    // Make a new offer. Takes funds from the caller into market escrow.
    function offer( 
        uint msh,                   //maker (ask) sell how much
        ERC20 sell_which_token,     //maker (ask) sell which token
        uint mbh,                   //maker (ask) buy how much
        ERC20 buy_which_token,      //maker (ask) buy which token
        uint pos                    //position to insert offer, 0 should be used if unknown
    )
    /*NOT synchronized!!! */
    can_offer
    returns(uint mid)
    {
        //make sure 'sell how much' is greater than minimum required 
        assert( dust[sell_which_token] <= msh );
        if (matchingEnabled) {
            //matching enabled
            mid = matcho(msh, sell_which_token, mbh, buy_which_token, pos);
        } else {
            //revert to expiring market
            mid = super.offer(msh, sell_which_token, mbh, buy_which_token);
        }
    }
    // Accept given quantity (`num`) of an offer. Transfers funds from caller to
    // offer maker, and from market to caller.
    function buy( 
        uint mid,   //maker (ask) offer's id that is to be bought
        uint qua    //quantity of token to buy
    )
    /*NOT synchronized!!! */
    can_buy(mid)
    returns (bool success)
    {
        if (matchingEnabled) {
            //matching enabled
            //buy enabled
            assert(buyEnabled);    
            if(qua >= offers[mid].sell_how_much) {
                //offers[mid] must be removed from
                //sorted list because all of it is bought
                unsort(mid);
            }
            assert(super.buy(mid, qua));
            success = true;
        } else {
            //revert to expiring market
            success = super.buy(mid, qua); 
        }
    }
    // Cancel an offer. Refunds offer maker.
    function cancel(uint mid)
    /*NOT synchronized!!! */
    can_cancel(mid)
    returns(bool success)
    {
        if (matchingEnabled) {
            //matching enabled
            unsort(mid);
        }
        return super.cancel(mid);
    }
    //insert offer into the sorted list
    //keepers need to use this function
    function insert(
        uint mid,   //maker (ask) id
        uint pos    //position to insert into
                   )
    returns(bool)
    {
        address buy_which_token = address(offers[mid].buy_which_token);
        address sell_which_token = address(offers[mid].sell_which_token);
        uint uid; //id to search for `mid` in unsorted offers list
        uint pre; //previous offer's id in unsorted offers list

        //make sure offers[mid] is not yet sorted
        assert(rank[mid].next == 0);
        assert(rank[mid].prev == 0);
        assert(best[sell_which_token][buy_which_token] != mid);

        assert(isActive(mid)); 
        assert(pos == 0 || isActive(pos)); 
        
        //take offer out of list of unsorted offers
        uid = ufi;
        pre = 0;

        //find `mid` in the unsorted list of offers
        while(uid > 0 && uid != mid) {
            //while not found `mid`
            pre = uid;
            uid = uni[uid];   
        }
        if (pre == 0) {
            //uid was the first in the unsorted offers list
            if (uid == mid) {
                //uid was the first in unsorted offers list
                ufi = uni[uid];
                uni[uid] = 0;
                sort(mid, pos);
                return true;
            }
            //there were no offers in the unsorted list
            return false;                
        } else {
            //uid was not the first in the unsorted offers list
            if (uid == mid) {
                //uid was not the first in the list but we found mid
                uni[pre] = uni[uid];
                uni[uid] = 0;   
                sort(mid, pos);
                return true;
            }
            //did not find mid
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
        uint dust_                  //maker (ask) minimum sell amount 
    )
    auth
    note
    returns(bool suc) {
        dust[sell_which_token] = dust_;
        LogMinSell(sell_which_token, dust_);
        suc = true; 
    }
    //returns the minimum sell amount for an offer
    function getMinSell(
        ERC20 sell_which_token      //token for which minimum sell amount is queried
    )
    constant
    returns(uint) {
        return dust[sell_which_token];
    }

    //the call of buy() function is enabled (offer sniping)
    //    Returns true, if users can click and buy any arbitrary offer, 
    //    not only the lowest one. Users can also buy unsorted offers as 
    //    well. 
    //    Returns false, if users are not allowed to buy arbitrary offers. 
    function isBuyEnabled() constant returns (bool) {
        return buyEnabled;
    }
    
    //set buy functionality enabled/disabled 
    function setBuyEnabled(bool buyEnabled_) auth note returns (bool) {
        buyEnabled = buyEnabled_;
        LogBuyEnabled(buyEnabled);
        return true;
    }
    
    //is otc offer matching enabled?
    //      Returns true if offers will be matched if possible.
    //      Returns false if contract is reverted to ExpiringMarket
    //      and no matching is done for new offers. 
    function isMatchingEnabled() constant returns (bool) {
        return matchingEnabled;
    }

    //set matching anabled/disabled
    //    If matchingEnabled_ true(default), then inserted offers are matched. 
    //    Except the ones inserted by contracts, because those end up 
    //    in the unsorted list of offers, that must be later sorted by
    //    keepers using insert().
    //    If matchingEnabled_ is false then MatchingMarket is reverted to ExpiringMarket,
    //    and matching is not done, and sorted lists are disabled.    
    function setMatchingEnabled(bool matchingEnabled_) auth note returns (bool) {
        matchingEnabled = matchingEnabled_;
        LogMatchingEnabled(matchingEnabled);
        return true;
    }

    //return the best offer for a token pair
    //      the best offer is the lowest one if its an ask, 
    //      and highest one if its a bid offer
    function getBestOffer(ERC20 sell_token, ERC20 buy_token) constant returns(uint) {
        return best[sell_token][buy_token];
    }

    //return the next worse offer in the sorted list
    //      the worse offer is the higher one if its an ask, 
    //      and next lower one if its a bid offer
    function getWorseOffer(uint mid) constant returns(uint) {
        return rank[mid].prev;
    }

    //return the next better offer in the sorted list
    //      the better offer is in the lower priced one if its an ask, 
    //      and next higher priced one if its a bid offer
    function getBetterOffer(uint mid) constant returns(uint) {
        return rank[mid].next;
    }
    
    //return the amount of better offers for a token pair
    function getOfferCount(ERC20 sell_token, ERC20 buy_token) constant returns(uint) {
        return span[sell_token][buy_token];
    }

    //get the first unsorted offer that was inserted by a contract
    //      Contracts can't calculate the insertion position of their offer because it is not an O(1) operation.
    //      Their offers end up in the unsorted list of offers.
    //      Keepers can calculate the insertion position offchain and pass it to the insert() function to insert
    //      the unsorted offer into the sorted list. Unsorted offers will not be matched, but can be bought with buy().
    function getFirstUnsortedOffer() constant returns(uint) {
        return ufi;
    }

    //get the next unsorted offer
    //      Can be used to cycle through all the unsorted offers.
    function getNextUnsortedOffer(uint mid) constant returns(uint) {
        return uni[mid];
    }
}