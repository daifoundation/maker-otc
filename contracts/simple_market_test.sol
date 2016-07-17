import 'dapple/test.sol';
import 'erc20/base.sol';
import 'simple_market.sol';

contract MarketTester is Tester {
    SimpleMarket market;
    function bindMarket(SimpleMarket _market) {
        _target(_market);
        market = SimpleMarket(_t);
    }
    function doApprove(address spender, uint value, ERC20 token) {
        token.approve(spender, value);
    }
    function doBuy(uint id) returns (bool _success) {
        return market.buy(id);
    }
    function doBuyPartial(uint id, uint buy_how_much) returns (bool _success) {
        return market.buyPartial(id, buy_how_much);
    }
}

contract SimpleMarketTest is Test, EventfulMarket {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    SimpleMarket otc;
    function setUp() {
        otc = new SimpleMarket();
        user1 = new MarketTester();
        user1.bindMarket(otc);

        dai = new ERC20Base(10 ** 9);
        mkr = new ERC20Base(10 ** 6);

        mkr.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);
    }
    function testBasicTrade() {
        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        var id = otc.offer( 30, mkr, 100, dai );
        assertTrue(user1.doBuy(id));
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        assertEq( 30, my_mkr_balance_before - my_mkr_balance_after );
        assertEq( 100, my_dai_balance_after - my_dai_balance_before );
        assertEq( 30, user1_mkr_balance_after - user1_mkr_balance_before );
        assertEq( 100, user1_dai_balance_before - user1_dai_balance_after );

        expectEventsExact(otc);
        ItemUpdate(id);
        Trade( 30, mkr, 100, dai );
        ItemUpdate(id);
    }
    function testPartiallyFilledOrderMkr() {
        dai.transfer(user1, 30);
        user1.doApprove(otc, 30, dai);
        mkr.approve(otc, 200);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        var id = otc.offer( 200, mkr, 500, dai );
        assertTrue(user1.doBuyPartial(id, 10));
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(id);

        assertEq( 200, my_mkr_balance_before - my_mkr_balance_after );
        assertEq( 25, my_dai_balance_after - my_dai_balance_before );
        assertEq( 10, user1_mkr_balance_after - user1_mkr_balance_before );
        assertEq( 25, user1_dai_balance_before - user1_dai_balance_after );
        assertEq( 190, sell_val );
        assertEq( 475, buy_val );

        expectEventsExact(otc);
        ItemUpdate(id);
        Trade( 10, mkr, 25, dai );
        ItemUpdate(id);
    }
    function testPartiallyFilledOrderDai() {
        mkr.transfer(user1, 10);
        user1.doApprove(otc, 10, mkr);
        dai.approve(otc, 500);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        var id = otc.offer( 500, dai, 200, mkr );
        assertTrue(user1.doBuyPartial(id, 10));
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(id);

        assertEq( 500, my_dai_balance_before - my_dai_balance_after );
        assertEq( 4, my_mkr_balance_after - my_mkr_balance_before );
        assertEq( 10, user1_dai_balance_after - user1_dai_balance_before );
        assertEq( 4, user1_mkr_balance_before - user1_mkr_balance_after );
        assertEq( 490, sell_val );
        assertEq( 196, buy_val );

        expectEventsExact(otc);
        ItemUpdate(id);
        Trade( 10, dai, 4, mkr );
        ItemUpdate(id);
    }
    function testPartiallyFilledOrderMkrExcessQuantity() {
        dai.transfer(user1, 30);
        user1.doApprove(otc, 30, dai);
        mkr.approve(otc, 200);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        var id = otc.offer( 200, mkr, 500, dai );
        assertFalse(user1.doBuyPartial(id, 201));

        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(id);

        assertEq( 0, my_dai_balance_before - my_dai_balance_after );
        assertEq( 200, my_mkr_balance_before - my_mkr_balance_after );
        assertEq( 0, user1_dai_balance_before - user1_dai_balance_after );
        assertEq( 0, user1_mkr_balance_before - user1_mkr_balance_after );
        assertEq( 200, sell_val );
        assertEq( 500, buy_val );

        expectEventsExact(otc);
        ItemUpdate(id);
    }
    function testCancel() {
        mkr.approve(otc, 30);
        var id = otc.offer( 30, mkr, 100, dai );
        assertTrue(otc.cancel(id));

        expectEventsExact(otc);
        ItemUpdate(id);
        ItemUpdate(id);
    }

    function testFailOfferNotEnoughFunds() {
        mkr.transfer(address(0x0), mkr.balanceOf(this) - 29);
        var id = otc.offer(30, mkr, 100, dai);
    }
    function testFailBuyNotEnoughFunds() {
        var id = otc.offer(30, mkr, 101, dai);
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        user1.doApprove(otc, 101, dai);
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        log_named_uint("user1 dai balance before", dai.balanceOf(user1));
        assertTrue(user1.doBuy(id));
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        log_named_uint("user1 dai balance after", dai.balanceOf(user1));
    }
    function testFailBuyNotEnoughApproval() {
        var id = otc.offer(30, mkr, 100, dai);
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        user1.doApprove(otc, 99, dai);
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        log_named_uint("user1 dai balance before", dai.balanceOf(user1));
        assertTrue(user1.doBuy(id));
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        log_named_uint("user1 dai balance after", dai.balanceOf(user1));
    }
}
