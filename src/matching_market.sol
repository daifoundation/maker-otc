pragma solidity ^0.4.8;

import "erc20/erc20.sol";

import "ds-auth/auth.sol";

import "./expiring_market.sol";

contract MatchingEvents {
	event LogSetBuyEnabled(bool);
	event LogExpiringMarket(ExpiringMarket);
	event LogSetMinSellAmount(ERC20 sell_which_token, uint min_amount);
}

contract MatchingMarket is DSAuth, MatchingEvents, ExpiringMarket {

	bool public buy_enabled = true;
	bool public normal_operation = true;

    //lower offer's id - sorted list of offers storing the next lower offer
	mapping( uint => uint ) public loi; 

    //higher offer's id - sorted list of offers sroring the next higher offer
	mapping( uint => uint ) public hoi; 

    //id of the highest offer for a token pair
	mapping( address => mapping( address => uint ) ) public big;    

    //id of the lowest offer for a token pair
	mapping( address => mapping( address => uint ) ) public low;    

    //size of `hoi` (number of keys)
	mapping( address => mapping( address => uint ) ) public hos;

    //the minimum sell amount for a token to avoid dust offers
	mapping( address => uint) public min_sell_amount;

    function intoSorted( uint id, uint pos )
    internal
    {
        OfferInfo offer = offers[id];
        address bwt = address(offer.buy_which_token);
        address swt = address(offer.sell_which_token);
        uint lid; //lower id
        uint hsi; //HigheSt Id
       

        if ( pos != 0 ) {
            //offers[id] is not the highest offer
            
            assert(offers[pos].sell_which_token == offer.sell_which_token);
            assert(offers[pos].buy_which_token == offer.buy_which_token);
            //make sure offers[id] price is lower than offers[higher_offer] price
            assert( isLtOrEq( id, pos ) );

            hoi[id] = pos;
            hos[swt][bwt]++;
            if ( pos != low[swt][bwt] ) {
                //offers[id] is not the lowest offer 
                
                lid = loi[pos];
                
                //make sure offer price is higher than  
                //to lower_offer price
                assert( lid == 0 || !isLtOrEq( id, lid ) ); 
                
                if( lid > 0 ) {
                    hoi[lid] = id;
                }
                loi[id] = lid;
                loi[pos] = id;
            }else{
                //offers[id] is the lowest offer
                
                loi[pos] = id;
                low[swt][bwt] = id;                
            }
        } else {
            //offers[id] is the highest offer

            hsi = big[swt][bwt];
            if ( hsi != 0 ) {
                //offers[id] is at least the second offer that was stored

                //make sure offer price is strictly higher than highest_offer price
                assert( !isLtOrEq( id, hsi ) );
                assert( offer.sell_which_token == offers[hsi].sell_which_token);
                assert( offer.buy_which_token == offers[hsi].buy_which_token);
                
                loi[id] = hsi;
                hoi[hsi] = id;
                hos[swt][bwt]++;
            } else {
                //offers[id] is the first offer that is stored

                low[swt][bwt] = id;
            }
            big[swt][bwt] = id;
        }
    }

    //return true if offers[loi] has less than or equal 
    //price than offers[hoi]
    function isLtOrEq(
                        uint loi    //lower offer's id
                      , uint hoi    //higher offer's id
                     ) 
    internal
    returns (bool)
    {
        OfferInfo hof = offers[hoi];
        OfferInfo lof = offers[loi];

        return safeMul( lof.buy_how_much , hof.sell_how_much ) 
               >= 
               safeMul( hof.buy_how_much , lof.sell_how_much ); 
    }

    //find the id of the next higher offer, than offers[id]
    function findPos(uint id)
    internal
    returns (uint)
    {
        address bwt = address(offers[id].buy_which_token);
        address swt = address(offers[id].sell_which_token);
        uint hid = big[swt][bwt];
        assert( id > 0 ); 
        
		if ( hid == 0 ) {
            //there are no offers stored
			return 0;
		}
        if ( hos[swt][bwt] > 0 ) {
            //there is at least two offers stored for token pair

            if ( !isLtOrEq( id, hid ) ) {
                //did not find any offer that has higher or equal price than offers[id]

                return 0;

            } else {
                //offers[hid] is higher or equal priced than offers[id]

                //cycle through all offers for token pair to find the id 
                //that is the next higher or equal to offers[id]
                while ( loi[hid] != 0 && isLtOrEq( id, loi[hid] ) ) {
                    hid = loi[hid];
                }

                return hid;
            }
        } else {
            //there is maximum one offer stored

            if ( low[swt][bwt] == 0 ) {
                //there is no offer stored yet
                
                return 0;
            }
            if ( isLtOrEq( id, hid ) ) {
                //there is exactly one offer stored, and it IS higher or equal than offers[id]

                return hid;
            } else {
                //there is exatly one offer stored, but lower than offers[id]

                return 0;
            }
        }
    }

    // Remove offer from the sorted list.
    function fromSorted(
                          uint id     //id of offer to remove from sorted list
                        , ERC20 swt   //sell which token of offer[id]
                        , ERC20 bwt   //buy which token of offer[id]
                       )
        internal
        returns (bool)
        {

        if(big[swt][bwt] == id){
            //offers[id] is the highest offer
        
            big[swt][bwt] = loi[id]; 
            delete hoi[ loi[id] ];
            delete loi[id];
            if ( hos[swt][bwt] > 0 ) {
                //there is at least one offer left
        
                hos[swt][bwt]--;
            } else {
                //offer was the last offer 
        
                low[swt][bwt] = 0;
            }
        } else if( low[swt][bwt] == id ) {
            //offers[id] is the lowest offer
        
            low[swt][bwt] = hoi[id]; 
            delete loi[ hoi[id] ];
            delete hoi[id];
            hos[swt][bwt]--;
        } else {
            //offers[id] is between the highest and the lowest offer

            loi[ hoi[id] ] = loi[id];
            hoi[ loi[id] ] = hoi[id];
            delete loi[id];
            delete hoi[id];
            hos[swt][bwt]--;
        }
        
        return true;
    }
    //these variables are global only because of solidity local variable limit
    uint mbu;   //maker(asker) offer wants to buy this much token
    uint mse;   //maker(asker) offer wants to sell this much token
    bool del;   //taker(bidder) offer should not be created, because all was matched 

    //match offers with taker(bidder) offer, and do the token transactions
    function matchOffer( 
                          uint shm   //taker(bidder) sell How Much
                        , ERC20 swt  //taker(bidder) sell which token
                        , uint bhm   //taker(bidder) buy how much
                        , ERC20 bwt  //taker(bidder) buy which token
                        , uint pos   //position id
                       )
        internal
        {

        del = false;        //no taker offer should be created, because all is matched
        bool mnd = true;    //matching not done yet
        uint hmi;           //highest maker (ask) id
        uint out;           //spending of taker 
        
        assert( pos == 0 
               || !isActive(pos) 
               || bwt == offers[pos].buy_which_token );

        assert(pos == 0 
               || !isActive(pos) 
               || swt == offers[pos].sell_which_token);

        while ( mnd && big[bwt][swt] > 0) {

            hmi = big[bwt][swt];

            if ( hmi > 0 ) {
                //there is at least one ask offer stored 
                
                mbu = offers[hmi].buy_how_much;
                mse = offers[hmi].sell_how_much;

                if ( safeMul( mbu , bhm ) <= safeMul( shm , mse ) ) {
                    //maker (ask) price is lower than or equal to taker (bid) price

                    if ( mse >= bhm ){
                        //maker (asker) wants to sell more than taker(bidder) wants to buy
                        
                        buy( hmi, bhm );
                        del = true;
                        mnd = false;
                    } else {
                        //maker(asker) wants to sell less than taker(bidder) wants to buy
                        
                        shm = safeSub( shm , mbu );
                        bhm = safeMul( offers[id].sell_how_much, bhm ) / shm;
                        buy( hmi, mse );
                    }
                } else {
                    //lowest maker (ask) price is higher than current taker (bid) price

                    mnd = false;
                }
            } else {
                //there is no maker(ask) offer to match

                mnd = false;
            }
        }
        if( ! del ) {
            //offer should be created            
            var id = super.offer( shm, swt, bhm, bwt );
            
            assert( id > 0 );
            
            //insert offer into the sorted list
            if ( pos != 0
                && offers[pos].active 
                && isLtOrEq( id, pos  )
                && ( loi[pos] == 0 || !isLtOrEq( id, loi[pos] ) 
               ) ) {
                //client provided valid position

                intoSorted( id, pos );
            } else {
                //client did not provide valid position, 
                //so we have to find it ourselves
                
                pos = 0;

                if( big[swt][bwt] > 0 && isLtOrEq( id, big[swt][bwt] ) ) {
                    //pos was 0 because user did not provide one  

                     pos = findPos(id);
                }
                intoSorted( id, pos );
            }
        }
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

    function offer( 
                     uint shm   //sell how much
                   , ERC20 swt  //sell which token
                   , uint bhm   //buy how much
                   , ERC20 bwt  //buy which token
                  )
        /*NOT synchronized!!! */
        returns (uint) 
    {
        return offer( shm, swt, bhm, bwt, 0 ); 
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    // If user provides the pos of the next higher priced offer, 

    function offer( 
                     uint shm   //sell how much
                   , ERC20 swt  //sell which token
                   , uint bhm   //buy how much
                   , ERC20 bwt  //buy which token
                   , uint pos   //position to insert offer
                  )
        /*NOT synchronized!!! */
        can_offer
        returns ( uint id )
    {
        if(normal_operation){
            assert(min_sell_amount[swt] <= shm);
            matchOffer( shm, swt, bhm, bwt, pos );
        }else{
            //revert to expiring market
            super.offer( shm, swt, bhm, bwt );
        }
    }

    // Accept given quantity (`num`) of an offer. Transfers funds from caller to
    // offer maker, and from market to caller.

    function buy( 
                   uint id          //id of offer to buy from
                 , uint num         //quantity of token to buy
                )
        /*NOT synchronized!!! */
        can_buy(id)
        returns ( bool success )
    {
        if(normal_operation){
            assert(buy_enabled);

            if(num >= offers[id].sell_how_much) {
                fromSorted(
                             id
                           , offers[id].sell_which_token
                           , offers[id].buy_which_token
                         );
            }
            assert( super.buy( id, num ) ); 

            success = true;
        }else{
            //revert to expiring market
            success = super.buy( id, num ); 
        }
    }

    // Cancel an offer. Refunds offer maker.

    function cancel( uint id )
        /*NOT synchronized!!! */
        can_cancel(id)
        returns ( bool success )
    {
        if(normal_operation){
            fromSorted( 
                         id 
                       , offers[id].sell_which_token
                       , offers[id].buy_which_token 
                      );
        }
        return super.cancel(id);
    }
    
	function setMinSellAmount(ERC20 sell_which_token, uint min_amount)
	auth
	returns (bool success) {
		min_sell_amount[sell_which_token] = min_amount;
		LogSetMinSellAmount(sell_which_token, min_amount);
		success = true;
	}

	function getMinSellAmount(ERC20 sell_which_token)
	constant
	returns (uint) {
		return min_sell_amount[sell_which_token];
	}

	function isBuyEnabled() constant returns (bool){
		return buy_enabled;
	}

	function enableBuy() auth returns (bool){
		buy_enabled = true;
		LogSetBuyEnabled(buy_enabled);
		return buy_enabled;
	}

	function disableBuy() auth returns (bool){
		buy_enabled = false;
		LogSetBuyEnabled(buy_enabled);
		return !buy_enabled;
	}

    function setMatching(bool normal_operation_) auth returns (bool) {
        normal_operation = normal_operation_;
        return true;
    }

}
