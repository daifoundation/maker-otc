pragma solidity ^0.4.8;

import "erc20/erc20.sol";

import "ds-auth/auth.sol";

import "./expiring_market.sol";

contract MatchingEvents {
	event LogBuyEnabled(bool);
	event LogMinSellAmount(address sell_which_token, uint min_amount);
    event LogMatchingEnabled(bool);
    event LogUnsortedOffer(uint mid);
    event LogSortedOffer(uint mid);
}

contract MatchingMarket is DSAuth, MatchingEvents, ExpiringMarket {

	bool public bue = true; //buy enabled
	bool public ema = true; //enable matching, if false revert to expiring market

    //lower offer's id - sorted list of offers storing the next lower offer
	mapping( uint => uint ) public loi; 

    //higher offer's id - sorted list of offers storing the next higher offer
	mapping( uint => uint ) public hoi; 

    //id of the highest offer for a token pair
	mapping( address => mapping( address => uint ) ) public big;    

    //id of the lowest offer for a token pair
	mapping( address => mapping( address => uint ) ) public low;    

    //size of `hoi` (number of keys)
	mapping( address => mapping( address => uint ) ) public hos;

    //the minimum sell amount for a token to avoid dust offers
	mapping( address => uint) public ami;

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
        address mbt = address(offers[mid].buy_which_token);
        address mst = address(offers[mid].sell_which_token);
        uint hid = big[mst][mbt];
        assert( mid > 0 ); 
        
		if ( hid == 0 ) {
            //there are no offers stored
			return 0;
		}
        if ( hos[mst][mbt] > 0 ) {
            //there are at least two offers stored for token pair

            if ( !isLtOrEq( mid, hid ) ) {
                //did not find any offers that have higher or equal price than offers[mid]

                return 0;
            } else {
                //offers[hid] is higher or equal priced than offers[mid]

                //cycle through all offers for token pair to find the mid 
                //that is the next higher or equal to offers[mid]
                while ( loi[hid] != 0 && isLtOrEq( mid, loi[hid] ) ) {
                    hid = loi[hid];
                }

                return hid;
            }
        } else {
            //there is maximum one offer stored

            if ( low[mst][mbt] == 0 ) {
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

    // Remove offer from the sorted list.
    function unsort(
                      uint mid    //id of maker (ask) offer to remove from sorted list
                   )
        internal
        returns (bool)
        {
        address mbt = address(offers[mid].buy_which_token);
        address mst = address(offers[mid].sell_which_token);
        
        if(big[mst][mbt] == mid){
            //offers[mid] is the highest offer
        
            big[mst][mbt] = loi[mid]; 
            delete hoi[ loi[mid] ];
            delete loi[mid];
            if ( hos[mst][mbt] > 0 ) {
                //there is at least one offer left
        
                hos[mst][mbt]--;
            } else {
                //offer was the last offer 
        
                low[mst][mbt] = 0;
            }
        } else if( low[mst][mbt] == mid ) {
            //offers[mid] is the lowest offer
        
            low[mst][mbt] = hoi[mid]; 
            delete loi[ hoi[mid] ];
            delete hoi[mid];
            hos[mst][mbt]--;
        } else {
            //offers[mid] is between the highest and the lowest offer

            loi[ hoi[mid] ] = loi[mid];
            hoi[ loi[mid] ] = hoi[mid];
            delete loi[mid];
            delete hoi[mid];
            hos[mst][mbt]--;
        }
        
        return true;
    }
    //these variables are global only because of solidity local variable limit
    uint mbh;   //maker(ask) offer wants to buy this much token
    uint msh;   //maker(ask) offer wants to sell this much token
    bool tno;   /*if true, taker(bid) offer should not be 
                  created, because it was matched */

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

        tno = false;        //taker offer should be created
        bool ndy = true;    //matching not done yet
        uint mhi;           //highest maker (ask) id
        uint tss;           //taker (bid) sell how much saved    
        
        //offers[pos] should buy the same token as taker 
        assert( pos == 0 
               || !isActive(pos) 
               || tbt == offers[pos].buy_which_token );

        //offers[pos] should sell the same token as taker 
        assert(pos == 0 
               || !isActive(pos) 
               || tst == offers[pos].sell_which_token);

        while ( ndy && big[tbt][tst] > 0) {
            //matching is not done yet and there is at 
            //least one offer stored for token pair

            mhi = big[tbt][tst]; //store highest maker (ask) offer's id

            if ( mhi > 0 ) {
                //there is at least one maker (ask) offer stored 
                
                mbh = offers[mhi].buy_how_much;
                msh = offers[mhi].sell_how_much;

                if ( safeMul( mbh , tbh ) <= safeMul( tsh , msh ) ) {
                    //maker (ask) price is lower than or equal to taker (bid) price

                    if ( msh >= tbh ){
                        //maker (ask) wants to sell more than taker(bid) wants to buy
                        
                        buy( mhi, tbh );
                        tno = true;
                        ndy = false;
                    } else {
                        //maker(ask) wants to sell less than taker(bid) wants to buy

                        tss = tsh; 
                        tsh = safeSub( tsh, mbh );
                        tbh = safeMul( tsh, tbh ) / tss;
                        buy( mhi, msh );
                    }
                } else {
                    //lowest maker (ask) price is higher than current taker (bid) price

                    ndy = false;
                }
            } else {
                //there is no maker (ask) offer to match

                ndy = false;
            }
        }
        if( ! tno ) {
            //new offer should be created            

            mid = super.offer( tsh, tst, tbh, tbt );
            
            assert( mid > 0 );
            
            //insert offer into the sorted list
            if ( pos != 0
                && offers[pos].active 
                && isLtOrEq( mid, pos  )
                && ( loi[pos] == 0 || !isLtOrEq( mid, loi[pos] ) 
               ) ) {
                //client provided valid position

                sort( mid, pos );
            } else {
                //client did not provide valid position, 
                //so we have to find it ourselves
                
                pos = 0;

                if( big[tst][tbt] > 0 && isLtOrEq( mid, big[tst][tbt] ) ) {
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
    // Keepers should call sort(mid,pos) to put offer in the sorted list.

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
    //     * keepers should call sort(mid,pos) 
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

    function offer( 
                     uint msh   //maker (ask) sell how much
                   , ERC20 mst  //maker (ask) sell which token
                   , uint mbh   //maker (ask) buy how much
                   , ERC20 mbt  //maker (ask) buy which token
                   , uint pos   //position to insert offer, 0 should be used if unknown
                  )
        /*NOT synchronized!!! */
        can_offer
        returns ( uint id )
    {
        //make sure the 'sell how much' is greater than minimum required 
        assert(ami[mst] <= msh);

        if(ema){
            //matching enabled

            return matcho( msh, mst, mbh, mbt, pos );
        }else{
            //revert to expiring market

            id = super.offer( msh, mst, mbh, mbt );
        }
    }

    // Accept given quantity (`num`) of an offer. Transfers funds from caller to
    // offer maker, and from market to caller.

    function buy( 
                   uint mid         //maker (ask) offer's id that is to be bought
                 , uint qua         //quantity of token to buy
                )
        /*NOT synchronized!!! */
        can_buy(mid)
        returns ( bool success )
    {
        if(ema){
            //matching enabled

            assert(bue);    //buy enabled

            if(qua >= offers[mid].sell_how_much) {
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
        if(ema){
            //matching enabled

            unsort(mid);
        }
        return super.cancel(mid);
    }

    //put offer into the sorted list
    function sort( 
                    uint mid    //maker (ask) id
                  , uint pos    //position to insert into
                 )
    {
        OfferInfo offer = offers[mid];
        address mbt = address(offer.buy_which_token);
        address mst = address(offer.sell_which_token);
        uint lid; //lower maker (ask) id
        uint hsi; //HigheSt maker (ask) Id

        assert(isActive(pos));
        assert(isActive(mid));
       
        //make sure offers[mid] is not yet sorted
        assert( hoi[mid] == 0);
        assert( loi[mid] == 0);
        assert( low[mst][mbt] != mid);

        if ( pos != 0 ) {
            //offers[mid] is not the highest offer
            
            assert(offers[pos].sell_which_token == offer.sell_which_token);
            assert(offers[pos].buy_which_token == offer.buy_which_token);

            //make sure offers[mid] price is lower than or equal to offers[pos] price
            assert( isLtOrEq( mid, pos ) );

            hoi[mid] = pos;
            hos[mst][mbt]++;
            if ( pos != low[mst][mbt] ) {
                //offers[mid] is not the lowest offer 
                
                lid = loi[pos];
                
                //make sure price of offers[mid] is higher than  
                //price of offers[lid]
                assert( lid == 0 || !isLtOrEq( mid, lid ) ); 
                
                if( lid > 0 ) {
                    hoi[lid] = mid;
                }
                loi[mid] = lid;
                loi[pos] = mid;
            }else{
                //offers[mid] is the lowest offer
                
                loi[pos] = mid;
                low[mst][mbt] = mid;                
            }
        } else {
            //offers[mid] is the highest offer

            hsi = big[mst][mbt];
            if ( hsi != 0 ) {
                //offers[mid] is at least the second offer that was stored

                //make sure offer price is strictly higher than highest_offer price
                assert( !isLtOrEq( mid, hsi ) );
                assert( offer.sell_which_token == offers[hsi].sell_which_token);
                assert( offer.buy_which_token == offers[hsi].buy_which_token);
                
                loi[mid] = hsi;
                hoi[hsi] = mid;
                hos[mst][mbt]++;
            } else {
                //offers[mid] is the first offer that is stored

                low[mst][mbt] = mid;
            }
            big[mst][mbt] = mid;
        }
        LogSortedOffer(mid);
    }

    // set the minimum sell amount for a token
	function setMinSellAmount(
                                ERC20 mst  //token to assign minimum sell amount to
                              , uint msa   //maker (ask) minimum sell amount 
                             )
	auth
	returns (bool suc) {
		ami[mst] = msa;
		LogMinSellAmount(mst, msa);
		suc = true; //success
	}

	function getMinSellAmount(
                              ERC20 mst //token for which minimum sell amount is queried
                             )
	constant
	returns (uint) {
		return ami[mst];
	}

	function isBuyEnabled() constant returns (bool){
		return bue;
	}

	function setBuyEnabled(bool bue_) auth returns (bool){
		bue = bue_;
		LogBuyEnabled(bue);
		return bue;
	}

    function setMatchingEnabled(bool ema_) auth returns (bool) {
        ema = ema_;
        LogMatchingEnabled(ema);
        return true;
    }

}
