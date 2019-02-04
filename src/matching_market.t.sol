pragma solidity ^0.4.18;

import "ds-test/test.sol";
import "ds-token/base.sol";

import "./matching_market.sol";

contract MarketTester {
    MatchingMarket market;
    function MarketTester(MatchingMarket  market_) public {
        market = market_;
    }
    function doGetFirstUnsortedOffer()
        public
        constant
        returns (uint)
    {
        return market.getFirstUnsortedOffer();
    }
    function doGetNextUnsortedOffer(uint mid)
        public
        constant
        returns (uint)
    {
        return market.getNextUnsortedOffer(mid);
    }
    function doSetMatchingEnabled(bool ema_)
        public
        returns (bool)
    {
        return market.setMatchingEnabled(ema_);
    }
    function doIsMatchingEnabled()
        public
        constant
        returns (bool)
    {
        return market.matchingEnabled();
    }
    function doSetBuyEnabled(bool ebu_)
        public
        returns (bool)
    {
        return market.setBuyEnabled(ebu_);
    }
    function doIsBuyEnabled()
        public
        constant
        returns (bool)
    {
        return market.buyEnabled();
    }
    function doSetMinSellAmount(ERC20 pay_gem, uint min_amount)
        public
        returns (bool)
    {
        return market.setMinSell(pay_gem, min_amount);
    }
    function doGetMinSellAmount(ERC20 pay_gem)
        public
        constant
        returns (uint)
    {
        return market.getMinSell(pay_gem);
    }
    function doApprove(address spender, uint value, ERC20 token) public {
        token.approve(spender, value);
    }
    function doBuy(uint id, uint buy_amt) public returns (bool _success) {
        return market.buy(id, buy_amt);
    }
    function doUnsortedOffer(uint pay_amt, ERC20 pay_gem,
                    uint buy_amt,  ERC20 buy_gem)
        public
        returns (uint)
    {
        return market.offer(pay_amt, pay_gem,
                    buy_amt, buy_gem);
    }
    function doOffer(uint pay_amt, ERC20 pay_gem,
                    uint buy_amt,  ERC20 buy_gem)
        public
        returns (uint)
    {
        return market.offer(pay_amt, pay_gem,
                  buy_amt, buy_gem, 0);
    }
    function doOffer(uint pay_amt, ERC20 pay_gem,
                    uint buy_amt,  ERC20 buy_gem,
                    uint pos)
        public
        returns (uint)
    {
        return market.offer(pay_amt, pay_gem,
                  buy_amt, buy_gem, pos);
    }
    function doOffer(uint pay_amt, ERC20 pay_gem,
                    uint buy_amt,  ERC20 buy_gem,
                    uint pos, bool rounding)
        public
        returns (uint)
    {
        return market.offer(pay_amt, pay_gem,
                  buy_amt, buy_gem, pos, rounding);
    }
    function doCancel(uint id) public returns (bool _success) {
        return market.cancel(id);
    }
    function getMarket()
        public
        constant
        returns (MatchingMarket)
    {
        return market;
    }
}
contract OrderMatchingGasTest is DSTest {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    ERC20 dgd;
    MatchingMarket otc;
    uint offer_count = 200;
    mapping( uint => uint ) offer;
    mapping( uint => uint ) dai_to_buy;
    mapping( uint => uint ) mkr_to_sell;
    uint [] match_count = [1,5,10,15,20,25,30,50,100];

    uint constant DAI_SUPPLY = (10 ** 9) * (10 ** 18);
    uint constant DGD_SUPPLY = (10 ** 9) * (10 ** 18);
    uint constant MKR_SUPPLY = (10 ** 9) * (10 ** 18);

    function setUp() public {
        otc = new MatchingMarket(uint64(now + 1 weeks));
        dai = new DSTokenBase(DAI_SUPPLY);
        mkr = new DSTokenBase(MKR_SUPPLY);
        dgd = new DSTokenBase(DGD_SUPPLY);
        user1 = new MarketTester(otc);
        dai.transfer(user1, (DAI_SUPPLY / 3) * 2);
        user1.doApprove(otc, DAI_SUPPLY / 3, dai );
        mkr.approve(otc, MKR_SUPPLY);
        dai.approve(otc, DAI_SUPPLY);
        //setup offers that will be matched later
        //determine how much dai, mkr must be bought and sold
        //to match a certain number(match_count) of offers
    }
    // non overflowing multiplication
    function safeMul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        assert(a == 0 || c / a == b);
    }
    function insertOffer(uint pay_amt, ERC20 pay_gem,
                         uint buy_amt, ERC20 buy_gem)
        public
        logs_gas
    {
        otc.offer(pay_amt, pay_gem,
                  buy_amt, buy_gem, 0);
    }
    //insert single offer
    function insertOffer(uint pay_amt, ERC20 pay_gem,
                         uint buy_amt, ERC20 buy_gem,
                         uint pos)
        public
        logs_gas
    {
        otc.offer(pay_amt, pay_gem,
                  buy_amt, buy_gem, pos);
    }
    //creates offer_count number of offers of increasing price
    function createOffers(uint offer_count_) public {
        for(uint offer_index = 0; offer_index < offer_count_; offer_index++) {
            offer[offer_index] = user1.doOffer(offer_index+1, dai, 1, mkr);
        }
    }
    // Creates test to match match_order_count number of orders
    function execOrderMatchingGasTest(uint match_order_count) public {
        uint mkr_sell;
        uint dai_buy;
        offer_count = match_order_count + 1;

        createOffers(offer_count);
        dai_buy =  safeMul(offer_count, offer_count + 1) / 2;
        mkr_sell = dai_buy;

        insertOffer(mkr_sell, mkr, dai_buy, dai);
        assertEq(otc.getOfferCount(dai,mkr), 0);
    }
    /*Test the gas usage of inserting one offer.
    Creates offer_index amount of offers of decreasing price then it
    logs the gas usage of inserting one additional offer. This
    function is useful to test the cost of sorting in order to do
    offer matching.*/
    function execOrderInsertGasTest(uint offer_index, uint kind) public {
        createOffers(offer_index + 1);
        if (kind == 0) {                  // no frontend aid
            insertOffer(1, dai, 1, mkr);
            assertEq(otc.getOfferCount(dai,mkr), offer_index + 2);
        } else if (kind == 1){            // with frontend aid
            insertOffer(1, dai, 1, mkr, 1);
            assertEq(otc.getOfferCount(dai,mkr), offer_index + 2);
        } else if (kind == 2){            // with frontend aid outdated pos new offer is better 
            user1.doCancel(2);
            insertOffer(2, dai, 1, mkr, 2);
            assertEq(otc.getOfferCount(dai,mkr), offer_index + 1);
        } else if (kind == 3){            // with frontend aid outdated pos new offer is worse
            user1.doCancel(3);
            insertOffer(2, dai, 1, mkr, 2);
            assertEq(otc.getOfferCount(dai,mkr), offer_index + 1);
        }    
    }
    function testGasMatchOneOrder() public {
        var match_order_count = match_count[0]; // 1
        execOrderMatchingGasTest(match_order_count);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMatchFiveOrders() public {
        var match_order_count = match_count[1]; // 5
        execOrderMatchingGasTest(match_order_count);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMatchTenOrders() public {
        var match_order_count = match_count[2]; // 10
        execOrderMatchingGasTest(match_order_count);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMatchFifteenOrders() public {
        var match_order_count = match_count[3]; // 15
        execOrderMatchingGasTest(match_order_count);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMatchTwentyOrders() public {
        var match_order_count = match_count[4]; // 20
        execOrderMatchingGasTest(match_order_count);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMatchTwentyfiveOrders() public {
        var match_order_count = match_count[5]; // 25
        execOrderMatchingGasTest(match_order_count);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMatchThirtyOrders() public {
        var match_order_count = match_count[6]; // 30
        execOrderMatchingGasTest(match_order_count);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMatchFiftyOrders() public {
        var match_order_count = match_count[7]; // 50
        execOrderMatchingGasTest(match_order_count);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMatchHundredOrders() public {
        var match_order_count = match_count[8]; // 100
        execOrderMatchingGasTest(match_order_count);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsFirstNoFrontendAid() public {
        uint offer_index = 1 - 1;
        execOrderInsertGasTest(offer_index, 0);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsFirstWithFrontendAid() public {
        uint offer_index = 1 - 1;
        execOrderInsertGasTest(offer_index, 1);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTenthNoFrontendAid() public {
        uint offer_index = 10 - 1;
        execOrderInsertGasTest(offer_index, 0);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTenthWithFrontendAid() public {
        uint offer_index = 10 - 1;
        execOrderInsertGasTest(offer_index, 1);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTenthWithFrontendAidOldPos() public {
        uint offer_index = 10 - 1;
        execOrderInsertGasTest(offer_index, 2);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTenthWithFrontendAidOldPosWorse() public {
        uint offer_index = 10 - 1;
        execOrderInsertGasTest(offer_index, 3);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTwentiethNoFrontendAid() public {
        uint offer_index = 20 - 1;
        execOrderInsertGasTest(offer_index, 0);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTwentiethWithFrontendAid() public {
        uint offer_index = 20 - 1;
        execOrderInsertGasTest(offer_index, 1);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTwentiethWithFrontendAidOldPos() public {
        uint offer_index = 20 - 1;
        execOrderInsertGasTest(offer_index, 2);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTwentiethWithFrontendAidOldPosWorse() public {
        uint offer_index = 20 - 1;
        execOrderInsertGasTest(offer_index, 3);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsFiftiethNoFrontendAid() public {
        uint offer_index = 50 - 1;
        execOrderInsertGasTest(offer_index, 0);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsFiftiethWithFrontendAid() public {
        uint offer_index = 50 - 1;
        execOrderInsertGasTest(offer_index, 1);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsFiftiethWithFrontendAidOldPos() public {
        uint offer_index = 50 - 1;
        execOrderInsertGasTest(offer_index, 2);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsFiftiethWithFrontendAidOldPosWorse() public {
        uint offer_index = 50 - 1;
        execOrderInsertGasTest(offer_index, 3);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsHundredthNoFrontendAid() public {
        uint offer_index = 100 - 1;
        execOrderInsertGasTest(offer_index, 0);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsHundredthWithFrontendAid() public {
        uint offer_index = 100 - 1;
        execOrderInsertGasTest(offer_index, 1);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsHundredthWithFrontendAidOldPos() public {
        uint offer_index = 100 - 1;
        execOrderInsertGasTest(offer_index, 2);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsHundredthWithFrontendAidOldPoWorses() public {
        uint offer_index = 100 - 1;
        execOrderInsertGasTest(offer_index, 3);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTwohundredthNoFrontendAid() public {
        uint offer_index = 200 -1;
        execOrderInsertGasTest(offer_index, 0);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTwohundredthWithFrontendAid() public {
        uint offer_index = 200 -1;
        execOrderInsertGasTest(offer_index, 1);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTwohundredthWithFrontendAidOldPos() public {
        uint offer_index = 200 -1;
        execOrderInsertGasTest(offer_index, 2);
// uncomment following line to run this test!
//        assert(false);
    }
    function testGasMakeOfferInsertAsTwohundredthWithFrontendAidOldPosWorse() public {
        uint offer_index = 200 -1;
        execOrderInsertGasTest(offer_index, 3);
// uncomment following line to run this test!
//        assert(false);
    }
}
contract OrderMatchingTest is DSTest, EventfulMarket, MatchingEvents {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    ERC20 dgd;
    MatchingMarket otc;
    mapping(uint => uint) offer_id;
    uint buy_val;
    uint sell_val;
    uint buy_val1;
    uint sell_val1;
    ERC20 sell_token;
    ERC20 buy_token;
    ERC20 sell_token1;
    ERC20 buy_token1;

    uint constant DAI_SUPPLY = (10 ** 9) * (10 ** 18);
    uint constant DGD_SUPPLY = (10 ** 9) * (10 ** 18);
    uint constant MKR_SUPPLY = (10 ** 9) * (10 ** 18);

    function setUp() public {
        dai = new DSTokenBase(DAI_SUPPLY);
        mkr = new DSTokenBase(MKR_SUPPLY);
        dgd = new DSTokenBase(DGD_SUPPLY);
        otc = new MatchingMarket(uint64(now + 1 weeks));
        user1 = new MarketTester(otc);
    }
    function testGetFirstNextUnsortedOfferOneOffer() public {
        mkr.approve(otc, 30);
        offer_id[1] = otc.offer(30, mkr, 100, dai);
        assertEq(otc.getFirstUnsortedOffer(), offer_id[1]);
        assertEq(otc.getNextUnsortedOffer(offer_id[1]), 0);
    }
    function testGetFirstUnsortedOfferOneOfferBought() public {
        mkr.approve(otc, 30);
        dai.transfer(user1, 100 );
        offer_id[1] = otc.offer(30, mkr, 100, dai);
        user1.doBuy(offer_id[1], 30);
        assertEq(otc.getFirstUnsortedOffer(), 0);
    }
    function testGetFirstNextUnsortedOfferThreeOffers() public {
        mkr.approve(otc, 90);
        offer_id[1] = otc.offer(30, mkr, 100, dai);
        offer_id[2] = otc.offer(30, mkr, 100, dai);
        offer_id[3] = otc.offer(30, mkr, 100, dai);
        assertEq(otc.getFirstUnsortedOffer(), offer_id[3]);
        assertEq(otc.getNextUnsortedOffer(offer_id[1]), 0);
        assertEq(otc.getNextUnsortedOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getNextUnsortedOffer(offer_id[3]), offer_id[2]);
    }
    function testGetFirstNextUnsortedOfferAfterInsertOne() public {
        mkr.approve(otc, 90);
        offer_id[1] = otc.offer(30, mkr, 100, dai);
        offer_id[2] = otc.offer(30, mkr, 100, dai);
        offer_id[3] = otc.offer(30, mkr, 100, dai);
        otc.insert(offer_id[3], 0);
        assertEq(otc.getBestOffer( mkr, dai ), offer_id[3]);
        assertEq(otc.getFirstUnsortedOffer(), offer_id[2]);
        assertEq(otc.getNextUnsortedOffer(offer_id[1]), 0);
        assertEq(otc.getNextUnsortedOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getNextUnsortedOffer(offer_id[3]), 0);
    }
    function testGetFirstNextUnsortedOfferAfterInsertTwo() public {
        mkr.approve(otc, 90);
        offer_id[1] = otc.offer(30, mkr, 100, dai);
        offer_id[2] = otc.offer(30, mkr, 100, dai);
        offer_id[3] = otc.offer(30, mkr, 100, dai);
        otc.insert(offer_id[3],0);
        otc.insert(offer_id[2],0);
        assertEq( otc.getFirstUnsortedOffer(), offer_id[1]);
        assertEq( otc.getNextUnsortedOffer(offer_id[1]), 0);
        assertEq( otc.getNextUnsortedOffer(offer_id[2]), 0);
        assertEq( otc.getNextUnsortedOffer(offer_id[3]), 0);
    }
    function testGetFirstNextUnsortedOfferAfterInsertTheree() public {
        mkr.approve(otc, 90);
        offer_id[1] = otc.offer(30, mkr, 100, dai);
        offer_id[2] = otc.offer(30, mkr, 100, dai);
        offer_id[3] = otc.offer(30, mkr, 100, dai);
        otc.insert(offer_id[3],0);
        otc.insert(offer_id[2],0);
        otc.insert(offer_id[1],0);
        assertEq(otc.getFirstUnsortedOffer(), 0);
        assertEq(otc.getNextUnsortedOffer(offer_id[1]), 0);
        assertEq(otc.getNextUnsortedOffer(offer_id[2]), 0);
        assertEq(otc.getNextUnsortedOffer(offer_id[3]), 0);
    }
    function testFailInsertOfferThatIsAlreadyInTheSortedList() public {
        mkr.approve(otc, 30);
        offer_id[1] = otc.offer(30, mkr, 100, dai, 0);
        otc.insert(offer_id[1],0);
        otc.insert(offer_id[1],0);
    }
    function testFailInsertOfferThatHasWrongInserPosition() public {
        mkr.approve(otc, 30);
        offer_id[1] = otc.offer(30, mkr, 100, dai, 0);
        otc.insert(offer_id[1],7);  //there is no active offer at pos 7
    }
    function testBuyEnabledByDefault() public constant {
        assert(otc.buyEnabled());
    }
    function testSetBuyDisabled() public {
        otc.setBuyEnabled(false);
        assert(!otc.buyEnabled());
        expectEventsExact(otc);
        LogBuyEnabled(false);
    }
    function testSetBuyEnabled() public {
        otc.setBuyEnabled(false);
        otc.setBuyEnabled(true);
        assert(otc.buyEnabled());
        expectEventsExact(otc);
        LogBuyEnabled(false);
        LogBuyEnabled(true);
    }
    function testFailBuyDisabled() public {
        otc.setBuyEnabled(false);
        mkr.approve(otc, 30);
        dai.transfer(user1, 100 );
        offer_id[1] = otc.offer(30, mkr, 100, dai, 0);
        user1.doBuy(offer_id[1], 30);//should fail
    }
    function testBuyEnabledBuyWorks() public {
        otc.setBuyEnabled(false);
        otc.setBuyEnabled(true);
        mkr.approve(otc, 30);
        dai.transfer(user1, 90);
        user1.doApprove(otc, 90, dai);
        offer_id[1] = otc.offer(30, mkr, 90, dai, 0);
        user1.doBuy(offer_id[1], 30);

        expectEventsExact(otc);
        LogBuyEnabled(false);
        LogBuyEnabled(true);
        LogItemUpdate(offer_id[1]);
        LogTrade(30, mkr, 100, dai);
        LogItemUpdate(offer_id[1]);
    }
    function testMatchingEnabledByDefault() public constant {
        assert(otc.matchingEnabled());
    }
    function testDisableMatching() public {
        assert(otc.setMatchingEnabled(false));
        assert(!otc.matchingEnabled());
        expectEventsExact(otc);
        LogMatchingEnabled(false);
    }
    function testFailMatchingEnabledUserCantMakeUnsortedOffer() public {
        assert(otc.matchingEnabled());
        dai.transfer(user1, 1);
        offer_id[1] = user1.doUnsortedOffer(1, dai, 1, mkr);
    }
    function testMatchingDisabledUserCanMakeUnsortedOffer() public {
        assert(otc.setMatchingEnabled(false));
        assert(!otc.matchingEnabled());
        dai.transfer(user1, 1);
        user1.doApprove(otc, 1, dai);
        offer_id[1] = user1.doUnsortedOffer(1, dai, 1, mkr);
        assert(offer_id[1] > 0);
        assertEq(otc.getFirstUnsortedOffer(), 0);
        assertEq(otc.getBestOffer(dai, mkr), 0);
    }
    function testMatchingEnabledAuthUserCanMakeUnsortedOffer() public {
        assert(otc.setMatchingEnabled(true));
        assert(otc.matchingEnabled());
        dai.approve(otc, 1);
        offer_id[1] = otc.offer(1, dai, 1, mkr);
        assert(offer_id[1] > 0);
    }
    function testMatchingDisabledCancelDoesNotChangeSortedList() public {
        assert(otc.setMatchingEnabled(true));
        assert(otc.matchingEnabled());
        dai.approve(otc, 1);
        offer_id[1] = otc.offer(1, dai, 1, mkr, 0);
        assert(otc.setMatchingEnabled(false));
        assert(!otc.matchingEnabled());
        otc.cancel(offer_id[1]);
        assertEq(otc.getBestOffer(dai, mkr), offer_id[1]);
    }
    function testSetGetMinSellAmout() public {
        otc.setMinSell(dai, 100);
        assertEq(otc.getMinSell(dai), 100);
    }
    function testFailOfferSellsLessThanRequired() public {
        mkr.approve(otc, 30);
        otc.setMinSell(mkr, 31);
        assertEq(otc.getMinSell(mkr), 31);
        offer_id[1] = otc.offer(30, mkr, 100, dai, 0);
    }
    function testFailNonOwnerCanNotSetSellAmount() public {
        user1.doSetMinSellAmount(dai,100);
    }
    function testOfferSellsMoreThanOrEqualThanRequired() public {
        mkr.approve(otc, 30);
        otc.setMinSell(mkr,30);
        assertEq(otc.getMinSell(mkr), 30);
        offer_id[1] = otc.offer(30, mkr, 90, dai, 0);
    }
    function testDustMakerOfferCanceled() public {
        assert(otc.matchingEnabled());
        dai.transfer(user1, 30);
        user1.doApprove(otc, 30, dai);
        mkr.approve(otc, 25);
        otc.setMinSell(dai, 10);
        uint id0 = user1.doOffer(30, dai, 30, mkr, 0);
        uint id1 = otc.offer(25, mkr, 25, dai, 0);
        assert(!otc.isActive(id0));
        assert(!otc.isActive(id1));
    }
    function testDustNotNewDustOfferIsCreated() public {
        assert(otc.matchingEnabled());
        dai.transfer(user1, 30);
        user1.doApprove(otc, 30, dai);
        mkr.approve(otc, 25);
        otc.setMinSell(dai, 10);
        uint id0 = otc.offer(25, mkr, 25, dai, 0);
        uint id1 = user1.doOffer(30, dai, 30, mkr, 0);
        assert(!otc.isActive(id0));
        assert(!otc.isActive(id1));
    }
    function testBuyDustOfferCanceled() public {
        dai.transfer(user1, 30);
        user1.doApprove(otc, 30, dai);
        mkr.approve(otc, 25);
        otc.setMinSell(dai, 10);
        uint id0 = user1.doOffer(30, dai, 30, mkr, 0);
        otc.buy(id0, 25);
        assert(!otc.isActive(id0));
    }
    function testErroneousUserHigherIdStillWorks() public {
        dai.transfer(user1, 10);
        user1.doApprove(otc, 10, dai);
        offer_id[1] =  user1.doOffer(1,    dai, 1,    mkr);
        offer_id[2] =  user1.doOffer(2, dai, 1,    mkr);
        offer_id[3] =  user1.doOffer(4, dai, 1,    mkr);
        offer_id[4] =  user1.doOffer(3,    dai, 1,    mkr, offer_id[2]);
    }

    function testErroneousUserHigherIdStillWorksOther() public {
        dai.transfer(user1, 11);
        user1.doApprove(otc, 11, dai);
        offer_id[1] =  user1.doOffer(2, dai, 1,    mkr);
        offer_id[2] =  user1.doOffer(3, dai, 1,    mkr);
        offer_id[3] =  user1.doOffer(5, dai, 1,    mkr);
        offer_id[4] =  user1.doOffer(1,    dai, 1,    mkr, offer_id[3]);
    }
    
    function testNonExistentOffersPosStillWorks() public {
        dai.transfer(user1, 10);
        user1.doApprove(otc, 10, dai);
        uint non_existent_offer_id = 4;
        offer_id[1] =  user1.doOffer(1, dai, 1, mkr);
        offer_id[2] =  user1.doOffer(2, dai, 1, mkr);
        offer_id[3] =  user1.doOffer(4, dai, 1, mkr);
        offer_id[4] =  user1.doOffer(3, dai, 1, mkr, non_existent_offer_id);
    }

    // Derived from error on Kovan, transaction ID:
    // 0x2efe7de83d72ae499fec7f45d64ea48749f8a2bf809b2f64c10c6951b143ca8d
    function testOrderMatchRounding() public {
        // Approvals & user funding
        mkr.transfer(user1, MKR_SUPPLY / 2);
        dai.transfer(user1, DAI_SUPPLY / 2);
        dgd.transfer(user1, DGD_SUPPLY / 2);
        user1.doApprove(otc, DAI_SUPPLY, dai);
        user1.doApprove(otc, DGD_SUPPLY, dgd);
        user1.doApprove(otc, MKR_SUPPLY, mkr);
        dai.approve(otc, DAI_SUPPLY);
        dgd.approve(otc, DGD_SUPPLY);
        mkr.approve(otc, MKR_SUPPLY);

        // Does not divide cleanly.
        otc.offer(1504155374, dgd, 18501111110000000000, dai, 0);

        uint old_dai_bal = dai.balanceOf(user1);
        uint old_dgd_bal = dgd.balanceOf(user1);
        uint dai_pay = 1230000000000000000;
        uint dgd_buy = 100000000;

        // `true` allows rounding to a slightly higher price
        // in order to find a match.
        user1.doOffer(dai_pay, dai, dgd_buy, dgd, 0, true);

        // We should have paid a bit more than we offered to pay.
        uint expected_overpay = 651528437;
        assertEq(dgd.balanceOf(user1) - old_dgd_bal, dgd_buy);
        assertEq(old_dai_bal - dai.balanceOf(user1), dai_pay + expected_overpay);
    }

    function testOrderMatchNoRounding() public {
        // Approvals & user funding
        mkr.transfer(user1, MKR_SUPPLY / 2);
        dai.transfer(user1, DAI_SUPPLY / 2);
        dgd.transfer(user1, DGD_SUPPLY / 2);
        user1.doApprove(otc, DAI_SUPPLY, dai);
        user1.doApprove(otc, DGD_SUPPLY, dgd);
        user1.doApprove(otc, MKR_SUPPLY, mkr);
        dai.approve(otc, DAI_SUPPLY);
        dgd.approve(otc, DGD_SUPPLY);
        mkr.approve(otc, MKR_SUPPLY);

        // Does not divide cleanly.
        otc.offer(1504155374, dgd, 18501111110000000000, dai, 0);

        uint old_dai_bal = dai.balanceOf(user1);
        uint old_dgd_bal = dgd.balanceOf(user1);
        uint dai_pay = 1230000000000000000;
        uint dgd_buy = 100000000;

        user1.doOffer(dai_pay, dai, dgd_buy, dgd, 0, false);

        // Order should not have matched this time.
        assertEq(dgd.balanceOf(user1), old_dgd_bal);
        assertEq(old_dai_bal - dai.balanceOf(user1), dai_pay);
    }    
    
    function testOrderMatchWithRounding() public {
        // Approvals & user funding
        mkr.transfer(user1, MKR_SUPPLY / 2);
        dai.transfer(user1, DAI_SUPPLY / 2);
        dgd.transfer(user1, DGD_SUPPLY / 2);
        user1.doApprove(otc, DAI_SUPPLY, dai);
        user1.doApprove(otc, DGD_SUPPLY, dgd);
        user1.doApprove(otc, MKR_SUPPLY, mkr);
        dai.approve(otc, DAI_SUPPLY);
        dgd.approve(otc, DGD_SUPPLY);
        mkr.approve(otc, MKR_SUPPLY);

        // Does not divide cleanly.
        otc.offer(1504155374, dgd, 18501111110000000000, dai, 0);

        uint old_dai_bal = dai.balanceOf(user1);
        uint old_dgd_bal = dgd.balanceOf(user1);
        uint dai_pay = 1230000000000000000;
        uint dgd_buy = 100000000;

        offer_id[1] = user1.doOffer(dai_pay, dai, dgd_buy, dgd, 0);

        // Order should not have matched this time.
        assertEq(otc.isActive(offer_id[1]), false);
    }

    function testBestOfferWithOneOffer() public {
        dai.transfer(user1, 1);
        user1.doApprove(otc, 1, dai);
        offer_id[1] = user1.doOffer(1, dai, 1, mkr);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[1]);
        assertEq(otc.getBetterOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 1);
    }
    function testBestOfferWithOneOfferWithUserprovidedId() public {
        dai.transfer(user1, 1);
        user1.doApprove(otc, 1, dai);
        offer_id[1] = user1.doOffer(1, dai, 1, mkr , 0);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[1]);
        assertEq(otc.getBetterOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 1);
    }
    function testBestOfferWithTwoOffers() public {
        dai.transfer(user1, 25);
        user1.doApprove(otc, 25, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(15, dai, 1, mkr);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 2);
    }
    function testBestOfferWithTwoOffersWithUserprovidedId() public {
        dai.transfer(user1, 25);
        user1.doApprove(otc, 25, dai);
        offer_id[2] = user1.doOffer(15, dai, 1, mkr);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr, offer_id[2]);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 2);
    }
    function testBestOfferWithThreeOffers() public {
        dai.transfer(user1, 37);
        user1.doApprove(otc, 37, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        offer_id[3] = user1.doOffer(15, dai, 1, mkr);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[3]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[3]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 3);
    }
    function testBestOfferWithThreeOffersMixed() public {
        dai.transfer(user1, 37);
        user1.doApprove(otc, 37, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(15, dai, 1, mkr);
        offer_id[3] = user1.doOffer(12, dai, 1, mkr);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[3]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[1]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getBetterOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getOfferCount(dai, mkr), 3);
    }
    function testBestOfferWithThreeOffersMixedWithUserProvidedId() public {
        dai.transfer(user1, 37);
        user1.doApprove(otc, 37, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(15, dai, 1, mkr);
        offer_id[3] = user1.doOffer(12, dai, 1, mkr, offer_id[2]);

        assertEq(otc.getBestOffer( dai, mkr ), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[3]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[1]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getBetterOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getOfferCount(dai, mkr), 3);
    }
    function testBestOfferWithFourOffersDeleteBetween() public {
        dai.transfer(user1, 53);
        user1.doApprove(otc, 53, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        offer_id[3] = user1.doOffer(15, dai, 1, mkr);
        offer_id[4] = user1.doOffer(16, dai, 1, mkr);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[4]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[4]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[3]), offer_id[4]);
        assertEq(otc.getBetterOffer(offer_id[4]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 4);

        user1.doCancel(offer_id[3]);
        assertEq(otc.getBestOffer(dai, mkr), offer_id[4]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[4]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), offer_id[4]);
        assertEq(otc.getBetterOffer(offer_id[3]), offer_id[4]);
        assertEq(otc.getBetterOffer(offer_id[4]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 3);
    }
    function testBestOfferWithFourOffersWithUserprovidedId() public {
        dai.transfer(user1, 53);
        user1.doApprove(otc, 53, dai);
        offer_id[4] = user1.doOffer(16, dai, 1, mkr, 0);
        offer_id[3] = user1.doOffer(15, dai, 1, mkr, offer_id[4]);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr, offer_id[3]);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr, offer_id[2]);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[4]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[4]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[3]), offer_id[4]);
        assertEq(otc.getBetterOffer(offer_id[4]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 4);
    }
    function testBestOfferWithFourOffersTwoSamePriceUserProvidedId() public {
        dai.transfer(user1, 50);
        user1.doApprove(otc, 50, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        offer_id[4] = user1.doOffer(16, dai, 1, mkr);
        offer_id[3] = user1.doOffer(12, dai, 1, mkr , offer_id[2]);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[4]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[3]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[4]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[2]), offer_id[4]);
        assertEq(otc.getBetterOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[4]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 4);
    }
    function testBestOfferWithTwoOffersDeletedLowest() public {
        dai.transfer(user1, 22);
        user1.doApprove(otc, 22, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        user1.doCancel(offer_id[1]);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), 0);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getOfferCount(dai,mkr), 1);
        assert(!otc.isActive( offer_id[1]));
    }
    function testBestOfferWithTwoOffersDeletedHighest() public {
        dai.transfer(user1, 22);
        user1.doApprove(otc, 22, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        user1.doCancel(offer_id[2]);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getBetterOffer(offer_id[1]), 0);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 1);
        assert(!otc.isActive(offer_id[2]));
    }
    function testBestOfferWithThreeOffersDeletedLowest() public {
        dai.transfer(user1, 36);
        user1.doApprove(otc, 36, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        offer_id[3] = user1.doOffer(14, dai, 1, mkr);
        user1.doCancel(offer_id[1]);
        assertEq(otc.getBestOffer(dai, mkr), offer_id[3]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), 0);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[2]);

        // make sure we retained our offer information.
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[3]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 2);
        assert(!otc.isActive(offer_id[1]));
    }
    function testBestOfferWithThreeOffersDeletedHighest() public {
        dai.transfer(user1, 36);
        user1.doApprove(otc, 36, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        offer_id[3] = user1.doOffer(14, dai, 1, mkr);
        user1.doCancel(offer_id[3]);
        assertEq(otc.getBestOffer(dai, mkr), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getBetterOffer(offer_id[3]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 2);
        assert(!otc.isActive( offer_id[3]));

        expectEventsExact(otc);
        LogItemUpdate(offer_id[1]);
        LogItemUpdate(offer_id[2]);
        LogItemUpdate(offer_id[3]);
        LogItemUpdate(offer_id[3]);
    }
    function testBestOfferWithTwoOffersWithDifferentTokens() public {
        dai.transfer(user1, 2);
        user1.doApprove(otc, 2, dai);
        offer_id[1] = user1.doOffer(1, dai, 1, dgd);
        offer_id[2] = user1.doOffer(1, dai, 1, mkr);
        assertEq(otc.getBestOffer(dai, dgd), offer_id[1]);
        assertEq(otc.getBestOffer(dai, mkr), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[1]), 0);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), 0);
        assertEq(otc.getOfferCount(dai, dgd), 1);
        assertEq(otc.getOfferCount(dai, mkr), 1);
    }
    function testBestOfferWithFourOffersWithDifferentTokens() public {
        dai.transfer(user1, 55);
        user1.doApprove(otc, 55, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        offer_id[3] = user1.doOffer(16, dai, 1, dgd);
        offer_id[4] = user1.doOffer(17, dai, 1, dgd);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[2]);
        assertEq(otc.getBestOffer(dai, dgd), offer_id[4]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getBetterOffer(offer_id[3]), offer_id[4]);
        assertEq(otc.getBetterOffer(offer_id[4]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[3]), 0);
        assertEq(otc.getWorseOffer(offer_id[4]), offer_id[3]);
        assertEq(otc.getOfferCount(dai, mkr), 2);
        assertEq(otc.getOfferCount(dai, dgd), 2);
    }
    function testBestOfferWithSixOffersWithDifferentTokens() public {
        dai.transfer(user1, 88);
        user1.doApprove(otc, 88, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        offer_id[3] = user1.doOffer(15, dai, 1, mkr);
        offer_id[4] = user1.doOffer(16, dai, 1, dgd);
        offer_id[5] = user1.doOffer(17, dai, 1, dgd);
        offer_id[6] = user1.doOffer(18, dai, 1, dgd);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[3]);
        assertEq(otc.getBestOffer(dai, dgd), offer_id[6]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[3]), 0);
        assertEq(otc.getBetterOffer(offer_id[4]), offer_id[5]);
        assertEq(otc.getBetterOffer(offer_id[5]), offer_id[6]);
        assertEq(otc.getBetterOffer(offer_id[6]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[4]), 0);
        assertEq(otc.getWorseOffer(offer_id[5]), offer_id[4]);
        assertEq(otc.getWorseOffer(offer_id[6]), offer_id[5]);
        assertEq(otc.getOfferCount(dai, mkr), 3);
        assertEq(otc.getOfferCount(dai, dgd), 3);
    }
    function testBestOfferWithEightOffersWithDifferentTokens() public {
        dai.transfer(user1, 106);
        user1.doApprove(otc, 106, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        offer_id[3] = user1.doOffer(15, dai, 1, mkr);
        offer_id[4] = user1.doOffer(16, dai, 1, mkr);
        offer_id[5] = user1.doOffer(10, dai, 1, dgd);
        offer_id[6] = user1.doOffer(12, dai, 1, dgd);
        offer_id[7] = user1.doOffer(15, dai, 1, dgd);
        offer_id[8] = user1.doOffer(16, dai, 1, dgd);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[4]);
        assertEq(otc.getBestOffer(dai, dgd), offer_id[8]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[3]), offer_id[4]);
        assertEq(otc.getBetterOffer(offer_id[4]), 0);
        assertEq(otc.getBetterOffer(offer_id[5]), offer_id[6]);
        assertEq(otc.getBetterOffer(offer_id[6]), offer_id[7]);
        assertEq(otc.getBetterOffer(offer_id[7]), offer_id[8]);
        assertEq(otc.getBetterOffer(offer_id[8]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[4]), offer_id[3]);
        assertEq(otc.getWorseOffer(offer_id[5]), 0);
        assertEq(otc.getWorseOffer(offer_id[6]), offer_id[5]);
        assertEq(otc.getWorseOffer(offer_id[7]), offer_id[6]);
        assertEq(otc.getWorseOffer(offer_id[8]), offer_id[7]);
        assertEq(otc.getOfferCount(dai, mkr), 4);
        assertEq(otc.getOfferCount(dai, dgd), 4);
    }
    function testBestOfferWithFourOffersWithDifferentTokensLowHighDeleted() public {
        dai.transfer(user1, 29);
        user1.doApprove(otc, 39, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        user1.doCancel(offer_id[1] );
        offer_id[3] = user1.doOffer(8, dai, 1, dgd);
        offer_id[4] = user1.doOffer(9, dai, 1, dgd);
        user1.doCancel(offer_id[3]);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[2]);
        assertEq(otc.getBestOffer(dai, dgd), offer_id[4]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getBetterOffer(offer_id[3]), offer_id[4]);
        assertEq(otc.getBetterOffer(offer_id[4]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), 0);
        assertEq(otc.getWorseOffer(offer_id[3]), 0);
        assertEq(otc.getWorseOffer(offer_id[4]), 0);
        assertEq(otc.getOfferCount(dai,mkr), 1);
        assertEq(otc.getOfferCount(dai,dgd), 1);
        assert(!otc.isActive(offer_id[1]));
        assert(!otc.isActive(offer_id[3]));
    }
    function testBestOfferWithFourOffersWithDifferentTokensHighLowDeleted() public {
        dai.transfer(user1, 27);
        user1.doApprove(otc, 39, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        user1.doCancel(offer_id[2]);
        offer_id[3] = user1.doOffer(8, dai, 1, dgd);
        offer_id[4] = user1.doOffer(9, dai, 1, dgd);
        user1.doCancel(offer_id[4]);
        assertEq(otc.getBestOffer( dai, mkr ), offer_id[1]);
        assertEq(otc.getBestOffer( dai, dgd ), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[1]), 0);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getBetterOffer(offer_id[3]), 0);
        assertEq(otc.getBetterOffer(offer_id[4]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[3]), 0);
        assertEq(otc.getWorseOffer(offer_id[4]), offer_id[3]);
        assertEq(otc.getOfferCount(dai,mkr), 1);
        assertEq(otc.getOfferCount(dai,dgd), 1);
        assert(!otc.isActive(offer_id[2]));
        assert(!otc.isActive(offer_id[4]));
    }
    function testBestOfferWithSixOffersWithDifferentTokensLowHighDeleted() public {
        dai.transfer(user1, 78);
        user1.doApprove(otc, 88, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        offer_id[3] = user1.doOffer(15, dai, 1, mkr);
        user1.doCancel(offer_id[1]);
        offer_id[4] = user1.doOffer(16, dai, 1, dgd);
        offer_id[5] = user1.doOffer(17, dai, 1, dgd);
        offer_id[6] = user1.doOffer(18, dai, 1, dgd);
        user1.doCancel(offer_id[6]);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[3]);
        assertEq(otc.getBestOffer(dai, dgd), offer_id[5]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[3]), 0);
        assertEq(otc.getBetterOffer(offer_id[4]), offer_id[5]);
        assertEq(otc.getBetterOffer(offer_id[5]), 0);
        assertEq(otc.getBetterOffer(offer_id[6]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), 0);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[4]), 0);
        assertEq(otc.getWorseOffer(offer_id[5]), offer_id[4]);
        assertEq(otc.getWorseOffer(offer_id[6]), offer_id[5]);
        assertEq(otc.getOfferCount(dai,mkr), 2);
        assertEq(otc.getOfferCount(dai,dgd), 2);
        assert(!otc.isActive( offer_id[1]));
        assert(!otc.isActive( offer_id[6]));
    }
    function testBestOfferWithSixOffersWithDifferentTokensHighLowDeleted() public {
        dai.transfer(user1, 73);
        user1.doApprove(otc, 88, dai);
        offer_id[1] = user1.doOffer(10, dai, 1, mkr);
        offer_id[2] = user1.doOffer(12, dai, 1, mkr);
        offer_id[3] = user1.doOffer(15, dai, 1, mkr);
        user1.doCancel(offer_id[3]);
        offer_id[4] = user1.doOffer(16, dai, 1, dgd);
        offer_id[5] = user1.doOffer(17, dai, 1, dgd);
        offer_id[6] = user1.doOffer(18, dai, 1, dgd);
        user1.doCancel(offer_id[4]);

        assertEq(otc.getBestOffer(dai, mkr), offer_id[2]);
        assertEq(otc.getBestOffer(dai, dgd), offer_id[6]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getBetterOffer(offer_id[3]), 0); // was best when cancelled
        assertEq(otc.getBetterOffer(offer_id[4]), offer_id[5]);
        assertEq(otc.getBetterOffer(offer_id[5]), offer_id[6]);
        assertEq(otc.getBetterOffer(offer_id[6]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[2]);
        assertEq(otc.getWorseOffer(offer_id[4]), 0);
        assertEq(otc.getWorseOffer(offer_id[5]), 0);
        assertEq(otc.getWorseOffer(offer_id[6]), offer_id[5]);
        assertEq(otc.getOfferCount(dai, mkr), 2);
        assertEq(otc.getOfferCount(dai, dgd), 2);
        assert(!otc.isActive(offer_id[3]));
        assert(!otc.isActive(offer_id[4]));
    }

    function testInsertOfferWithUserProvidedIdOfADifferentTokenLower() public {
        dai.transfer(user1, 13);
        user1.doApprove(otc, 13, dai);
        dai.approve(otc, 11);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = otc.offer(11, dai, 1, dgd, offer_id[1]);
	assert(otc.getBetterOffer(offer_id[2]) == 0);
	assert(otc.getWorseOffer(offer_id[2]) == 0);
    }
    
    function testInsertOfferWithUserProvidedIdOfADifferentTokenHigher() public {
        dai.transfer(user1, 13);
        user1.doApprove(otc, 13, dai);
        dai.approve(otc, 14);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = otc.offer(14, dai, 1, dgd, offer_id[1]);
	assert(otc.getBetterOffer(offer_id[2]) == 0);
	assert(otc.getWorseOffer(offer_id[2]) == 0);
    }
    
    function testInsertOfferWithUserProvidedIdOfADifferentTokenHigherToHighest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 12);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[1]);
        offer_id[4] = otc.offer(12, dai, 1, dgd, offer_id[1]);
	assert(otc.getBetterOffer(offer_id[4]) == 0);
	assert(otc.getWorseOffer(offer_id[4]) == 0);
    }

    function testInsertOfferWithUserProvidedIdOfADifferentTokenHigherToBetween() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 10);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[2]);
        offer_id[4] = otc.offer(10, dai, 1, dgd , offer_id[2]);
	assert(otc.getBetterOffer(offer_id[4]) == 0);
	assert(otc.getWorseOffer(offer_id[4]) == 0);
    }

    function testInsertOfferWithUserProvidedIdOfADifferentTokenHigherToLowest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 8);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[3]);
        offer_id[4] = otc.offer(8, dai, 1, dgd, offer_id[3]);
	assert(otc.getBetterOffer(offer_id[4]) == 0);
	assert(otc.getWorseOffer(offer_id[4]) == 0);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToHighestWrongPos() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[1]);
        offer_id[4] = otc.offer(14, dai, 1, mkr, offer_id[1]);
	assert(otc.getBetterOffer(offer_id[4]) == 0);
	assert(otc.getWorseOffer(offer_id[4]) == offer_id[2]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToBetweenWrongPos() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[2]);
        offer_id[4] = otc.offer(14, dai, 1, mkr, offer_id[2]);
	assert(otc.getBetterOffer(offer_id[4]) == 0);
	assert(otc.getWorseOffer(offer_id[4]) == offer_id[1]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToLowestWrongPos() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[3]);
        offer_id[4] = otc.offer(14, dai, 1, mkr, offer_id[3]);
	assert(otc.getBetterOffer(offer_id[4]) == 0);
	assert(otc.getWorseOffer(offer_id[4]) == offer_id[1]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToHighestWrongPosLowest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 7);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[1]);
        offer_id[4] = otc.offer(7, dai, 1, mkr, offer_id[1]);
	assert(otc.getBetterOffer(offer_id[4]) == offer_id[3]);
	assert(otc.getWorseOffer(offer_id[4]) == 0);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToBetweenWrongPosLowest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 7);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[2]);
        offer_id[4] = otc.offer(7, dai, 1, mkr, offer_id[2]);
	assert(otc.getBetterOffer(offer_id[4]) == offer_id[3]);
	assert(otc.getWorseOffer(offer_id[4]) == 0);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToLowestWrongPosLowest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 7);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[3]);
        offer_id[4] = otc.offer(7, dai, 1, mkr, offer_id[3]);
	assert(otc.getBetterOffer(offer_id[4]) == offer_id[2]);
	assert(otc.getWorseOffer(offer_id[4]) == 0);
    }
    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToHighest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 12);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[1]);
        offer_id[4] = otc.offer(12, dai, 1, mkr, offer_id[1]);
	assert(otc.getBetterOffer(offer_id[4]) == 0);
	assert(otc.getWorseOffer(offer_id[4]) == offer_id[2]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToBetween() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 10);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[2]);
        offer_id[4] = otc.offer(10, dai, 1, mkr, offer_id[2]);
	assert(otc.getBetterOffer(offer_id[4]) == offer_id[1]);
	assert(otc.getWorseOffer(offer_id[4]) == offer_id[3]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToLowest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 8);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[3]);
        offer_id[4] = otc.offer(8, dai, 1, mkr, offer_id[3]);
	assert(otc.getBetterOffer(offer_id[4]) == offer_id[2]);
	assert(otc.getWorseOffer(offer_id[4]) == 0);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToHighestWrongPosHighest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[1]);
        offer_id[4] = otc.offer(14, dai, 1, mkr, offer_id[1]);
	assert(otc.getBetterOffer(offer_id[4]) == 0);
	assert(otc.getWorseOffer(offer_id[4]) == offer_id[2]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToBetweenWrongPosHighest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[2]);
        offer_id[4] = otc.offer(14, dai, 1, mkr, offer_id[2]);
	assert(otc.getBetterOffer(offer_id[4]) == 0);
	assert(otc.getWorseOffer(offer_id[4]) == offer_id[1]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToLowestWrongPosHighest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[3]);
        offer_id[4] = otc.offer(14, dai, 1, mkr, offer_id[3]);
	assert(otc.getBetterOffer(offer_id[4]) == 0);
	assert(otc.getWorseOffer(offer_id[4]) == offer_id[1]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToHighestWrongPosBetween() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 10);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[1]);
        offer_id[4] = otc.offer(10, dai, 1, mkr, offer_id[1]);
	assert(otc.getBetterOffer(offer_id[4]) == offer_id[2]);
	assert(otc.getWorseOffer(offer_id[4]) == offer_id[3]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToBetweenWrongPosBetween() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 10);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[2]);
        offer_id[4] = otc.offer(10, dai, 1, mkr, offer_id[2]);
	assert(otc.getBetterOffer(offer_id[4]) == offer_id[1]);
	assert(otc.getWorseOffer(offer_id[4]) == offer_id[3]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToLowestWrongPosBetween() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 10);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr);
        offer_id[2] = user1.doOffer(11, dai, 1, mkr);
        offer_id[3] = user1.doOffer(9, dai, 1, mkr);
	user1.doCancel(offer_id[3]);
        offer_id[4] = otc.offer(10, dai, 1, mkr, offer_id[3]);
	assert(otc.getBetterOffer(offer_id[4]) == offer_id[2]);
	assert(otc.getWorseOffer(offer_id[4]) == 0);
    }

    function testOfferMatchOneOnOneSendAmounts() public {
        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        offer_id[1] = otc.offer(30, mkr, 100, dai, 0);
        offer_id[2] = user1.doOffer(100, dai, 30, mkr);
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        assertEq(my_mkr_balance_before - my_mkr_balance_after , 30);
        assertEq(my_dai_balance_after - my_dai_balance_before , 100);
        assertEq(user1_mkr_balance_after - user1_mkr_balance_before, 30);
        assertEq(user1_dai_balance_before - user1_dai_balance_after, 100);

        /* //REPORTS FALSE ERROR:
        expectEventsExact(otc);
        LogItemUpdate(offer_id[1]);
        LogItemUpdate(offer_id[1]);
        LogItemUpdate(offer_id[2]);*/
    }
    function testOfferMatchOneOnOnePartialSellSendAmounts() public {
        dai.transfer(user1, 50);
        user1.doApprove(otc, 50, dai);
        mkr.approve(otc, 200);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        offer_id[1] = otc.offer(200, mkr, 500, dai, 0);
        offer_id[2] = user1.doOffer(50, dai, 20, mkr);
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(offer_id[1]);

        assertEq(my_mkr_balance_before - my_mkr_balance_after, 200);
        assertEq(my_dai_balance_after - my_dai_balance_before, 50);
        assertEq(user1_mkr_balance_after - user1_mkr_balance_before, 20);
        assertEq(user1_dai_balance_before - user1_dai_balance_after, 50);
        assertEq(sell_val, 180);
        assertEq(buy_val, 450);
        assert(!otc.isActive(offer_id[2]));

        /* //REPORTS FALSE ERROR:
        expectEventsExact(otc);
        LogItemUpdate(offer_id[1]);
        LogItemUpdate(offer_id[1]);
        LogItemUpdate(offer_id[2]);*/
    }
    function testOfferMatchOneOnOnePartialBuySendAmounts() public {
        dai.transfer(user1, 2000);
        user1.doApprove(otc, 2000, dai);
        mkr.approve(otc, 200);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        offer_id[1] = otc.offer(200, mkr, 500, dai, 0);
        offer_id[2] = user1.doOffer(2000, dai, 800, mkr);
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
         (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(offer_id[1]);
         (sell_val1, sell_token1, buy_val1, buy_token1) = otc.getOffer(offer_id[2]);

        assertEq(my_mkr_balance_before - my_mkr_balance_after, 200);
        assertEq(my_dai_balance_after - my_dai_balance_before, 500 );
        assertEq(user1_mkr_balance_after - user1_mkr_balance_before, 200);
        assertEq(user1_dai_balance_before - user1_dai_balance_after, 2000);
        assertEq(sell_val , 0);
        assertEq(buy_val , 0);
        assertEq(sell_val1 , 1500);
        assertEq(buy_val1 , 600);

        expectEventsExact(otc);
        LogItemUpdate(offer_id[1]);
        LogItemUpdate(offer_id[1]);
        LogItemUpdate(offer_id[2]);
    }
    function testOfferMatchingOneOnOneMatch() public {
        dai.transfer(user1, 1);
        user1.doApprove(otc, 1, dai);
        mkr.approve(otc, 1);
        offer_id[1] = user1.doOffer(1, dai, 1, mkr);
        offer_id[2] = otc.offer(1, mkr, 1, dai, 0);

        assertEq(otc.getBestOffer(dai, mkr), 0);
        assertEq(otc.getBetterOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 0);
        assert(!otc.isActive(offer_id[1]));
        assert(!otc.isActive(offer_id[2]));
    }
    function testOfferMatchingOneOnOneMatchCheckOfferPriceRemainsTheSame() public {
        dai.transfer(user1, 5);
        user1.doApprove(otc, 5, dai);
        mkr.approve(otc, 10);
        offer_id[1] = user1.doOffer(5, dai, 1, mkr);
        offer_id[2] = otc.offer(10, mkr, 10, dai, 0);
        (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(offer_id[2]);

        assertEq(otc.getBestOffer(dai, mkr), 0);
        assertEq(otc.getBetterOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 0);
        assertEq(otc.getOfferCount(mkr, dai), 1);
        assert(!otc.isActive(offer_id[1]));
        //assert price of offer_id[2] should be the same as before matching
        assertEq(sell_val, 5);
        assertEq(buy_val, 5);
        assert(address(sell_token) > 0x0);
        assert(address(buy_token) > 0x0);
    }
    function testOfferMatchingPartialSellTwoOffers() public {
        mkr.transfer(user1, 10);
        user1.doApprove(otc, 10, mkr);
        dai.approve(otc, 5);
        offer_id[1] = user1.doOffer( 10, mkr, 10, dai);
        offer_id[2] = otc.offer(5, dai, 5, mkr, 0);
        (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(offer_id[1]);

        assertEq(otc.getBestOffer(dai, mkr), 0);
        assertEq(otc.getBestOffer(mkr, dai), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), 0);
        assertEq(otc.getBetterOffer(offer_id[1]), 0);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getOfferCount(mkr, dai), 1);
        assertEq(otc.getOfferCount(dai, mkr), 0);
        assert(!otc.isActive(offer_id[2]));
        assertEq(sell_val, 5);
        assertEq(buy_val, 5);
        assert(address(sell_token) > 0x0);
        assert(address(buy_token) > 0x0);
    }
    function testOfferMatchingOneOnTwoMatchCheckOfferPriceRemainsTheSame() public {
        dai.transfer(user1, 9);
        user1.doApprove(otc, 9, dai);
        mkr.approve(otc, 10);
        offer_id[1] = user1.doOffer(5, dai, 1, mkr);
        offer_id[1] = user1.doOffer(4, dai, 1, mkr);
        offer_id[2] = otc.offer(10, mkr, 10, dai, 0);
        (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(offer_id[2]);

        assertEq(otc.getBestOffer(dai, mkr), 0);
        assertEq(otc.getBetterOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getOfferCount(dai, mkr), 0);
        assertEq(otc.getOfferCount(mkr, dai), 1);
        assert(!otc.isActive(offer_id[1]));
        //assert érice of offer_id[2] should be the same as before matching
        assertEq(sell_val, 1);
        assertEq(buy_val, 1);
        assert(address(sell_token) > 0x0);
        assert(address(buy_token) > 0x0);
    }
    function testOfferMatchingPartialBuyTwoOffers() public {
        mkr.transfer(user1, 5);
        user1.doApprove(otc, 5, mkr);
        dai.approve(otc, 10);
        offer_id[1] = user1.doOffer(5, mkr, 5, dai);
        offer_id[2] = otc.offer(10, dai, 10, mkr, 0);
        (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(offer_id[2]);

        assertEq( otc.getBestOffer(dai, mkr), offer_id[2]);
        assertEq( otc.getBestOffer(mkr, dai), 0);
        assertEq( otc.getWorseOffer(offer_id[1]), 0);
        assertEq( otc.getWorseOffer(offer_id[2]), 0);
        assertEq( otc.getBetterOffer(offer_id[1]), 0);
        assertEq( otc.getBetterOffer(offer_id[2]), 0);
        assertEq( otc.getOfferCount(mkr, dai), 0);
        assertEq( otc.getOfferCount(dai, mkr), 1);
        assert(!otc.isActive(offer_id[1]));
        assertEq(sell_val, 5);
        assertEq(buy_val, 5);
        assert(address(sell_token) > 0x0);
        assert(address(buy_token) > 0x0);
    }
    function testOfferMatchingPartialBuyThreeOffers() public {
        mkr.transfer(user1, 15);
        user1.doApprove(otc, 15, mkr);
        dai.approve(otc, 1);
        offer_id[1] = user1.doOffer(5, mkr, 10, dai);
        offer_id[2] = user1.doOffer(10, mkr, 10, dai);
        offer_id[3] = otc.offer(1, dai, 1, mkr, 0);
        (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(offer_id[1]);
        (sell_val1, sell_token1, buy_val1, buy_token1) = otc.getOffer(offer_id[2]);

        assertEq(otc.getBestOffer(mkr, dai), offer_id[2]);
        assertEq(otc.getBestOffer(dai, mkr), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[2]);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getOfferCount(mkr, dai), 2);
        assertEq(otc.getOfferCount(dai, mkr), 0);
        assert(!otc.isActive(offer_id[3]));
        assertEq(sell_val, 5);
        assertEq(buy_val, 10);
        assertEq(sell_val1, 9);
        assertEq(buy_val1, 9);
        assert(address(sell_token) > 0x0);
        assert(address(buy_token) > 0x0);
        assert(address(sell_token1) > 0x0);
        assert(address(buy_token1) > 0x0);
    }
    function testOfferMatchingPartialSellThreeOffers() public {
        mkr.transfer(user1, 6);
        user1.doApprove(otc, 6, mkr);
        dai.approve(otc, 10);
        offer_id[1] = user1.doOffer(5, mkr, 10, dai);
        offer_id[2] = user1.doOffer(1, mkr, 1, dai);
        offer_id[3] = otc.offer(10, dai, 10, mkr, 0);
        (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(offer_id[1]);
        (sell_val1, sell_token1, buy_val1, buy_token1) = otc.getOffer(offer_id[3]);

        assertEq(otc.getBestOffer(mkr, dai), offer_id[1]);
        assertEq(otc.getBestOffer(dai, mkr), offer_id[3]);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[3]), 0);
        assertEq(otc.getBetterOffer(offer_id[1]), 0);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getBetterOffer(offer_id[3]), 0);
        assertEq(otc.getOfferCount(mkr, dai), 1);
        assertEq(otc.getOfferCount(dai, mkr), 1);
        assert(!otc.isActive(offer_id[2]));
        assertEq(sell_val, 5);
        assertEq(buy_val, 10);
        assertEq(sell_val1, 9);
        assertEq(buy_val1, 9);
        assert(address(sell_token) > 0x0);
        assert(address(buy_token) > 0x0);
        assert(address(sell_token1) > 0x0);
        assert(address(buy_token1) > 0x0);
    }
    function testOfferMatchingPartialSellThreeOffersTwoBuyThreeSell() public {
        dai.transfer(user1, 3);
        user1.doApprove(otc, 3, dai);
        mkr.approve(otc, 12);
        offer_id[1] = otc.offer(1, mkr, 10, dai, 0);
        offer_id[2] = otc.offer(1, mkr,  1, dai, 0);
        offer_id[3] = otc.offer(10, mkr, 10, dai, 0);
        offer_id[4] = user1.doOffer(3, dai, 3, mkr);
        (sell_val, sell_token, buy_val, buy_token) = otc.getOffer(offer_id[3]);
        (sell_val1, sell_token1, buy_val1, buy_token1) = otc.getOffer(offer_id[1]);

        assertEq(otc.getBestOffer(mkr, dai), offer_id[3]);
        assertEq(otc.getBestOffer(dai, mkr), 0);
        assertEq(otc.getWorseOffer(offer_id[1]), 0);
        assertEq(otc.getWorseOffer(offer_id[2]), offer_id[3]);
        assertEq(otc.getWorseOffer(offer_id[3]), offer_id[1]);
        assertEq(otc.getWorseOffer(offer_id[4]), 0);
        assertEq(otc.getBetterOffer(offer_id[1]), offer_id[3]);
        assertEq(otc.getBetterOffer(offer_id[2]), 0);
        assertEq(otc.getBetterOffer(offer_id[3]), 0);
        assertEq(otc.getBetterOffer(offer_id[4]), 0);
        assertEq(otc.getOfferCount(mkr, dai), 2);
        assertEq(otc.getOfferCount(dai, mkr), 0);
        assert(!otc.isActive(offer_id[2]));
        assert(!otc.isActive(offer_id[4]));
        assertEq(sell_val, 8);
        assertEq(buy_val, 8);
        assertEq(sell_val1, 1);
        assertEq(buy_val1, 10);
        assert(address(sell_token) > 0x0);
        assert(address(buy_token) > 0x0);
        assert(address(sell_token1) > 0x0);
        assert(address(buy_token1) > 0x0);
    }
    function testSellAllDai() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.offer(10 ether, mkr, 3200 ether, dai, 0);
        otc.offer(10 ether, mkr, 2800 ether, dai, 0);

        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        assertEq(otc.getBuyAmount(mkr, dai, 4000 ether), expectedResult);
        assertEq(otc.sellAllAmount(dai, 4000 ether, mkr, expectedResult), expectedResult);

        otc.offer(10 ether, mkr, 3200 ether, dai, 0);
        otc.offer(10 ether, mkr, 2800 ether, dai, 0);

        // With 319 wei DAI is not possible to buy 1 wei MKR, then 319 wei DAI can not be sold
        expectedResult = 10 ether * 2800 / 2800;
        assertEq(otc.getBuyAmount(mkr, dai, 2800 ether + 319), expectedResult);
        assertEq(otc.sellAllAmount(dai, 2800 ether + 319, mkr, expectedResult), expectedResult);

        otc.offer(10 ether, mkr, 2800 ether, dai, 0);
        // This time we should be able to buy 1 wei MKR more
        expectedResult = 10 ether * 2800 / 2800 + 1;
        assertEq(otc.getBuyAmount(mkr, dai, 2800 ether + 320), expectedResult);
        assertEq(otc.sellAllAmount(dai, 2800 ether + 320, mkr, expectedResult), expectedResult);
    }

    function testSellAllMkr() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.offer(3200 ether, dai, 10 ether, mkr, 0);
        otc.offer(2800 ether, dai, 10 ether, mkr, 0);

        uint expectedResult = 3200 ether * 10 / 10 + 2800 ether * 8 / 10;
        assertEq(otc.getBuyAmount(dai, mkr, 18 ether), expectedResult);
        assertEq(otc.sellAllAmount(mkr, 18 ether, dai, expectedResult), expectedResult);
    }

    function testFailSellAllMkr() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.offer(3200 ether, dai, 10 ether, mkr, 0);
        otc.offer(2800 ether, dai, 10 ether, mkr, 0);

        uint expectedResult = 3200 ether * 10 / 10 + 2800 ether * 8 / 10;
        assertEq(otc.sellAllAmount(mkr, 18 ether, dai, expectedResult + 1), expectedResult);
    }

    function testBuyAllMkr() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.offer(10 ether, mkr, 3200 ether, dai, 0);
        otc.offer(10 ether, mkr, 2800 ether, dai, 0);

        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        assertEq(otc.getPayAmount(dai, mkr, 15 ether), expectedResult);
        assertEq(otc.buyAllAmount(mkr, 15 ether, dai, expectedResult), expectedResult);
    }

    function testBuyAllDai() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.offer(3200 ether, dai, 10 ether, mkr, 0);
        otc.offer(2800 ether, dai, 10 ether, mkr, 0);

        uint expectedResult = 10 ether * 3200 / 3200 + 10 ether * 1400 / 2800;
        assertEq(otc.getPayAmount(mkr, dai, 4600 ether), expectedResult);
        assertEq(otc.buyAllAmount(dai, 4600 ether, mkr, expectedResult), expectedResult);
    }

    function testFailBuyAllDai() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.offer(3200 ether, dai, 10 ether, mkr, 0);
        otc.offer(2800 ether, dai, 10 ether, mkr, 0);

        uint expectedResult = 10 ether * 3200 / 3200 + 10 ether * 1400 / 2800;
        assertEq(otc.buyAllAmount(dai, 4600 ether, mkr, expectedResult - 1), expectedResult);
    }
}
