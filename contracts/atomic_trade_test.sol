import 'maker-user/user_test.sol';
import 'atomic_trade.sol';

contract AtomicTradeTest is Test
                           , MakerUserGeneric(new MakerUserMockRegistry())
                           , EventfulMarket
{
    MakerUserTester user1;
    AtomicTrade otc;
    function setUp() {
        otc = new AtomicTrade(_M);
        user1 = new MakerUserTester(_M);
        user1._target(otc);
        transfer(user1, 100, "DAI");
        user1.doApprove(otc, 100, "DAI");
        approve(otc, 30, "MKR");
    }
    function testBasicTrade() {
        user1.doApprove(otc, 100, "DAI");
        var my_mkr_balance_before = balanceOf(this, "MKR");
        var my_dai_balance_before = balanceOf(this, "DAI");
        var user1_mkr_balance_before = balanceOf(user1, "MKR");
        var user1_dai_balance_before = balanceOf(user1, "DAI");

        var id = otc.offer( 30, "MKR", 100, "DAI" );
        AtomicTrade(user1).buy(id);
        var my_mkr_balance_after = balanceOf(this, "MKR");
        var my_dai_balance_after = balanceOf(this, "DAI");
        var user1_mkr_balance_after = balanceOf(user1, "MKR");
        var user1_dai_balance_after = balanceOf(user1, "DAI");
        assertEq( 30, my_mkr_balance_before - my_mkr_balance_after );
        assertEq( 100, my_dai_balance_after - my_dai_balance_before );
        assertEq( 30, user1_mkr_balance_after - user1_mkr_balance_before );
        assertEq( 100, user1_dai_balance_before - user1_dai_balance_after );

        expectEventsExact(otc);
        ItemUpdate(id);
        Trade( 30, "MKR", 100, "DAI" );
        ItemUpdate(id);
    }
    function testPartiallyFilledOrderMkr() {
        user1.doApprove(otc, 30, "DAI");
        approve(otc, 200, "MKR");

        var my_mkr_balance_before = balanceOf(this, "MKR");
        var my_dai_balance_before = balanceOf(this, "DAI");
        var user1_mkr_balance_before = balanceOf(user1, "MKR");
        var user1_dai_balance_before = balanceOf(user1, "DAI");

        var id = otc.offer( 200, "MKR", 500, "DAI" );
        AtomicTrade(user1).buyPartial(id, 10);
        var my_mkr_balance_after = balanceOf(this, "MKR");
        var my_dai_balance_after = balanceOf(this, "DAI");
        var user1_mkr_balance_after = balanceOf(user1, "MKR");
        var user1_dai_balance_after = balanceOf(user1, "DAI");
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(id);

        assertEq( 200, my_mkr_balance_before - my_mkr_balance_after );
        assertEq( 25, my_dai_balance_after - my_dai_balance_before );
        assertEq( 10, user1_mkr_balance_after - user1_mkr_balance_before );
        assertEq( 25, user1_dai_balance_before - user1_dai_balance_after );
        assertEq( 190, sell_val );
        assertEq( 475, buy_val );

        expectEventsExact(otc);
        ItemUpdate(id);
        Trade( 10, "MKR", 25, "DAI" );
        ItemUpdate(id);
    }
    function testPartiallyFilledOrderDai() {
        transfer(user1, 10, "MKR");
        user1.doApprove(otc, 10, "MKR");
        approve(otc, 500, "DAI");

        var my_mkr_balance_before = balanceOf(this, "MKR");
        var my_dai_balance_before = balanceOf(this, "DAI");
        var user1_mkr_balance_before = balanceOf(user1, "MKR");
        var user1_dai_balance_before = balanceOf(user1, "DAI");

        var id = otc.offer( 500, "DAI", 200, "MKR" );
        AtomicTrade(user1).buyPartial(id, 10);
        var my_mkr_balance_after = balanceOf(this, "MKR");
        var my_dai_balance_after = balanceOf(this, "DAI");
        var user1_mkr_balance_after = balanceOf(user1, "MKR");
        var user1_dai_balance_after = balanceOf(user1, "DAI");
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(id);
        
        assertEq( 500, my_dai_balance_before - my_dai_balance_after );
        assertEq( 4, my_mkr_balance_after - my_mkr_balance_before );
        assertEq( 10, user1_dai_balance_after - user1_dai_balance_before );
        assertEq( 4, user1_mkr_balance_before - user1_mkr_balance_after );
        assertEq( 490, sell_val );
        assertEq( 196, buy_val );

        expectEventsExact(otc);
        ItemUpdate(id);
        Trade( 10, "DAI", 4, "MKR" );
        ItemUpdate(id);
    }
    function testCancel() {
        approve(otc, 30, "MKR");
        var id = otc.offer( 30, "MKR", 100, "DAI" );
        otc.cancel(id);

        expectEventsExact(otc);
        ItemUpdate(id);
        ItemUpdate(id);
    }

    function testFailOfferNotEnoughFunds() {
        transfer(address(0x0), balanceOf(this, "MKR")-29, "MKR");
        var id = otc.offer(30, "MKR", 100, "DAI");
    }
    function testFailBuyNotEnoughFunds() {
        throw;
        var id = otc.offer(30, "MKR", 101, "DAI");
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        user1.doApprove(otc, 101, "DAI");
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        log_named_uint("user1 dai balance before", balanceOf(user1, "DAI"));
        AtomicTrade(user1).buy(id);
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        log_named_uint("user1 dai balance after", balanceOf(user1,"DAI"));
    }
    function testFailBuyNotEnoughApproval() {
        throw;
        var id = otc.offer(30, "MKR", 100, "DAI");
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        user1.doApprove(otc, 99, "DAI");
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        log_named_uint("user1 dai balance before", balanceOf(user1, "DAI"));
        AtomicTrade(user1).buy(id);
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        log_named_uint("user1 dai balance after", balanceOf(user1,"DAI"));
    }
}
