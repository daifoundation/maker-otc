pragma solidity ^0.4.24;

import "ds-test/test.sol";
import "ds-token/base.sol";

import "./simple_market.sol";

contract MarketTester {
    SimpleMarket market;
    constructor(SimpleMarket market_) public {
        market = market_;
    }
    function doApprove(address spender, uint value, ERC20 token) public {
        token.approve(spender, value);
    }
    function doOffer(uint sellAmt, ERC20 sellGem, uint buyAmt,  ERC20 buyGem)
        public
        returns (uint)
    {
        return market.offer(sellAmt, sellGem, buyAmt, buyGem);
    }
    function doBuy(uint id, uint buyHowMuch) public returns (bool success) {
        return market.buy(id, buyHowMuch);
    }
    function doCancel(uint id) public returns (bool success) {
        return market.cancel(id);
    }
}

contract SimpleMarketTest is DSTest, EventfulMarket {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    SimpleMarket otc;
    uint sellAmt;
    uint buyAmt;
    ERC20 sellGem;
    ERC20 buyGem;

    function setUp() public {
        otc = new SimpleMarket();
        user1 = new MarketTester(otc);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);
    }

    function testOriginalPayAndBuySet() public {
        uint oSellAmt;
        uint oBuyAmt;
        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        uint id0 = user1.doOffer(100, dai, 100, mkr);
        (oSellAmt, oBuyAmt,,,,,,) = otc.offers(id0);
        assert(oSellAmt == 100);
        assert(oBuyAmt == 100);
    }

    function testOriginalPayAndBuyUnchanged() public {
        uint oSellAmt;
        uint oBuyAmt;
        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 10);
        uint id0 = user1.doOffer(100, dai, 100, mkr);
        otc.offer(10, mkr, 10, dai);
        (oSellAmt, oBuyAmt,,,,,,) = otc.offers(id0);
        assert(oSellAmt == 100);
        assert(oBuyAmt == 100);
    }

    function testBasicTrade() public {
        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);

        uint myMKRBalanceBefore = mkr.balanceOf(this);
        uint myDAIBalanceBefore = dai.balanceOf(this);
        uint user1MKRBalanceBefore = mkr.balanceOf(user1);
        uint user1DAIBalanceBefore = dai.balanceOf(user1);

        uint id = otc.offer(30, mkr, 100, dai);
        assert(user1.doBuy(id, 30));
        uint myMKRBalanceAfter = mkr.balanceOf(this);
        uint myDAIBalanceAfter = dai.balanceOf(this);
        uint user1MKRbalanceAfter = mkr.balanceOf(user1);
        uint user1DAIbalanceAfter = dai.balanceOf(user1);
        assertEq(30, myMKRBalanceBefore - myMKRBalanceAfter);
        assertEq(100, myDAIBalanceAfter - myDAIBalanceBefore);
        assertEq(30, user1MKRbalanceAfter - user1MKRBalanceBefore);
        assertEq(100, user1DAIBalanceBefore - user1DAIbalanceAfter);
    }

    function testPartiallyFilledOrderMkr() public {
        dai.transfer(user1, 30);
        user1.doApprove(otc, 30, dai);
        mkr.approve(otc, 200);

        uint myMKRBalanceBefore = mkr.balanceOf(this);
        uint myDAIBalanceBefore = dai.balanceOf(this);
        uint user1MKRBalanceBefore = mkr.balanceOf(user1);
        uint user1DAIBalanceBefore = dai.balanceOf(user1);

        uint id = otc.offer(200, mkr, 500, dai);
        assert(user1.doBuy(id, 10));
        uint myMKRBalanceAfter = mkr.balanceOf(this);
        uint myDAIBalanceAfter = dai.balanceOf(this);
        uint user1MKRbalanceAfter = mkr.balanceOf(user1);
        uint user1DAIbalanceAfter = dai.balanceOf(user1);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(id);

        assertEq(200, myMKRBalanceBefore - myMKRBalanceAfter);
        assertEq(25, myDAIBalanceAfter - myDAIBalanceBefore);
        assertEq(10, user1MKRbalanceAfter - user1MKRBalanceBefore);
        assertEq(25, user1DAIBalanceBefore - user1DAIbalanceAfter);
        assertEq(190, sellAmt);
        assertEq(475, buyAmt);
        assert(address(sellGem) > 0x0);
        assert(address(buyGem) > 0x0);
    }

    function testPartiallyFilledOrderDai() public {
        mkr.transfer(user1, 10);
        user1.doApprove(otc, 10, mkr);
        dai.approve(otc, 500);

        uint myMKRBalanceBefore = mkr.balanceOf(this);
        uint myDAIBalanceBefore = dai.balanceOf(this);
        uint user1MKRBalanceBefore = mkr.balanceOf(user1);
        uint user1DAIBalanceBefore = dai.balanceOf(user1);

        uint id = otc.offer(500, dai, 200, mkr);
        assert(user1.doBuy(id, 10));
        uint myMKRBalanceAfter = mkr.balanceOf(this);
        uint myDAIBalanceAfter = dai.balanceOf(this);
        uint user1MKRbalanceAfter = mkr.balanceOf(user1);
        uint user1DAIbalanceAfter = dai.balanceOf(user1);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(id);

        assertEq(500, myDAIBalanceBefore - myDAIBalanceAfter);
        assertEq(4, myMKRBalanceAfter - myMKRBalanceBefore);
        assertEq(10, user1DAIbalanceAfter - user1DAIBalanceBefore);
        assertEq(4, user1MKRBalanceBefore - user1MKRbalanceAfter);
        assertEq(490, sellAmt);
        assertEq(196, buyAmt);
        assert(address(sellGem) > 0x0);
        assert(address(buyGem) > 0x0);
    }

    function testPartiallyFilledOrderMkrExcessQuantity() public {
        dai.transfer(user1, 30);
        user1.doApprove(otc, 30, dai);
        mkr.approve(otc, 200);

        uint myMKRBalanceBefore = mkr.balanceOf(this);
        uint myDAIBalanceBefore = dai.balanceOf(this);
        uint user1MKRBalanceBefore = mkr.balanceOf(user1);
        uint user1DAIBalanceBefore = dai.balanceOf(user1);

        uint id = otc.offer(200, mkr, 500, dai);
        assert(!user1.doBuy(id, 201));

        uint myMKRBalanceAfter = mkr.balanceOf(this);
        uint myDAIBalanceAfter = dai.balanceOf(this);
        uint user1MKRbalanceAfter = mkr.balanceOf(user1);
        uint user1DAIbalanceAfter = dai.balanceOf(user1);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(id);

        assertEq(0, myDAIBalanceBefore - myDAIBalanceAfter);
        assertEq(200, myMKRBalanceBefore - myMKRBalanceAfter);
        assertEq(0, user1DAIBalanceBefore - user1DAIbalanceAfter);
        assertEq(0, user1MKRBalanceBefore - user1MKRbalanceAfter);
        assertEq(200, sellAmt);
        assertEq(500, buyAmt);
        assert(address(sellGem) > 0x0);
        assert(address(buyGem) > 0x0);
    }

    function testInsufficientlyFilledOrder() public {
        mkr.approve(otc, 30);
        uint id = otc.offer(30, mkr, 10, dai);

        dai.transfer(user1, 1);
        user1.doApprove(otc, 1, dai);
        bool success = user1.doBuy(id, 1);
        assert(!success);
    }

    function testCancel() public {
        mkr.approve(otc, 30);
        uint id = otc.offer(30, mkr, 100, dai);
        assert(otc.cancel(id));

        expectEventsExact(otc);
    }

    function testFailCancelNotOwner() public {
        mkr.approve(otc, 30);
        uint id = otc.offer(30, mkr, 100, dai);
        user1.doCancel(id);
    }

    function testFailCancelInactive() public {
        mkr.approve(otc, 30);
        uint id = otc.offer(30, mkr, 100, dai);
        assert(otc.cancel(id));
        otc.cancel(id);
    }

    function testFailBuyInactive() public {
        mkr.approve(otc, 30);
        uint id = otc.offer(30, mkr, 100, dai);
        assert(otc.cancel(id));
        otc.buy(id, 0);
    }

    function testFailOfferNotEnoughFunds() public {
        mkr.transfer(address(0x0), mkr.balanceOf(this) - 29);
        otc.offer(30, mkr, 100, dai);
    }

    function testFailBuyNotEnoughFunds() public {
        uint id = otc.offer(30, mkr, 101, dai);
        emit log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        user1.doApprove(otc, 101, dai);
        emit log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        emit log_named_uint("user1 dai balance before", dai.balanceOf(user1));
        assert(user1.doBuy(id, 101));
        emit log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        emit log_named_uint("user1 dai balance after", dai.balanceOf(user1));
    }

    function testFailBuyNotEnoughApproval() public {
        uint id = otc.offer(30, mkr, 100, dai);
        emit log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        user1.doApprove(otc, 99, dai);
        emit log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        emit log_named_uint("user1 dai balance before", dai.balanceOf(user1));
        assert(user1.doBuy(id, 100));
        emit log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
        emit log_named_uint("user1 dai balance after", dai.balanceOf(user1));
    }

    function testFailOfferSameToken() public {
        dai.approve(otc, 200);
        otc.offer(100, dai, 100, dai);
    }

    function testBuyTooMuch() public {
        mkr.approve(otc, 30);
        uint id = otc.offer(30, mkr, 100, dai);
        assert(!otc.buy(id, 50));
    }

    function testFailOverflow() public {
        mkr.approve(otc, 30);
        uint id = otc.offer(30, mkr, 100, dai);
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
        uint balanceBefore = mkr.balanceOf(this);
        uint id = otc.offer(30, mkr, 100, dai);
        uint balanceAfter = mkr.balanceOf(this);

        assertEq(balanceBefore - balanceAfter, 30);
        assert(id > 0);
    }

    function testOfferTransfersToMarket() public {
        uint balanceBefore = mkr.balanceOf(otc);
        uint id = otc.offer(30, mkr, 100, dai);
        uint balanceAfter = mkr.balanceOf(otc);

        assertEq(balanceAfter - balanceBefore, 30);
        assert(id > 0);
    }

    function testOfferOtherOwner() public {
        assertEq(dai.balanceOf(address(123)), 0);
        uint id = otc.offer(30, mkr, 100, dai, address(123));
        (,,,,,, address owner,) = otc.offers(id);
        assertEq(owner, address(123));
        dai.approve(otc, uint(-1));
        otc.buy(id, 30);
        assertEq(dai.balanceOf(address(123)), 100);
    }
}

