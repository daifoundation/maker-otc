import 'maker-user/user_test.sol';
import 'btc_market.sol';

contract BTCMarketTest is Test
                           , MakerUserGeneric(new MakerUserMockRegistry())
                           , EventfulMarket
{
    MakerUserTester user1;
    MakerUserTester user2;
    BTCMarket otc;
    function setUp() {
        otc = new BTCMarket(_M);
        user1 = new MakerUserTester(_M);
        user1._target(otc);
        user2 = new MakerUserTester(_M);
        user2._target(otc);
        transfer(user1, 100, "DAI");
        user1.doApprove(otc, 100, "DAI");
        approve(otc, 30, "MKR");
    }
    function testOfferBuyBitcoin() {
        bytes20 seller_btc_address = 0x123;
        var id = otc.offer(30, "MKR", 10, "BTC", seller_btc_address);
        assertEq(id, 1);
        assertEq(otc.last_offer_id(), id);

        var (sell_how_much, sell_which_token,
             buy_how_much, buy_which_token) = otc.getOffer(id);

        assertEq(sell_how_much, 30);
        assertEq32(sell_which_token, "MKR");

        assertEq(buy_how_much, 10);
        assertEq32(buy_which_token, "BTC");

        assertEq20(otc.getBtcAddress(id), seller_btc_address);
    }
    function testFailOfferSellBitcoin() {
        otc.offer(30, "BTC", 10, "MKR", 0x11);
    }
    function testFailOfferBuyNotBitcoin() {
        otc.offer(30, "MKR", 10, "DAI", 0x11);
    }
    function testOfferTransferFrom() {
        var my_mkr_balance_before = balanceOf(this, "MKR");
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        var my_mkr_balance_after = balanceOf(this, "MKR");

        var transferred = my_mkr_balance_before - my_mkr_balance_after;

        assertEq(transferred, 30);
    }
    function testBuyLocking() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        assertEq(otc.isLocked(id), false);
        BTCMarket(user1).buy(id);
        assertEq(otc.isLocked(id), true);
    }
    function testCancelUnlocked() {
        var my_mkr_balance_before = balanceOf(this, "MKR");
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        var my_mkr_balance_after = balanceOf(this, "MKR");
        otc.cancel(id);
        var my_mkr_balance_after_cancel = balanceOf(this, "MKR");

        var diff = my_mkr_balance_before - my_mkr_balance_after_cancel;
        assertEq(diff, 0);
    }
    function testFailCancelInactive() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        otc.cancel(id);
        otc.cancel(id);
    }
    function testFailCancelNonOwner() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        BTCMarket(user1).cancel(id);
    }
    function testFailCancelLocked() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        BTCMarket(user1).buy(id);
        otc.cancel(id);
    }
    function testFailBuyLocked() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        BTCMarket(user1).buy(id);
        BTCMarket(user2).buy(id);
    }
}
