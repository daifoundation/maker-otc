pragma solidity ^0.4.8;

import "ds-test/test.sol";
import "ds-token/base.sol";

import "./expiring_market.sol";
import "./simple_market_test.sol";

contract TestableExpiringMarket is ExpiringMarket(1 weeks) {
    uint public time;
    function getTime() constant returns (uint) {
        return time;
    }
    function addTime(uint extra) {
        time += extra;
    }
}

// Test expiring market retains behaviour of simple market
contract ExpiringSimpleMarketTest is SimpleMarketTest {
    function setUp() {
        otc = new TestableExpiringMarket();
        user1 = new MarketTester(otc);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);
    }
}

// Expiry specific tests
contract ExpiringMarketTest is DSTest {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    TestableExpiringMarket otc;
    bool buy_enabled;
    function setUp() {
        otc = new TestableExpiringMarket();
        user1 = new MarketTester(otc);
        buy_enabled = otc.isBuyEnabled();
        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);
    }
    function testIsClosedBeforeExpiry() {
        assert(!otc.isClosed());
    }
    function testIsClosedAfterExpiry() {
        otc.addTime(ExpiringMarket(otc).lifetime() + 1 seconds);
        assert(otc.isClosed());
    }
    function testOfferBeforeExpiry() {
        otc.offer( 30, mkr, 100, dai );
    }
    function testFailOfferAfterExpiry() {
        otc.addTime(ExpiringMarket(otc).lifetime() + 1 seconds);
        otc.offer( 30, mkr, 100, dai );
    }
    function testCancelBeforeExpiry() {
        var id = otc.offer( 30, mkr, 100, dai );
        otc.cancel(id);
    }
    function testFailCancelNonOwnerBeforeExpiry() {
        var id = otc.offer( 30, mkr, 100, dai );
        user1.doCancel(id);
    }
    function testCancelNonOwnerAfterExpiry() {
        var id = otc.offer( 30, mkr, 100, dai );
        otc.addTime(otc.lifetime() + 1 seconds);

        assert(otc.isActive(id));
        assert(user1.doCancel(id));
        assert(!otc.isActive(id));
    }
    function testBuyBeforeExpiry() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );
            assert(user1.doBuy(id, 30));
        }
    }
    function testFailBuyAfterExpiry() {
        var id = otc.offer( 30, mkr, 100, dai );
        otc.addTime(otc.lifetime() + 1 seconds);
        user1.doBuy(id, 30);
    }
}

contract ExpiringTransferTest is TransferTest {
    function setUp() {
        otc = new TestableExpiringMarket();
        user1 = new MarketTester(otc);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);
    }
}

contract ExpiringOfferTransferTest is OfferTransferTest, ExpiringTransferTest {}
contract ExpiringBuyTransferTest is BuyTransferTest, ExpiringTransferTest {}
contract ExpiringPartialBuyTransferTest is PartialBuyTransferTest, ExpiringTransferTest {}

contract ExpiringCancelTransferTest is CancelTransferTest
                                     , ExpiringTransferTest
{
    function testCancelAfterExpiryTransfersFromMarket() {
        var id = otc.offer( 30, mkr, 100, dai );
        TestableExpiringMarket(otc).addTime(
            ExpiringMarket(otc).lifetime() + 1 seconds
        );

        var balance_before = mkr.balanceOf(otc);
        otc.cancel(id);
        var balance_after = mkr.balanceOf(otc);

        assertEq(balance_before - balance_after, 30);
    }
    function testCancelAfterExpiryTransfersToSeller() {
        var id = otc.offer( 30, mkr, 100, dai );
        TestableExpiringMarket(otc).addTime(
            ExpiringMarket(otc).lifetime() + 1 seconds
        );

        var balance_before = mkr.balanceOf(this);
        user1.doCancel(id);
        var balance_after = mkr.balanceOf(this);

        assertEq(balance_after - balance_before, 30);
    }
}
