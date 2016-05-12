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
    function testOfferBuyBitcoin() {
        var id = otc.offer(30, "MKR", 10, "BTC");
        assertEq(id, 1);
        assertEq(otc.last_offer_id(), id);

        var (sell_how_much, sell_which_token,
             buy_how_much, buy_which_token) = otc.getOffer(id);

        assertEq(sell_how_much, 30);
        assertEq32(sell_which_token, "MKR");

        assertEq(buy_how_much, 10);
        assertEq32(buy_which_token, "BTC");
    }
    function testFailOfferSellBitcoin() {
        otc.offer(30, "BTC", 10, "MKR");
    }
}
