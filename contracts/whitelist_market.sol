import 'expiring_market.sol';


contract WhitelistedMarket is ExpiringMarket {
    address public constant MKR = 0x11;
    address public constant ETH = 0x22;

    modifier only_whitelisted(ERC20 selling, ERC20 buying) {
        assert(selling == ETH || selling == MKR);
        assert(buying == ETH || buying == MKR);
        _
    }

    function offer ( uint sell_how_much, ERC20 sell_which_token,
                     uint buy_how_much,  ERC20 buy_which_token )
        only_whitelisted(sell_which_token, buy_which_token)
        returns (uint id)
    {
        return super.offer(sell_how_much, sell_which_token, buy_how_much, buy_which_token);
    }
}