contract BuyTransferTest is TransferTest {
    function testBuyTransfersFromBuyer() public {
        uint id = otc.offer(30, mkr, 100, dai);

        uint balanceBefore = dai.balanceOf(user1);
        user1.doBuy(id, 30);
        uint balanceAfter = dai.balanceOf(user1);

        assertEq(balanceBefore - balanceAfter, 100);
    }

    function testBuyTransfersToSeller() public {
        uint id = otc.offer(30, mkr, 100, dai);

        uint balanceBefore = dai.balanceOf(this);
        user1.doBuy(id, 30);
        uint balanceAfter = dai.balanceOf(this);

        assertEq(balanceAfter - balanceBefore, 100);
    }

    function testBuyTransfersFromMarket() public {
        uint id = otc.offer(30, mkr, 100, dai);

        uint balanceBefore = mkr.balanceOf(otc);
        user1.doBuy(id, 30);
        uint balanceAfter = mkr.balanceOf(otc);

        assertEq(balanceBefore - balanceAfter, 30);
    }

    function testBuyTransfersToBuyer() public {
        uint id = otc.offer(30, mkr, 100, dai);

        uint balanceBefore = mkr.balanceOf(user1);
        user1.doBuy(id, 30);
        uint balanceAfter = mkr.balanceOf(user1);

        assertEq(balanceAfter - balanceBefore, 30);
    }
}

