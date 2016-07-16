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

    uint public last_offer_id;

    function next_id() internal returns (uint) {
        last_offer_id++; return last_offer_id;
    }

    modifier only_active(uint id) {
        assert(isActive(id));
        _
    }
    modifier only_owner(uint id) {
        assert(getOwner(id) == msg.sender);
        _
    }
    function isActive(uint id) constant returns (bool active) {
        return offers[id].active;
    }
    function getOwner(uint id) constant returns (address owner) {
        return offers[id].owner;
    }

    function offer( uint sell_how_much, ERC20 sell_which_token
                  , uint buy_how_much,  ERC20 buy_which_token )
        exclusive
        returns (uint id)
    {
        assert(sell_how_much > 0);
        assert(sell_which_token != ERC20(0x0));
        assert(buy_how_much > 0);
        assert(buy_which_token != ERC20(0x0));

        var seller_paid = sell_which_token.transferFrom( msg.sender, this, sell_how_much );
        assert(seller_paid);
        OfferInfo memory info;
        info.sell_how_much = sell_how_much;
        info.sell_which_token = sell_which_token;
        info.buy_how_much = buy_how_much;
        info.buy_which_token = buy_which_token;
        info.owner = msg.sender;
        info.active = true;
        id = next_id();
        offers[id] = info;
        ItemUpdate(id);
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
    function buy( uint id, uint quantity )
        only_active(id)
        exclusive
        returns ( bool success )
    {
        var offer = offers[id];

        if ( offer.sell_how_much < quantity ) {
            success = false;
        } else if ( offer.sell_how_much == quantity ) {
            trade( offer.owner, offer.sell_how_much, offer.sell_which_token,
                   msg.sender, offer.buy_how_much, offer.buy_which_token );
            delete offers[id];
            ItemUpdate(id);
            success = true;
        } else {
            uint buy_quantity = quantity * offer.buy_how_much / offer.sell_how_much;
            if ( buy_quantity > 0 ) {
                trade( offer.owner, quantity, offer.sell_which_token,
                       msg.sender, buy_quantity, offer.buy_which_token );

                offer.sell_how_much -= quantity;
                offer.buy_how_much -= buy_quantity;

                ItemUpdate(id);
                success = true;
            }
        }
    }
    function cancel( uint id )
        only_active(id)
        only_owner(id)
        exclusive
        returns ( bool success )
    {
        var offer = offers[id];

        var seller_refunded = offer.sell_which_token.transfer( msg.sender, offer.sell_how_much );
        assert(seller_refunded);

        delete offers[id];
        ItemUpdate(id);

        success = true;
    }
    function getOffer( uint id ) constant
        returns (uint, ERC20, uint, ERC20) {
      var offer = offers[id];
      return (offer.sell_how_much, offer.sell_which_token,
              offer.buy_how_much, offer.buy_which_token);
    }
}
