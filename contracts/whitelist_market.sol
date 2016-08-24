import 'expiring_market.sol';


contract WhitelistedMarket is ExpiringMarket {
    mapping( address => bool ) public whitelisted;

    modifier only_whitelisted(ERC20 token) {
        assert(whitelisted[token]);
        _
    }

    function WhitelistedMarket(uint lifetime, address[] whitelist)
        ExpiringMarket(lifetime)
    {
        for( uint i = 0; i < whitelist.length; i++ ) {
            whitelisted[whitelist[i]] = true;
        }
    }

    function offer ( uint sell_how_much, ERC20 sell_which_token,
                     uint buy_how_much,  ERC20 buy_which_token )
        only_whitelisted(sell_which_token)
        only_whitelisted(buy_which_token)
        returns (uint id)
    {
        return super.offer(sell_how_much, sell_which_token, buy_how_much, buy_which_token);
    }
}