contract PartialBuyTransferTest is TransferTest {
    function testBuyTransfersFromBuyer() public {
        uint id = otc.offer(30, mkr, 100, dai);

        uint balanceBefore = dai.balanceOf(user1);
        user1.doBuy(id, 15);
        uint balanceAfter = dai.balanceOf(user1);

        assertEq(balanceBefore - balanceAfter, 50);
    }

    function testBuyTransfersToSeller() public {
        uint id = otc.offer(30, mkr, 100, dai);

        uint balanceBefore = dai.balanceOf(this);
        user1.doBuy(id, 15);
        uint balanceAfter = dai.balanceOf(this);

        assertEq(balanceAfter - balanceBefore, 50);
    }

    function testBuyTransfersFromMarket() public {
        uint id = otc.offer(30, mkr, 100, dai);

        uint balanceBefore = mkr.balanceOf(otc);
        user1.doBuy(id, 15);
        uint balanceAfter = mkr.balanceOf(otc);

        assertEq(balanceBefore - balanceAfter, 15);
    }

    function testBuyTransfersToBuyer() public {
        uint id = otc.offer(30, mkr, 100, dai);

        uint balanceBefore = mkr.balanceOf(user1);
        user1.doBuy(id, 15);
        uint balanceAfter = mkr.balanceOf(user1);

        assertEq(balanceAfter - balanceBefore, 15);
    }

    function testBuyOddTransfersFromBuyer() public {
        uint id = otc.offer(30, mkr, 100, dai);

        uint balanceBefore = dai.balanceOf(user1);
        user1.doBuy(id, 17);
        uint balanceAfter = dai.balanceOf(user1);

        assertEq(balanceBefore - balanceAfter, 56);
    }
}

