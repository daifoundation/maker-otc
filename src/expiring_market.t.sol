pragma solidity ^0.5.12;

import "ds-test/test.sol";
import "ds-token/base.sol";

import "./expiring_market.sol";
import "./simple_market.t.sol";

contract WarpingExpiringMarket is ExpiringMarket {
    uint64 _now;

    constructor(uint64 close_time) ExpiringMarket(close_time) public {
        _now = uint64(now);
    }

    function warp(uint64 w) public {
        _now += w;
    }

    function getTime() public view returns (uint64) {
        return _now;
    }
}

// Test expiring market retains behaviour of simple market
contract ExpiringSimpleMarketTest is SimpleMarketTest {
    function setUp() public {
        otc = new WarpingExpiringMarket(uint64(now) + 1 weeks);
        user1 = new MarketTester(otc);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        dai.transfer(address(user1), 100);
        user1.doApprove(address(otc), 100, dai);
        mkr.approve(address(otc), 30);
    }
}

// Expiry specific tests
contract ExpiringMarketTest is DSTest {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    WarpingExpiringMarket otc;
    uint64 constant LIFETIME = 1 weeks;

    function setUp() public {
        otc = new WarpingExpiringMarket(uint64(now) + LIFETIME);
        user1 = new MarketTester(otc);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        dai.transfer(address(user1), 100);
        user1.doApprove(address(otc), 100, dai);
        mkr.approve(address(otc), 30);
    }
    function testIsClosedBeforeExpiry() public view {
        assert(!otc.isClosed());
    }
    function testIsClosedAfterExpiry() public {
        otc.warp(LIFETIME + 1 seconds);
        assert(otc.isClosed());
    }
    function testOfferBeforeExpiry() public {
        otc.offer(30, mkr, 100, dai);
    }
    function testFailOfferAfterExpiry() public {
        otc.warp(LIFETIME + 1 seconds);
        otc.offer(30, mkr, 100, dai);
    }
    function testCancelBeforeExpiry() public {
        uint256 id = otc.offer(30, mkr, 100, dai);
        otc.cancel(id);
    }
    function testFailCancelNonOwnerBeforeExpiry() public {
        uint256 id = otc.offer(30, mkr, 100, dai);
        user1.doCancel(id);
    }
    function testCancelNonOwnerAfterExpiry() public {
        uint256 id = otc.offer(30, mkr, 100, dai);
        otc.warp(LIFETIME + 1 seconds);

        assert(otc.isActive(id));
        assert(user1.doCancel(id));
        assert(!otc.isActive(id));
    }
    function testBuyBeforeExpiry() public {
        uint256 id = otc.offer(30, mkr, 100, dai);
        assert(user1.doBuy(id, 30));
    }
    function testFailBuyAfterExpiry() public {
        uint256 id = otc.offer(30, mkr, 100, dai);
        otc.warp(LIFETIME + 1 seconds);
        user1.doBuy(id, 30);
    }
}

contract ExpiringTransferTest is TransferTest {
    function setUp() public {
        otc = new WarpingExpiringMarket(uint64(now) + 1 weeks);
        user1 = new MarketTester(otc);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        dai.transfer(address(user1), 100);
        user1.doApprove(address(otc), 100, dai);
        mkr.approve(address(otc), 30);
    }
}

contract ExpiringOfferTransferTest is OfferTransferTest, ExpiringTransferTest {}
contract ExpiringBuyTransferTest is BuyTransferTest, ExpiringTransferTest {}
contract ExpiringPartialBuyTransferTest is PartialBuyTransferTest, ExpiringTransferTest {}

contract ExpiringCancelTransferTest is CancelTransferTest
                                     , ExpiringTransferTest
{
    uint64 constant LIFETIME = 1 weeks;

    function testCancelAfterExpiryTransfersFromMarket() public {
        uint256 id = otc.offer(30, mkr, 100, dai);
        WarpingExpiringMarket(address(otc)).warp(LIFETIME + 1 seconds);

        uint256 balance_before = mkr.balanceOf(address(otc));
        otc.cancel(id);
        uint256 balance_after = mkr.balanceOf(address(otc));

        assertEq(balance_before - balance_after, 30);
    }
    function testCancelAfterExpiryTransfersToSeller() public {
        uint256 id = otc.offer(30, mkr, 100, dai);
        WarpingExpiringMarket(address(otc)).warp(LIFETIME + 1 seconds);

        uint256 balance_before = mkr.balanceOf(address(this));
        user1.doCancel(id);
        uint256 balance_after = mkr.balanceOf(address(this));

        assertEq(balance_after - balance_before, 30);
    }
}
