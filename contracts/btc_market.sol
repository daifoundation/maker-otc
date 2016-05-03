import 'dappsys/auth.sol';
import 'maker-user/user.sol';
import 'assertive.sol';
import 'fallback_failer.sol';
import 'simple_market.sol';

// BTC-relay integration

contract BTCMarket is MakerUser, EventfulMarket, FallbackFailer, Assertive {
    function BTCMarket( MakerUserLinkType registry ) MakerUser( registry ) {}
}
