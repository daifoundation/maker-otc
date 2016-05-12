import 'dappsys/auth.sol';
import 'maker-user/user.sol';
import 'assertive.sol';
import 'fallback_failer.sol';
import 'simple_market.sol';

// BTC-relay integration

contract BTCMarket is MakerUser, EventfulMarket, FallbackFailer, Assertive {
    struct OfferInfo {
        uint sell_how_much;
        bytes32 sell_which_token;
        uint buy_how_much;
        bytes32 buy_which_token;
        address owner;
        bool active;
        bytes20 btc_address;
    }
    uint public last_offer_id;
    mapping( uint => OfferInfo ) public offers;

    function BTCMarket( MakerUserLinkType registry ) MakerUser( registry ) {}

    function next_id() internal returns (uint) {
        last_offer_id++; return last_offer_id;
    }
    function offer( uint sell_how_much, bytes32 sell_which_token,
                    uint buy_how_much,  bytes32 buy_which_token,
                    bytes20 btc_address )
        returns (uint id)
    {
        assert(sell_how_much > 0);
        assert(sell_which_token != 0x0);
        assert(sell_which_token != 'BTC');
        assert(buy_how_much > 0);
        assert(buy_which_token == 'BTC');

        transferFrom( msg.sender, this, sell_how_much, sell_which_token );
        OfferInfo memory info;
        info.sell_how_much = sell_how_much;
        info.sell_which_token = sell_which_token;
        info.buy_how_much = buy_how_much;
        info.buy_which_token = buy_which_token;
        info.owner = msg.sender;
        info.active = true;
        info.btc_address = btc_address;
        id = next_id();
        offers[id] = info;
        ItemUpdate(id);
        return id;
    }
    function getOffer( uint id ) constant
        returns (uint, bytes32, uint, bytes32) {
      var offer = offers[id];
      return (offer.sell_how_much, offer.sell_which_token,
              offer.buy_how_much, offer.buy_which_token);
    }
    function getBtcAddress( uint id ) constant returns (bytes20) {
        var offer = offers[id];
        return offer.btc_address;
    }
}
