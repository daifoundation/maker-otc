import 'dappsys/auth.sol';
import 'maker-user/user.sol';
import 'btc-tx/btc_tx.sol';
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
        uint deposit_how_much;
        bytes32 deposit_which_token;
        address owner;
        bool active;
        bytes20 btc_address;
        address locked;
        uint256 confirmed;
    }
    uint public last_offer_id;
    mapping( uint => OfferInfo ) public offers;
    mapping( uint256 => uint) public offersByTxHash;

    address public trustedRelay;
    BTCTxParser parser;

    function BTCMarket( MakerUserLinkType registry, address BTCRelay)
                        MakerUser( registry )
    {
        trustedRelay = BTCRelay;
        parser = new BTCTxParser();
    }

    function next_id() internal returns (uint) {
        last_offer_id++; return last_offer_id;
    }
    function offer( uint sell_how_much, bytes32 sell_which_token,
                    uint buy_how_much,  bytes32 buy_which_token,
                    bytes20 btc_address )
        returns (uint id)
    {
        return offer(sell_how_much, sell_which_token,
                     buy_how_much, buy_which_token,
                     btc_address, 0, "DAI");
    }
    function offer( uint sell_how_much, bytes32 sell_which_token,
                    uint buy_how_much,  bytes32 buy_which_token,
                    bytes20 btc_address, uint deposit_how_much,
                    bytes32 deposit_which_token)
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
        info.deposit_how_much = deposit_how_much;
        info.deposit_which_token = deposit_which_token;

        info.owner = msg.sender;
        info.active = true;
        info.btc_address = btc_address;
        id = next_id();
        offers[id] = info;
        ItemUpdate(id);
        return id;
    }
    function buy ( uint id ) {
        assert(!isLocked(id));
        var offer = offers[id];
        offer.locked = msg.sender;
        transferFrom( msg.sender, this, offer.deposit_how_much, offer.deposit_which_token );
    }
    function cancel( uint id )
    {
        var offer = offers[id];
        assert(offer.active);
        assert(msg.sender == offer.owner);
        assert(!isLocked(id));

        transfer( msg.sender, offer.sell_how_much, offer.sell_which_token );
        delete offers[id];
        ItemUpdate(id);
    }
    function confirm( uint id, uint256 txHash ) {
        var offer = offers[id];
        assert(offer.locked == msg.sender);
        offer.confirmed = txHash;
        offersByTxHash[txHash] = id;
    }
    function processTransaction(bytes txBytes, uint256 txHash)
        returns (int256)
    {
        var id = offersByTxHash[txHash];
        var offer = offers[id];

        var sent = parser.checkValueSent(txBytes,
                                         offer.btc_address,
                                         offer.buy_how_much);

        if (sent) {
            var buyer = offer.locked;
            transfer(buyer, offer.sell_how_much, offer.sell_which_token);
            transfer(buyer, offer.deposit_how_much, offer.deposit_which_token );
            delete offers[id];
            return 0;
        } else {
            return 1;
        }
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
    function getOfferByTxHash( uint256 txHash ) returns (uint id) {
        return offersByTxHash[txHash];
    }
    function getRelay() returns (address) {
        return trustedRelay;
    }
    function isLocked( uint id ) constant returns (bool) {
        var offer = offers[id];
        return (offer.locked != 0x00);
    }
    function isConfirmed( uint id ) constant returns (bool) {
        var offer = offers[id];
        return (offer.confirmed != 0);
    }
}
