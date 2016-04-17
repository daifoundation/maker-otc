import 'feedbase/feedbase.sol';
import 'feedbase/user.sol';

import 'fallback_failer.sol';
import 'lpc.sol';

// Factory + creation event.
contract BasicLiquidityProviderFactory is FallbackFailer, FeedBaseUser, DSAuthUser
{
    function BasicLiquidityProviderFactory( FeedBase _feedbase
                                          , MakerUserLinkType _M )
             FeedBaseUser(_feedbase, _M)
    {}

    event NewBasicLPC( address indexed lpc );

    function create() returns (BasicLiquidityProvider) {
        var lpc = new BasicLiquidityProvider(_feedbase, _M);
        transferFrom(msg.sender, lpc, allowance(lpc, this, "DAI"), "DAI");
        NewBasicLPC(lpc);
        setOwner( lpc, msg.sender );
        return lpc;
    }
}
