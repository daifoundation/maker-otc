pragma solidity ^0.4.18;

import "ds-test/test.sol";
import "ds-token/base.sol";

import "./simple_market.sol";

contract MarketTester {
    SimpleMarket market;
    function MarketTester(SimpleMarket market_) public {
        market = market_;
    }
    function doApprove(address spender, uint value, ERC20 token) public {
        token.approve(spender, value);
    }
    function doOffer(uint pay_amt, ERC20 pay_gem,
                    uint buy_amt,  ERC20 buy_gem)
        public
        returns (uint)
    {
        return market.offer(pay_amt, pay_gem,
                  buy_amt, buy_gem);
    }
    function doBuy(uint id, uint buy_how_much) public returns (bool _success) {
        return market.buy(id, buy_how_much);
    }
    function doCancel(uint id) public returns (bool _success) {
        return market.cancel(id);
    }
}

contract SimpleMarketTest is DSTest, EventfulMarket {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    SimpleMarket otc;
    function setUp() public {
        otc = new SimpleMarket();
        user1 = new MarketTester(otc);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);
    }
    function testOriginalPayAndBuySet() public {
        uint o_pay_amt;
        uint o_buy_amt;
        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        uint id0 = user1.doOffer(100, dai, 100, mkr);
        (o_pay_amt,o_buy_amt,,,,)=otc.getOfferAll(id0);
        assert( o_pay_amt == 100 );
        assert( o_buy_amt == 100 );
    }
    function testOriginalPayAndBuyUnchanged() public {
        uint o_pay_amt;
        uint o_buy_amt;
        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 10);
        uint id0 = user1.doOffer(100, dai, 100, mkr);
        otc.offer(10, mkr, 10, dai);
        (o_pay_amt,o_buy_amt,,,,)=otc.getOfferAll(id0);
        assert( o_pay_amt == 100 );
        assert( o_buy_amt == 100 );
    }

    function testBasicTrade() public {
        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        var id = otc.offer(30, mkr, 100, dai);
        assert(user1.doBuy(id, 30));
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        assertEq(30, my_mkr_balance_before - my_mkr_balance_after);
        assertEq(100, my_dai_balance_after - my_dai_balance_before);
        assertEq(30, user1_mkr_balance_after - user1_mkr_balance_before);
        assertEq(100, user1_dai_balance_before - user1_dai_balance_after);

        expectEventsExact(otc);
        LogItemUpdate(id);
        LogTrade(30, mkr, 100, dai);
        LogItemUpdate(id);
    }
    function testPartiallyFilledOrderMkr() public {
        dai.transfer(user1, 30);
        user1.doApprove(otc, 30, dai);
        mkr.approve(otc, 200);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        var id = otc.offer(200, mkr, 500, dai);
        assert(user1.doBuy(id, 10));
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        var (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(id);

        assertEq(200, my_mkr_balance_before - my_mkr_balance_after);
        assertEq(25, my_dai_balance_after - my_dai_balance_before);
        assertEq(10, user1_mkr_balance_after - user1_mkr_balance_before);
        assertEq(25, user1_dai_balance_before - user1_dai_balance_after);
        assertEq(190, sell_val);
        assertEq(475, buy_val);
        assert(address(sell_token) > 0x0);
        assert(address(buy_token) > 0x0);

        expectEventsExact(otc);
        LogItemUpdate(id);
        LogTrade(10, mkr, 25, dai);
        LogItemUpdate(id);
    }
    function testPartiallyFilledOrderDai() public {
        mkr.transfer(user1, 10);
        user1.doApprove(otc, 10, mkr);
        dai.approve(otc, 500);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        var id = otc.offer(500, dai, 200, mkr);
        assert(user1.doBuy(id, 10));
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        var (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(id);

        assertEq(500, my_dai_balance_before - my_dai_balance_after);
        assertEq(4, my_mkr_balance_after - my_mkr_balance_before);
        assertEq(10, user1_dai_balance_after - user1_dai_balance_before);
        assertEq(4, user1_mkr_balance_before - user1_mkr_balance_after);
        assertEq(490, sell_val);
        assertEq(196, buy_val);
        assert(address(sell_token) > 0x0);
        assert(address(buy_token) > 0x0);

        expectEventsExact(otc);
        LogItemUpdate(id);
        LogTrade(10, dai, 4, mkr);
        LogItemUpdate(id);
    }
    function testPartiallyFilledOrderMkrExcessQuantity() public {
        dai.transfer(user1, 30);
        user1.doApprove(otc, 30, dai);
        mkr.approve(otc, 200);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        var id = otc.offer(200, mkr, 500, dai);
        assert(!user1.doBuy(id, 201));

        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        var (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(id);

        assertEq(0, my_dai_balance_before - my_dai_balance_after);
        assertEq(200, my_mkr_balance_before - my_mkr_balance_after);
        assertEq(0, user1_dai_balance_before - user1_dai_balance_after);
        assertEq(0, user1_mkr_balance_before - user1_mkr_balance_after);
        assertEq(200, sell_val);
        assertEq(500, buy_val);
        assert(address(sell_token) > 0x0);
        assert(address(buy_token) > 0x0);

        expectEventsExact(otc);
        LogItemUpdate(id);
    }
    function testInsufficientlyFilledOrder() public {
        mkr.approve(otc, 30);
        var id = otc.offer(30, mkr, 10, dai);

        dai.transfer(user1, 1);
        user1.doApprove(otc, 1, dai);
        var success = user1.doBuy(id, 1);
        assert(!success);
    }
    function testCancel() public {
        mkr.approve(otc, 30);
        var id = otc.offer(30, mkr, 100, dai);
        assert(otc.cancel(id));

        expectEventsExact(otc);
        LogItemUpdate(id);
        LogItemUpdate(id);
    }
    function testFailCancelNotOwner() public {
        mkr.approve(otc, 30);
        var id = otc.offer(30, mkr, 100, dai);
        user1.doCancel(id);
    }
    function testFailCancelInactive() public {
        mkr.approve(otc, 30);
        var id = otc.offer(30, mkr, 100, dai);
        assert(otc.cancel(id));
        otc.cancel(id);
    }
    function testFailBuyInactive() public {
        mkr.approve(otc, 30);
        var id = otc.offer(30, mkr, 100, dai);
        assert(otc.cancel(id));
        otc.buy(id, 0);
    }
    function testFailOfferNotEnoughFunds() public {
        mkr.transfer(address(0x0), mkr.balanceOf(this) - 29);
        var id = otc.offer(30, mkr, 100, dai);
        assert(id >= 0);     //ugly hack to stop compiler from throwing a warning for unused var id
    }
    function testFailBuyNotEnoughFunds() public {
        var id = otc.offer(30, mkr, 101, dai);
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        user1.doApprove(otc, 101, dai);
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        log_named_uint("user1 dai balance before", dai.balanceOf(user1));
        assert(user1.doBuy(id, 101));
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        log_named_uint("user1 dai balance after", dai.balanceOf(user1));
    }
    function testFailBuyNotEnoughApproval() public {
        var id = otc.offer(30, mkr, 100, dai);
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        user1.doApprove(otc, 99, dai);
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        log_named_uint("user1 dai balance before", dai.balanceOf(user1));
        assert(user1.doBuy(id, 100));
        log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        log_named_uint("user1 dai balance after", dai.balanceOf(user1));
    }
    function testFailOfferSameToken() public {
        dai.approve(otc, 200);
        otc.offer(100, dai, 100, dai);
    }
    function testBuyTooMuch() public {
        mkr.approve(otc, 30);
        var id = otc.offer(30, mkr, 100, dai);
        assert(!otc.buy(id, 50));
    }
    function testFailOverflow() public {
        mkr.approve(otc, 30);
        var id = otc.offer(30, mkr, 100, dai);
        // this should throw because of safeMul being used.
        // other buy failures will return false
        otc.buy(id, uint(-1));
    }
}

contract TransferTest is DSTest {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    SimpleMarket otc;
    function setUp() public {
        otc = new SimpleMarket();
        user1 = new MarketTester(otc);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);
    }
}

contract OfferTransferTest is TransferTest {
    function testOfferTransfersFromSeller() public {
        var balance_before = mkr.balanceOf(this);
        var id = otc.offer(30, mkr, 100, dai);
        var balance_after = mkr.balanceOf(this);

        assertEq(balance_before - balance_after, 30);
        assert(id > 0);
    }
    function testOfferTransfersToMarket() public {
        var balance_before = mkr.balanceOf(otc);
        var id = otc.offer(30, mkr, 100, dai);
        var balance_after = mkr.balanceOf(otc);

        assertEq(balance_after - balance_before, 30);
        assert(id > 0);
    }
}

contract BuyTransferTest is TransferTest {
    function testBuyTransfersFromBuyer() public {
        var id = otc.offer(30, mkr, 100, dai);

        var balance_before = dai.balanceOf(user1);
        user1.doBuy(id, 30);
        var balance_after = dai.balanceOf(user1);

        assertEq(balance_before - balance_after, 100);
    }
    function testBuyTransfersToSeller() public {
        var id = otc.offer(30, mkr, 100, dai);

        var balance_before = dai.balanceOf(this);
        user1.doBuy(id, 30);
        var balance_after = dai.balanceOf(this);

        assertEq(balance_after - balance_before, 100);
    }
    function testBuyTransfersFromMarket() public {
        var id = otc.offer(30, mkr, 100, dai);

        var balance_before = mkr.balanceOf(otc);
        user1.doBuy(id, 30);
        var balance_after = mkr.balanceOf(otc);

        assertEq(balance_before - balance_after, 30);
    }
    function testBuyTransfersToBuyer() public {
        var id = otc.offer(30, mkr, 100, dai);

        var balance_before = mkr.balanceOf(user1);
        user1.doBuy(id, 30);
        var balance_after = mkr.balanceOf(user1);

        assertEq(balance_after - balance_before, 30);
    }
}

contract PartialBuyTransferTest is TransferTest {
    function testBuyTransfersFromBuyer() public {
        var id = otc.offer(30, mkr, 100, dai);

        var balance_before = dai.balanceOf(user1);
        user1.doBuy(id, 15);
        var balance_after = dai.balanceOf(user1);

        assertEq(balance_before - balance_after, 50);
    }
    function testBuyTransfersToSeller() public {
        var id = otc.offer(30, mkr, 100, dai);

        var balance_before = dai.balanceOf(this);
        user1.doBuy(id, 15);
        var balance_after = dai.balanceOf(this);

        assertEq(balance_after - balance_before, 50);
    }
    function testBuyTransfersFromMarket() public {
        var id = otc.offer(30, mkr, 100, dai);

        var balance_before = mkr.balanceOf(otc);
        user1.doBuy(id, 15);
        var balance_after = mkr.balanceOf(otc);

        assertEq(balance_before - balance_after, 15);
    }
    function testBuyTransfersToBuyer() public {
        var id = otc.offer(30, mkr, 100, dai);

        var balance_before = mkr.balanceOf(user1);
        user1.doBuy(id, 15);
        var balance_after = mkr.balanceOf(user1);

        assertEq(balance_after - balance_before, 15);
    }
    function testBuyOddTransfersFromBuyer() public {
        var id = otc.offer(30, mkr, 100, dai);

        var balance_before = dai.balanceOf(user1);
        user1.doBuy(id, 17);
        var balance_after = dai.balanceOf(user1);

        assertEq(balance_before - balance_after, 56);
    }
}

contract CancelTransferTest is TransferTest {
    function testCancelTransfersFromMarket() public {
        var id = otc.offer(30, mkr, 100, dai);

        var balance_before = mkr.balanceOf(otc);
        otc.cancel(id);
        var balance_after = mkr.balanceOf(otc);

        assertEq(balance_before - balance_after, 30);
    }
    function testCancelTransfersToSeller() public {
        var id = otc.offer(30, mkr, 100, dai);

        var balance_before = mkr.balanceOf(this);
        otc.cancel(id);
        var balance_after = mkr.balanceOf(this);

        assertEq(balance_after - balance_before, 30);
    }
    function testCancelPartialTransfersFromMarket() public {
        var id = otc.offer(30, mkr, 100, dai);
        user1.doBuy(id, 15);

        var balance_before = mkr.balanceOf(otc);
        otc.cancel(id);
        var balance_after = mkr.balanceOf(otc);

        assertEq(balance_before - balance_after, 15);
    }
    function testCancelPartialTransfersToSeller() public {
        var id = otc.offer(30, mkr, 100, dai);
        user1.doBuy(id, 15);

        var balance_before = mkr.balanceOf(this);
        otc.cancel(id);
        var balance_after = mkr.balanceOf(this);

        assertEq(balance_after - balance_before, 15);
    }
}

contract GasTest is DSTest {
    ERC20 dai;
    ERC20 mkr;
    SimpleMarket otc;
    uint id;

    function setUp() public {
        otc = new SimpleMarket();

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        mkr.approve(otc, 60);
        dai.approve(otc, 100);

        id = otc.offer(30, mkr, 100, dai);
    }
    function testNewMarket()
        public
        logs_gas
    {
        new SimpleMarket();
    }
    function testNewOffer()
        public
        logs_gas
    {
        otc.offer(30, mkr, 100, dai);
    }
    function testBuy()
        public
        logs_gas
    {
        otc.buy(id, 30);
    }
    function testBuyPartial()
        public
        logs_gas
    {
        otc.buy(id, 15);
    }
    function testCancel()
        public
        logs_gas
    {
        otc.cancel(id);
    }
}
