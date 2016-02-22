import 'dappsys/auth.sol';
import 'makeruser/user.sol';

// A simple direct exchange order manager.
// Orders cannot be partially filled.
// Buy/sell function auto-deposits to the ETH token wrapper if msg.value equals deposit amount.

contract ItemUpdateEvent {
    event ItemUpdate( uint id );
}
contract AtomicSeller is MakerUserGeneric, ItemUpdateEvent {
    struct OfferInfo {
        uint sell_how_much;
        bytes32 sell_which_token;
        uint buy_how_much;
        bytes32 buy_which_token;
        address owner;
        bool active;
    }
    uint public last_offer_id;
    mapping( uint => OfferInfo ) _offers;

    function AtomicSeller( MakerTokenRegistry reg )
             MakerUserGeneric( reg )
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
        _offers[id] = info;
        ItemUpdate(id);
        return id;
    }
    function buy( uint id )
    {
        var offer = _offers[id];
        transferFrom( msg.sender, offer.owner, offer.buy_how_much, offer.buy_which_token );
        transfer( msg.sender, offer.sell_how_much, offer.sell_which_token );
        delete _offers[id];
        ItemUpdate(id);
    }
    function cancel( uint id )
    {
        var offer = _offers[id];
        if( msg.sender == offer.owner ) {
            transfer( msg.sender, offer.sell_how_much, offer.sell_which_token );
            delete _offers[id];
            ItemUpdate(id);
        } else {
            throw;
        }
    }
}
