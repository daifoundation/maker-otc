import 'dappsys/auth.sol';
import 'makeruser/user.sol';

// A simple direct exchange order manager.
// Orders cannot be partially filled.

contract ItemUpdateEvent {
    event ItemUpdate( uint id );
}
contract AtomicTrade is MakerUser, ItemUpdateEvent {
    struct OfferInfo {
        uint sell_how_much;
        bytes32 sell_which_token;
        uint buy_how_much;
        bytes32 buy_which_token;
        address owner;
        bool active;
    }
    uint public last_offer_id;
    mapping( uint => OfferInfo ) public offers;

    function AtomicTrade( MakerUserLinkType registry )
             MakerUser( registry )
    {
    }
    
    function next_id() internal returns (uint) {
        last_offer_id++; return last_offer_id;
    }

    function offer( uint sell_how_much, bytes32 sell_which_token
                  , uint buy_how_much,  bytes32 buy_which_token )
        returns (uint id)
    {
        transferFrom( msg.sender, this, sell_how_much, sell_which_token );
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
    function buy( uint id )
    {
        var offer = offers[id];
        transferFrom( msg.sender, offer.owner, offer.buy_how_much, offer.buy_which_token );
        transfer( msg.sender, offer.sell_how_much, offer.sell_which_token );
        delete offers[id];
        ItemUpdate(id);
    }
    function cancel( uint id )
    {
        var offer = offers[id];
        if( msg.sender == offer.owner ) {
            transfer( msg.sender, offer.sell_how_much, offer.sell_which_token );
            delete offers[id];
            ItemUpdate(id);
        } else {
            throw;
        }
    }
}

contract AtomicTradeMainnet is AtomicTrade(MakerUserLinkType(0x0)) {}
contract AtomicTradeMorden is AtomicTrade(MakerUserLinkType(0x1)) {}