contract CancelTransferTest is TransferTest {
    function testCancelTransfersFromMarket() public {
        uint id = otc.offer(30, mkr, 100, dai);

        uint balanceBefore = mkr.balanceOf(otc);
        otc.cancel(id);
        uint balanceAfter = mkr.balanceOf(otc);

        assertEq(balanceBefore - balanceAfter, 30);
    }

    function testCancelTransfersToSeller() public {
        uint id = otc.offer(30, mkr, 100, dai);

        uint balanceBefore = mkr.balanceOf(this);
        otc.cancel(id);
        uint balanceAfter = mkr.balanceOf(this);

        assertEq(balanceAfter - balanceBefore, 30);
    }

    function testCancelPartialTransfersFromMarket() public {
        uint id = otc.offer(30, mkr, 100, dai);
        user1.doBuy(id, 15);

        uint balanceBefore = mkr.balanceOf(otc);
        otc.cancel(id);
        uint balanceAfter = mkr.balanceOf(otc);

        assertEq(balanceBefore - balanceAfter, 15);
    }

    function testCancelPartialTransfersToSeller() public {
        uint id = otc.offer(30, mkr, 100, dai);
        user1.doBuy(id, 15);

        uint balanceBefore = mkr.balanceOf(this);
        otc.cancel(id);
        uint balanceAfter = mkr.balanceOf(this);

        assertEq(balanceAfter - balanceBefore, 15);
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

    function testNewMarket() public logs_gas {
        new SimpleMarket();
    }

    function testNewOffer() public logs_gas {
        otc.offer(30, mkr, 100, dai);
    }

    function testBuy() public logs_gas {
        otc.buy(id, 30);
    }

    function testBuyPartial() public logs_gas {
        otc.buy(id, 15);
    }

    function testCancel() public logs_gas {
        otc.cancel(id);
    }
}
