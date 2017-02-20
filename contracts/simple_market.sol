pragma solidity ^0.4.2;

import 'erc20/erc20.sol';

import 'assertive.sol';
import 'fallback_failer.sol';
import 'mutex.sol';

// A simple direct exchange order manager.

contract EventfulMarket {
    event ItemUpdate( uint id );
    event Trade( uint sell_how_much, address indexed sell_which_token,
                 uint buy_how_much, address indexed buy_which_token );
}
contract SimpleMarket is EventfulMarket
                       , Assertive
                       , FallbackFailer
                       , MutexUser
{
    struct OfferInfo {
        uint sell_how_much;
        ERC20 sell_which_token;
        uint buy_how_much;
        ERC20 buy_which_token;
        address owner;
        bool active;
    }
    mapping( uint => OfferInfo ) public offers;

    mapping( uint => uint ) public lower_offer_id;
    
    mapping( uint => uint ) public higher_offer_id;

    mapping( address => mapping( address => uint ) ) public higher_offer_id_size;

    mapping( address => mapping( address => uint ) ) public lowest_offer_id;

    mapping( address => mapping( address => uint ) ) public highest_offer_id;

    uint public last_offer_id;

    function next_id() internal returns (uint) {
        last_offer_id++; return last_offer_id;
    }

    modifier can_offer {
        _;
    }
    modifier can_buy(uint id) {
        assert(isActive(id));
        _;
    }
    modifier can_cancel(uint id) {
        assert(isActive(id));
        assert(getOwner(id) == msg.sender);
        _;
    }
    function isActive(uint id) constant returns (bool active) {
        return offers[id].active;
    }
    function getOwner(uint id) constant returns (address owner) {
        return offers[id].owner;
    }
    function getOffer( uint id ) constant returns (uint, ERC20, uint, ERC20) {
      var offer = offers[id];
      return (offer.sell_how_much, offer.sell_which_token,
              offer.buy_how_much, offer.buy_which_token);
    }
    function getHighestOffer(ERC20 sell_token, ERC20 buy_token) constant returns(uint) {
        address buy_which = address(buy_token);
        address sell_which = address(sell_token);
        return highest_offer_id[sell_which][buy_which];
    }
    function getLowestOffer(ERC20 sell_token, ERC20 buy_token) constant returns(uint) {
        address buy_which = address(buy_token);
        address sell_which = address(sell_token);
        return lowest_offer_id[sell_which][buy_which];
    }
    function getLowerOfferId(uint id) constant returns(uint) {
        return lower_offer_id[id];
    }
    function getHigherOfferId(uint id) constant returns(uint) {
        return higher_offer_id[id];
    }
    function getHigherOfferIdSize(ERC20 sell_token, ERC20 buy_token) constant returns(uint) {
        address buy_which = address(buy_token);
        address sell_which = address(sell_token);
        return higher_offer_id_size[sell_which][buy_which];
    }
    function checkIsLtOrEq(uint lower_id, uint higher_id) constant returns(bool) {
        return isLtOrEq(lower_id, higher_id);
    }


    // non underflowing subtraction
    function safeSub(uint a, uint b) internal returns (uint) {
        assert(b <= a);
        return a - b;
    }
    // non overflowing multiplication
    function safeMul(uint a, uint b) internal returns (uint c) {
        c = a * b;
        assert(a == 0 || c / a == b);
    }

    function trade( address seller, uint sell_how_much, ERC20 sell_which_token,
                    address buyer,  uint buy_how_much,  ERC20 buy_which_token )
        internal
    {
        var seller_paid_out = buy_which_token.transferFrom( buyer, seller, buy_how_much );
        assert(seller_paid_out);
        var buyer_paid_out = sell_which_token.transfer( buyer, sell_how_much );
        assert(buyer_paid_out);
        Trade( sell_how_much, sell_which_token, buy_how_much, buy_which_token );
    }
    function tradeOffers( address seller, uint sell_how_much, ERC20 sell_which_token,
                    address buyer,  uint buy_how_much,  ERC20 buy_which_token )
        internal
    {
        var seller_paid_out = buy_which_token.transfer( seller, buy_how_much );
        assert(seller_paid_out);
        var buyer_paid_out = sell_which_token.transfer( buyer, sell_how_much );
        assert(buyer_paid_out);
    }
    function insertIntoSortedList( uint id, uint user_higher_id )
    internal
    {
        OfferInfo offer = offers[id];
        address buy_which = address(offer.buy_which_token);
        address sell_which = address(offer.sell_which_token);
        uint lower_id;
        uint highest_id;
       

        if ( user_higher_id != 0 ) {
            //offers[id] is not the highest offer
            
            assert(offers[user_higher_id].sell_which_token == offer.sell_which_token);
            assert(offers[user_higher_id].buy_which_token == offer.buy_which_token);
            //make sure offers[id] price is lower than offers[higher_offer] price
            assert(isLtOrEq(id,user_higher_id));

            higher_offer_id[id] = user_higher_id;
            higher_offer_id_size[sell_which][buy_which]++;
            if ( user_higher_id != lowest_offer_id[sell_which][buy_which] ) {
                //offers[id] is not the lowest offer 
                
                lower_id = lower_offer_id[user_higher_id];
                //make sure offer price is higher than lower_offer price
                assert( lower_id == 0 || isLtOrEq( lower_id, id ) ); 
                
                if( lower_id > 0 ) {
                    higher_offer_id[lower_id] = id;
                }
                lower_offer_id[id] = lower_id;
                lower_offer_id[user_higher_id] = id;
            }else{
                //offers[id] is the lowest offer
                
                lower_offer_id[user_higher_id] = id;
                lowest_offer_id[sell_which][buy_which] = id;                
            }
        } else {
            //offers[id] is the highest offer

            highest_id = highest_offer_id[sell_which][buy_which];
            if ( highest_id != 0 ) {
                //offers[id] is at least the second offer that was stored

                higher_offer_id[highest_id] = id;
                
                higher_offer_id_size[sell_which][buy_which]++;

                //make sure offer price is higher than highest_offer price
                assert( isLtOrEq( highest_id, id ) );
                assert( offer.sell_which_token == offers[highest_id].sell_which_token);
                assert( offer.buy_which_token == offers[highest_id].buy_which_token);

                lower_offer_id[id] = highest_id;
            } else {
                //offers[id] is the first offer that is stored
                lowest_offer_id[sell_which][buy_which] = id;
            }
            highest_offer_id[sell_which][buy_which] = id;
        }
    }
    //return true if offers[lower_offer_id] has less than or equal 
    //price as offers[higher_offer_id]
    function isLtOrEq(uint lower_offer_id, uint higher_offer_id) 
    internal
    returns (bool)
    {
        OfferInfo higher_offer = offers[higher_offer_id];
        OfferInfo lower_offer = offers[lower_offer_id];
        
        return safeMul( lower_offer.buy_how_much
                , higher_offer.sell_how_much ) 
                >= 
                safeMul( higher_offer.buy_how_much
                , lower_offer.sell_how_much ); 
    }
    //find the id of the next higher offer, than offers[id]
    function findWhereToInsertId(uint id)
    internal
    returns (uint)
    {
        address buy_which = address(offers[id].buy_which_token);
        address sell_which = address(offers[id].sell_which_token);
        uint higher_id = highest_offer_id[sell_which][buy_which];
        assert( id > 0 ); 
        
		if ( higher_id == 0 ) {
            //there are no offers stored
			return 0;
		}
        if ( higher_offer_id_size[sell_which][buy_which] > 0 ) {
            //there is at least two offers stored for token pair

            if ( isLtOrEq( higher_id, id) ) {
                //did not find any offer that has higher price than offers[id]

                return 0;

            } else {
                //offers[higher_id] is higher priced than offers[id]

                //cycle through all offers for token pair to find first one  
                //with lower or equal price
                while (lower_offer_id[higher_id] != 0 
                       && !isLtOrEq( lower_offer_id[higher_id], id ) 
                        ) {

                    higher_id = lower_offer_id[higher_id];
                }

                return higher_id;
            }
        } else {
            //there is maximum one offer stored

            if ( lowest_offer_id[sell_which][buy_which] == 0 ) {
                //there is no offer stored yet
                
                return 0;
            }
            if ( isLtOrEq( id, higher_id ) ) {
                //there is exactly one offer stored, and it IS higher than offers[id]

                return higher_id;
            } else {
                //there is exatly one offer stored, but lower than offers[id]

                return 0;
            }
        }
    }
    // Delete offer and remove it from the sorted list.
    function deleteOffer(uint id)
        internal
        returns (bool)
        {
        address buy_which = address(offers[id].buy_which_token);
        address sell_which = address(offers[id].sell_which_token);

        if(highest_offer_id[sell_which][buy_which] == id){
            //offers[id] is the highest offer
        
            highest_offer_id[sell_which][buy_which] = lower_offer_id[id]; 
            delete higher_offer_id[lower_offer_id[id]];
            delete lower_offer_id[id];
            if ( higher_offer_id_size[sell_which][buy_which] > 0 ) {
                //there is at least one offer left
        
                higher_offer_id_size[sell_which][buy_which]--;
            } else {
                //offer was the last offer 
        
                lowest_offer_id[sell_which][buy_which] = 0;
            }
        } else if( lowest_offer_id[sell_which][buy_which] == id ) {
            //offers[id] is the lowest offer
        
            lowest_offer_id[sell_which][buy_which] = higher_offer_id[id]; 
            delete lower_offer_id[ higher_offer_id[id] ];
            delete higher_offer_id[id];
            higher_offer_id_size[sell_which][buy_which]--;
        } else {
            //offers[id] is between the highest and the lowest offer

            if( lower_offer_id[id] == 0 ) {
                //offer was not in the sorted list
            
                delete offers[id];
                ItemUpdate(id);
                return true;
            }
            lower_offer_id[higher_offer_id[id]] = lower_offer_id[id];
            higher_offer_id[lower_offer_id[id]] = higher_offer_id[id];
            delete lower_offer_id[id];
            delete higher_offer_id[id];
            higher_offer_id_size[sell_which][buy_which]--;
        }
        delete offers[id];
        ItemUpdate(id);
        return true;
    }
    function matchOffer(uint id, uint user_higher_id)
        internal
        {

        // read-only offer. Modify an offer by directly accessing offers[id]
        address buy_which = address(offers[id].buy_which_token);
        address sell_which = address(offers[id].sell_which_token);
        uint bid_buy_how_much;
        uint bid_sell_how_much;
        uint ask_buy_how_much;
        uint ask_sell_how_much;
        bool offer_deleted = false;
        bool matching_done = false;      
        uint highest_ask_id;
        uint spend;
        
        assert( id > 0 );

        assert( user_higher_id == 0 
               || offers[id].buy_which_token == offers[user_higher_id].buy_which_token );

        assert(user_higher_id == 0 
               || offers[id].sell_which_token == offers[user_higher_id].sell_which_token);

        while ( !matching_done 
               && highest_offer_id[buy_which][sell_which] > 0) {

            highest_ask_id = highest_offer_id[buy_which][sell_which];

            if ( highest_ask_id > 0 ) {
                //there is at least one ask offer stored 
                
                ask_buy_how_much = offers[highest_ask_id].buy_how_much;
                ask_sell_how_much = offers[highest_ask_id].sell_how_much;
                bid_buy_how_much = offers[id].buy_how_much;
                bid_sell_how_much = offers[id].sell_how_much;

                if ( safeMul( ask_buy_how_much , bid_buy_how_much ) 
                    <= safeMul( bid_sell_how_much , ask_sell_how_much ) ) {
                    //ask price is lower than or equal to bid price

                    if ( ask_sell_how_much >= bid_buy_how_much ){
                        //asker wants to sell more than bidder wants to buy
                        
                        spend = safeMul( bid_buy_how_much, ask_buy_how_much ) 
                            / ask_sell_how_much;  

                        tradeOffers( offers[highest_ask_id].owner
                            , bid_buy_how_much
                            , offers[highest_ask_id].sell_which_token
                            , msg.sender
                            , spend
                            , offers[highest_ask_id].buy_which_token );

                        offers[highest_ask_id].buy_how_much 
                            = safeSub( ask_buy_how_much , spend);

                        offers[highest_ask_id].sell_how_much 
                            = safeSub( ask_sell_how_much , bid_buy_how_much);

                        if( ask_sell_how_much == bid_buy_how_much ){
                            //ask offer must also be deleted

                            deleteOffer(highest_ask_id); 
                        }else{
                            //ask offer should not be deletet, only updated

                            ItemUpdate(highest_ask_id);
                        }

                        deleteOffer(id);
                        offer_deleted = true;
                        matching_done = true;
                    } else {
                        //asker wants to sell less than bidder wants to buy
                        
                        tradeOffers( offers[highest_ask_id].owner
                            , ask_sell_how_much
                            , offers[highest_ask_id].sell_which_token
                            , msg.sender
                            , ask_buy_how_much
                            , offers[highest_ask_id].buy_which_token );
                       
                        offers[id].buy_how_much 
                            = safeSub( bid_buy_how_much , ask_sell_how_much);
                        
                        offers[id].sell_how_much 
                            = safeSub( bid_sell_how_much , ask_buy_how_much);

                        deleteOffer(highest_ask_id);
                        matching_done = false;
                    }
                } else {
                    //lowest ask price is higher than current bid price

                    matching_done = true;
                }
            } else {
                //there is no ask offer to match

                matching_done = true;
            }
        }
        if( ! offer_deleted ) {
            //offer was not deleted during matching
            
            ItemUpdate(id);
            //insert offer into the sorted list
            if ( user_higher_id != 0
                && !isLtOrEq( user_higher_id, id )
                && ( lower_offer_id[user_higher_id] == 0
                     || isLtOrEq( lower_offer_id[user_higher_id], id ) 
               ) ) {
                //client provided valid user_higher_id

                insertIntoSortedList( id, user_higher_id );
            } else {
                //client did not provide valid user_higher_id, so we have to
                //find one ourselves
                
                if( highest_offer_id[sell_which][buy_which] > 0
                 && !isLtOrEq( highest_offer_id[sell_which][buy_which], id ) ) {
                    //user_higher_id was 0 because user did not provide one  

                     user_higher_id = findWhereToInsertId(id);
                }
                insertIntoSortedList( id, user_higher_id );
            }
        }
    }
    // ---- Public entrypoints ---- //

    // Make a new offer. Takes funds from the caller into market escrow.
    function offer( uint sell_how_much, ERC20 sell_which_token
                  , uint buy_how_much,  ERC20 buy_which_token)
        /*NO exclusive!!! */
        returns (uint) 
    {
        return offer( sell_how_much, sell_which_token, buy_how_much, buy_which_token, 0 ); 
    }
    // Make a new offer. Takes funds from the caller into market escrow.
    // If user provides the user_higher_id of the next higher priced offer, 
    // gas burning will be proportional to the amount of matched orders. 
    function offer( uint sell_how_much, ERC20 sell_which_token
                  , uint buy_how_much,  ERC20 buy_which_token
                  , uint user_higher_id)
        can_offer
        exclusive
        returns (uint id)
    {
        assert(sell_how_much > 0);
        assert(sell_which_token != ERC20(0x0));
        assert(buy_how_much > 0);
        assert(buy_which_token != ERC20(0x0));
        assert(sell_which_token != buy_which_token);

        OfferInfo memory info;
        info.sell_how_much = sell_how_much;
        info.sell_which_token = sell_which_token;
        info.buy_how_much = buy_how_much;
        info.buy_which_token = buy_which_token;
        info.owner = msg.sender;
        info.active = true;
        id = next_id();
        offers[id] = info;

        var seller_paid = sell_which_token.transferFrom( msg.sender, this, sell_how_much );
        assert(seller_paid);
        
        matchOffer( id, user_higher_id );
    }
    // Accept given `quantity` of an offer. Transfers funds from caller to
    // offer maker, and from market to caller.
    function buy( uint id, uint quantity )
        can_buy(id)
        exclusive
        returns ( bool success )
    {
        // read-only offer. Modify an offer by directly accessing offers[id]
        OfferInfo memory offer = offers[id];

        // inferred quantity that the buyer wishes to spend
        uint spend = safeMul(quantity, offer.buy_how_much) / offer.sell_how_much;

        if ( spend > offer.buy_how_much || quantity > offer.sell_how_much ) {
            // buyer wants more than is available
            success = false;
        } else if ( spend == offer.buy_how_much && quantity == offer.sell_how_much ) {
            // buyer wants exactly what is available

            trade( offer.owner, quantity, offer.sell_which_token,
                   msg.sender, spend, offer.buy_which_token );
            deleteOffer(id);

            success = true;
        } else if ( spend > 0 && quantity > 0 ) {
            // buyer wants a fraction of what is available
            offers[id].sell_how_much = safeSub(offer.sell_how_much, quantity);
            offers[id].buy_how_much = safeSub(offer.buy_how_much, spend);

            trade( offer.owner, quantity, offer.sell_which_token,
                    msg.sender, spend, offer.buy_which_token );

            ItemUpdate(id);
            success = true;
        } else {
            // buyer wants an unsatisfiable amount (less than 1 integer)
            success = false;
        }
    }
    // Cancel an offer. Refunds offer maker.
    function cancel( uint id )
        can_cancel(id)
        exclusive
        returns ( bool success )
    {
        // read-only offer. Modify an offer by directly accessing offers[id]
        OfferInfo memory offer = offers[id];

        var seller_refunded = offer.sell_which_token.transfer( offer.owner , offer.sell_how_much );
        assert(seller_refunded);
        
        deleteOffer(id);
        success = true;
    }
}
