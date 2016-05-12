import 'maker-user/user_test.sol';
import 'btc_market.sol';

contract BTCMarketTest is Test
                           , MakerUserGeneric(new MakerUserMockRegistry())
                           , EventfulMarket
{
    MakerUserTester user1;
    BTCMarket otc;
    function setUp() {
        otc = new BTCMarket(_M);
        user1 = new MakerUserTester(_M);
        user1._target(otc);
        transfer(user1, 100, "DAI");
        user1.doApprove(otc, 100, "DAI");
        approve(otc, 30, "MKR");
    }
}
