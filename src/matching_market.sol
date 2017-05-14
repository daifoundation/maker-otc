pragma solidity ^0.4.8;

import "./expiring_market.sol";

contract MatchingEvents {
    event LogBuyEnabled(bool);
    event LogMinSell(address sell_which_token, uint min_amount);
    event LogMatchingEnabled(bool);
    event LogUnsortedOffer(uint mid);
    event LogSortedOffer(uint mid);
}

contract MatchingMarket is MatchingEvents, ExpiringMarket {

    bool public ebu = true; //buy enabled
    bool public ema = true; /*true: enable matching, false: revert to 
                              expiring market*/

    //lower offer's id - sorted list of offers storing the next lower offer
    mapping( uint => uint ) public loi; 

    //higher offer's id - sorted list of offers storing the next higher offer
    mapping( uint => uint ) public hoi; 

    //id of the highest offer for a token pair
    mapping( address => mapping( address => uint ) ) public hes;    

    //size of `hoi` (number of keys)
    mapping( address => mapping( address => uint ) ) public hos;

    //minimum sell amount for a token to avoid dust offers
    mapping( address => uint) public mis;

    //next unsorted offer id
    mapping( uint => uint ) public uni; 
    
    //first unsigned offer id
    uint ufi;

    function MatchingMarket(uint lifetime_) ExpiringMarket(lifetime_){
    }
    //return true if offers[loi] priced less than or equal 
    //to offers[hoi]
    function isLtOrEq(
                        uint loi    //lower priced offer's id
                      , uint hoi    //higher priced offer's id
                     ) 
    internal
    returns (bool)
    {
        return safeMul(  
                         offers[loi].buy_how_much 
                       , offers[hoi].sell_how_much 
                      ) 
               >= 
               safeMul( 
                         offers[hoi].buy_how_much 
                       , offers[loi].sell_how_much 
                      ); 
    }

    //find the id of the next higher offer, than offers[mid]
    function find(uint mid)
    internal
    returns (uint)
    {
        assert( mid > 0 ); 

        address mbt = address(offers[mid].buy_which_token);
        address mst = address(offers[mid].sell_which_token);
        uint hid = hes[mst][mbt];

        if ( hid == 0 ) {
            //there are no offers stored

            return 0;
        }
        if ( hos[mst][mbt] > 0 ) {
            //there are at least two offers stored for token pair

            if ( !isLtOrEq( mid, hid ) ) {
                //did not find any offers that 
                //have higher or equal price than offers[mid]

                return 0;
            } else {
                //offers[hid] is higher or equal priced than offers[mid]

                //cycle through all offers for token pair to find the hid 
                //that is the next higher or equal to offers[mid]
                while ( loi[hid] != 0 && isLtOrEq( mid, loi[hid] ) ) {
                    hid = loi[hid];
                }

                return hid;
            }
        } else {
            //there is maximum one offer stored

            if ( hes[mst][mbt] == 0 ) {
                //there is no offer stored yet
                
                return 0;
            }
            if ( isLtOrEq( mid, hid ) ) {
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
                    uint mid    //maker (ask) id
                  , uint pos    //position to insert into
                 )
    internal
    {
        address mbt = address(offers[mid].buy_which_token);
        address mst = address(offers[mid].sell_which_token);
        uint lid; //lower maker (ask) id
        uint hid; //higher maker (ask) id
        uint hsi; //HigheSt maker (ask) Id

        assert( pos == 0 || isActive(pos) );
        assert( isActive(mid) );

        //assert `pos` is in the sorted list
        assert( pos == 0 || hoi[pos] != 0 || loi[pos] != 0 || hes[mst][mbt] == pos );
        
        if ( hes[mst][mbt] > 0 ){
            //if offer will be the sedond to insert

            hos[mst][mbt]++;
        }
        
        if ( pos != 0 ) {
            //offers[mid] is not the highest offer
            
            assert( isLtOrEq( mid, pos ) );

            lid = loi[pos];
            loi[pos] = mid;
            hoi[mid] = pos;
        }else{
            //offers[mid] is the highest offer

            lid = hes[mst][mbt];
            hes[mst][mbt] = mid;
        }

        assert( lid == 0 || offers[lid].sell_which_token 
               == offers[mid].sell_which_token );
        
        assert( lid == 0 || offers[lid].buy_which_token 
               == offers[mid].buy_which_token );


        if ( lid != 0 ) {
            //if lower offer does exist

            assert( !isLtOrEq( mid, lid ) ); 
            
            hoi[lid] = mid;
            loi[mid] = lid;
        }
        LogSortedOffer(mid);
    }

    // Remove offer from the sorted list.
    function unsort(
                      uint mid    /*id of maker (ask) offer to 
                                    remove from sorted list*/
                   )
    internal
    returns (bool)
    {
        address mbt = address(offers[mid].buy_which_token);
        address mst = address(offers[mid].sell_which_token);

        //assert mid is in the sorted list
        assert( hoi[mid] != 0 || loi[mid] != 0 || hes[mst][mbt] == mid );
        
        if ( mid != hes[mst][mbt] ) {
            // offers[mid] is not the highest offer

            loi[ hoi[mid] ] = loi[mid];
        }else{
            //offers[mid] is the highest offer

            hes[mst][mbt] = loi[mid];
        }

        if ( loi[mid] != 0 ) {
            //offers[mid] is not the lowest offer

            hoi[ loi[mid] ] = hoi[mid];
        }
       
        if ( hos[mst][mbt] > 0 ) {
            //size of `hes` is greater than 0

            hos[mst][mbt]--;
        }
        delete loi[mid];
        delete hoi[mid];
        return true;
    }

    //these variables are global only because of solidity local variable limit
    uint mbh;   //maker(ask) offer wants to buy this much token
    uint msh;   //maker(ask) offer wants to sell this much token
    bool toc;   /*if true, taker(bid) offer should not be 
                  created, because it was already matched */

    //match offers with taker(bid) offer, and execute token transactions
    function matcho( 
                      uint tsh   //taker(bid) sell How Much
                    , ERC20 tst  //taker(bid) sell which token
                    , uint tbh   //taker(bid) buy how much
                    , ERC20 tbt  //taker(bid) buy which token
                    , uint pos   //position id
                   )
    internal
    returns(uint mid)
    {

        toc = false;        //taker offer should be created
        bool yet = true;    //matching not done yet
        uint mes;           //highest maker (ask) id
        uint tas;           //taker (bid) sell how much saved    
        
        //offers[pos] should buy the same token as taker 
        assert( pos == 0 
               || !isActive(pos) 
               || tbt == offers[pos].buy_which_token );

        //offers[pos] should sell the same token as taker 
        assert(pos == 0 
               || !isActive(pos) 
               || tst == offers[pos].sell_which_token);

        while ( yet && hes[tbt][tst] > 0) {
            //matching is not done yet and there is at 
            //least one offer stored for token pair

            mes = hes[tbt][tst]; //store highest maker (ask) offer's id

            if ( mes > 0 ) {
                //there is at least one maker (ask) offer stored 
                
                mbh = offers[mes].buy_how_much;
                msh = offers[mes].sell_how_much;

                if ( safeMul( mbh , tbh ) <= safeMul( tsh , msh ) ) {
                    //maker (ask) price is lower than or equal to 
                    //taker (bid) price

                    if ( msh >= tbh ) {
                        //maker (ask) wants to sell more than 
                        //taker(bid) wants to buy
                        
                        buy( mes, tbh );
                        toc = true;
                        yet = false;
                    } else {
                        //maker(ask) wants to sell less than 
                        //taker(bid) wants to buy

                        tas = tsh; 
                        tsh = safeSub( tsh, mbh );
                        tbh = safeMul( tsh, tbh ) / tas;
                        buy( mes, msh );
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
        if ( ! toc ) {
            //new offer should be created            

            mid = super.offer( tsh, tst, tbh, tbt );
            
            assert( mid > 0 );
            
            //insert offer into the sorted list
            if ( pos != 0
                && isActive(pos) 
                && isLtOrEq( mid, pos  )
                && ( loi[pos] == 0 || !isLtOrEq( mid, loi[pos] ) 
               ) ) {
                //client provided valid position

                sort( mid, pos );
            } else {
                //client did not provide valid position, 
                //so we have to find it 
                
                pos = 0;

                if( hes[tst][tbt] > 0 && isLtOrEq( mid, hes[tst][tbt] ) ) {
                    //pos was 0 because user did not provide one  

                     pos = find(mid);
                }
                sort( mid, pos );
            }
        }
    }

    // Make a new offer without putting it in the sorted list.
    // Takes funds from the caller into market escrow.
    // ****Available to authorized contracts only!**********
    // Keepers should call insert(mid,pos) to put offer in the sorted list.

    function offeru ( 
                       uint msh   //maker (ask) sell how much
                     , ERC20 mst  //maker (ask) sell which token
                     , uint mbh   //maker (ask) buy how much
                     , ERC20 mbt  //maker (ask) buy which token
                    )
    auth
    internal
    /*NOT synchronized!!! */
    returns (uint mid) 
    {
        mid = super.offer( msh, mst, mbh, mbt ); 
        
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
                     uint msh   //maker (ask) sell how much
                   , ERC20 mst  //maker (ask) sell which token
                   , uint mbh   //maker (ask) buy how much
                   , ERC20 mbt  //maker (ask) buy which token
                  )
    /*NOT synchronized!!! */
    returns (uint mid) 
    {
        if( ema ) {
            //matching enabled

            mid = offeru( msh, mst, mbh, mbt ); 
        }else{
            //revert to expiring market

            mid = super.offer( msh, mst, mbh, mbt ); 
        } 
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    // Frontend should call only this function to create offers.

    function offer( 
                     uint msh   //maker (ask) sell how much
                   , ERC20 mst  //maker (ask) sell which token
                   , uint mbh   //maker (ask) buy how much
                   , ERC20 mbt  //maker (ask) buy which token
                   , uint pos   /*position to insert offer, 
                                  0 should be used if unknown*/
                  )
    /*NOT synchronized!!! */
    can_offer
    returns ( uint mid )
    {
        //make sure 'sell how much' is greater than minimum required 
        assert( mis[mst] <= msh );

        if ( ema ) {
            //matching enabled

            mid = matcho( msh, mst, mbh, mbt, pos );
        }else{
            //revert to expiring market

            mid = super.offer( msh, mst, mbh, mbt );
        }
    }

    // Accept given quantity (`num`) of an offer. Transfers funds from caller to
    // offer maker, and from market to caller.

    function buy( 
                   uint mid         /*maker (ask) offer's id that 
                                      is to be bought*/
                 , uint qua         //quantity of token to buy
                )
    /*NOT synchronized!!! */
    can_buy(mid)
    returns ( bool success )
    {
        if ( ema ) {
            //matching enabled

            //buy enabled
            assert(ebu);    

            if( qua >= offers[mid].sell_how_much ) {
                //offers[mid] must be removed from
                //sorted list because all of it is bought

                unsort(mid);
            }
            assert( super.buy( mid, qua ) ); 

            success = true;
        }else{
            //revert to expiring market
            success = super.buy( mid, qua ); 
        }
    }

    // Cancel an offer. Refunds offer maker.

    function cancel( uint mid )
    /*NOT synchronized!!! */
    can_cancel(mid)
    returns ( bool success )
    {
        if ( ema ) {
            //matching enabled

            unsort(mid);
        }
        return super.cancel(mid);
    }

    //insert offer into the sorted list
    //keepers need to use this function
    function insert(
                      uint mid    //maker (ask) id
                    , uint pos    //position to insert into
                   )
    returns(bool)
    {
        address mbt = address(offers[mid].buy_which_token);
        address mst = address(offers[mid].sell_which_token);
        uint uid; //id to search for `mid` in unsorted offers list
        uint pre; //previous offer's id in unsorted offers list

        //make sure offers[mid] is not yet sorted
        assert( hoi[mid] == 0 );
        assert( loi[mid] == 0 );
        assert( hes[mst][mbt] != mid );

        assert( isActive(mid) ); 
        assert( pos == 0 || isActive(pos) ); 
        
        //take offer out of list of unsorted offers
        uid = ufi;
        pre = 0;

        //find `mid` in the unsorted list of offers
        while( uid > 0 && uid != mid ) {
            //while not found `mid`

            pre = uid;
            uid = uni[uid];   
        }
        if ( pre == 0 ) {
            //uid was the first in the unsorted offers list

            if ( uid == mid ) {
                //uid was the first in unsorted offers list

                ufi = uni[uid];
                uni[uid] = 0;
                sort( mid, pos );
                return true;
            }
            //there were no offers in the unsorted list
            return false;                
        }else{
            //uid was not the first the unsorted offers list

            if ( uid == mid ) {
                //uid was not the first in the list but we found mid

                uni[pre] = uni[uid];
                uni[uid] = 0;   
                sort( mid, pos );
                return true;
            } 
            //did not find mid
            return false;
        }
    }

    // set the minimum sell amount for a token
    function setMinSell(
                                ERC20 mst  /*token to assign minimum 
                                             sell amount to*/
                              , uint mis_   //maker (ask) minimum sell amount 
                             )
    auth
    returns (bool suc) {
        mis[mst] = mis_;
        LogMinSell(mst, mis_);
        suc = true; //success
    }

    function getMinSell(
                              ERC20 mst /*token for which minimum 
                                          sell amount is queried*/
                             )
    constant
    returns (uint) {
        return mis[mst];
    }

    function isBuyEnabled() constant returns (bool){
        return ebu;
    }

    function setBuyEnabled(bool ebu_) auth returns (bool){
        ebu = ebu_;
        LogBuyEnabled(ebu);
        return ebu;
    }

    function setMatchingEnabled(bool ema_) auth returns (bool) {
        ema = ema_;
        LogMatchingEnabled(ema);
        return true;
    }

}
