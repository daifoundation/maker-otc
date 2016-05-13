import 'assertive.sol';
import 'dappsys/token/erc20.sol';
import 'fallback_failer.sol';

// A simple direct exchange order manager.

contract EventfulMarket {
    event ItemUpdate( uint id );
    event Trade( uint sell_how_much, ERC20 indexed sell_which_token,
                 uint buy_how_much, ERC20 indexed buy_which_token );
}
contract SimpleMarket is EventfulMarket, FallbackFailer, Assertive {
    struct OfferInfo {
        uint sell_how_much;
        ERC20 sell_which_token;
        uint buy_how_much;
        ERC20 buy_which_token;
        address owner;
        bool active;
    }
    uint public last_offer_id;
    mapping( uint => OfferInfo ) public offers;

    function next_id() internal returns (uint) {
        last_offer_id++; return last_offer_id;
    }
    function offer( uint sell_how_much, ERC20 sell_which_token
                  , uint buy_how_much,  ERC20 buy_which_token )
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
        return id;
    }
    function trade( address seller, uint sell_how_much, ERC20 sell_which_token, address buyer, uint buy_how_much, ERC20 buy_which_token ) internal
    {
        var seller_paid_out = buy_which_token.transferFrom( buyer, seller, buy_how_much );
        assert(seller_paid_out);
        var buyer_paid_out = sell_which_token.transfer( buyer, sell_how_much );
        assert(buyer_paid_out);
        Trade( sell_how_much, sell_which_token, buy_how_much, buy_which_token );
    }
    function buy( uint id )
    {
        var offer = offers[id];
        assert(offer.active);

        trade( offer.owner, offer.sell_how_much, offer.sell_which_token,
               msg.sender, offer.buy_how_much, offer.buy_which_token );

        delete offers[id];
        ItemUpdate(id);
    }
    function buyPartial( uint id, uint quantity )
    {
        var offer = offers[id];
        assert(offer.active);

        if ( offers[id].sell_how_much <= quantity ) {
            trade( offer.owner, offer.sell_how_much, offer.sell_which_token,
                   msg.sender, offer.buy_how_much, offer.buy_which_token );
            delete offers[id];

        } else {
            uint buy_quantity = quantity * offers[id].buy_how_much / offers[id].sell_how_much;
            if ( buy_quantity > 0 ) {
                trade( offer.owner, quantity, offer.sell_which_token,
                       msg.sender, buy_quantity, offer.buy_which_token );

                offer.sell_how_much -= quantity;
                offer.buy_how_much -= buy_quantity;

            }
        }
        ItemUpdate(id);
    }
    function cancel( uint id )
    {
        var offer = offers[id];
        assert(offer.active);
        assert(msg.sender == offer.owner);

        var seller_refunded = offer.sell_which_token.transfer( msg.sender, offer.sell_how_much );
        assert(seller_refunded);
        delete offers[id];
        ItemUpdate(id);
    }
    function getOffer( uint id ) constant
        returns (uint, ERC20, uint, ERC20) {
      var offer = offers[id];
      return (offer.sell_how_much, offer.sell_which_token,
              offer.buy_how_much, offer.buy_which_token);
    }
}
