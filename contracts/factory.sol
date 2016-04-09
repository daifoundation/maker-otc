// Factory + creation event.
contract BasicLiquidityProviderFactory is FeedBaseUser, DSAuthUser
{
    function BasicLiquidityProviderFactory( FeedBaseUserLinkType _feedbase
                                          , MakerUserLinkType _M )
             FeedBaseUser(_feedbase, _M)
    {}

    event NewBasicLPC( address indexed lpc );

    function create() returns (BasicLiquidityProvider) {
        var lpc = new BasicLiquidityProvider(_feedbase, _M);
        transferFrom(msg.sender, lpc, approval(lpc, this, "DAI"), "DAI");
        NewBasicLPC(lpc);
        setOwner( lpc, msg.sender );
    }
}
