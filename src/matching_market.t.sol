pragma solidity ^0.4.24;

import "ds-test/test.sol";
import "ds-token/base.sol";

import "./matching_market.sol";

contract MarketTester {
    MatchingMarket market;

    constructor(MatchingMarket  market_) public {
        market = market_;
    }

    function doSetDustLimitAmount(ERC20 sellGem, uint minAmt) public returns (bool) {
        return market.setDustLimit(sellGem, minAmt);
    }

    function doApprove(address spender, uint value, ERC20 token) public {
        token.approve(spender, value);
    }

    function doBuy(uint id, uint buyAmt) public returns (bool success) {
        return market.buy(id, buyAmt);
    }

    function doLimitOffer(uint sellAmt, ERC20 sellGem, uint buyAmt, ERC20 buyGem, bool forceSellAmt, uint pos) public returns (uint) {
        return market.limitOffer(sellAmt, sellGem, buyAmt, buyGem, forceSellAmt, pos);
    }

    function doCancel(uint id) public returns (bool success) {
        return market.cancel(id);
    }

    function getMarket() public view returns (MatchingMarket) {
        return market;
    }
}

contract OrderMatchingGasTest is DSTest {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    ERC20 dgd;
    MatchingMarket otc;
    uint offerCount = 200;
    mapping(uint => uint) offer;
    uint[] matchCount = [1,5,10,15,20,25,30,50,100];

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
        user1.doApprove(otc, DAI_SUPPLY / 3, dai);
        mkr.approve(otc, MKR_SUPPLY);
        dai.approve(otc, DAI_SUPPLY);
        //setup offers that will be matched later
        //determine how much dai, mkr must be bought and sold
        //to match a certain number(matchCount) of offers
    }

    // non overflowing multiplication
    function safeMul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        assert(a == 0 || c / a == b);
    }

    function insertOffer(uint sellAmt, ERC20 sellGem, uint buyAmt, ERC20 buyGem) public logs_gas {
        otc.limitOffer(sellAmt, sellGem, buyAmt, buyGem, false, 0);
    }

    //insert single offer
    function insertOffer(uint sellAmt, ERC20 sellGem, uint buyAmt, ERC20 buyGem, uint pos) public logs_gas {
        otc.limitOffer(sellAmt, sellGem, buyAmt, buyGem, false, pos);
    }

    //creates offerCount number of offers of increasing price
    function createOffers(uint offerCount_) public {
        for(uint offerIndex = 0; offerIndex < offerCount_; offerIndex++) {
            offer[offerIndex] = user1.doLimitOffer(offerIndex+1, dai, 1, mkr, false, 0);
        }
    }

    // Creates test to match matchOrderCount number of orders
    function execOrderMatchingGasTest(uint matchOrderCount) public {
        uint mkrSell;
        uint daiBuy;
        offerCount = matchOrderCount + 1;

        createOffers(offerCount);
        daiBuy = safeMul(offerCount, offerCount + 1) / 2;
        mkrSell = daiBuy;

        insertOffer(mkrSell, mkr, daiBuy, dai);
        assertEq(otc.span(dai,mkr), 0);
    }

    /*Test the gas usage of inserting one offer.
    Creates offerIndex amount of offers of decreasing price then it
    logs the gas usage of inserting one additional offer. This
    function is useful to test the cost of sorting in order to do
    offer matching.*/
    function execOrderInsertGasTest(uint offerIndex, uint kind) public {
        createOffers(offerIndex + 1);
        if (kind == 0) {                // no frontend aid
            insertOffer(1, dai, 1, mkr);
            assertEq(otc.span(dai,mkr), offerIndex + 2);
        } else if (kind == 1) {         // with frontend aid
            insertOffer(1, dai, 1, mkr, 1);
            assertEq(otc.span(dai,mkr), offerIndex + 2);
        } else if (kind == 2) {          // with frontend aid outdated pos new offer is better 
            user1.doCancel(2);
            insertOffer(2, dai, 1, mkr, 2);
            assertEq(otc.span(dai,mkr), offerIndex + 1);
        } else if (kind == 3) {          // with frontend aid outdated pos new offer is worse
            user1.doCancel(3);
            insertOffer(2, dai, 1, mkr, 2);
            assertEq(otc.span(dai,mkr), offerIndex + 1);
        }    
    }

    function testGasMatchOneOrder() public {
        uint matchOrderCount = matchCount[0]; // 1
        execOrderMatchingGasTest(matchOrderCount);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMatchFiveOrders() public {
        uint matchOrderCount = matchCount[1]; // 5
        execOrderMatchingGasTest(matchOrderCount);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMatchTenOrders() public {
        uint matchOrderCount = matchCount[2]; // 10
        execOrderMatchingGasTest(matchOrderCount);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMatchFifteenOrders() public {
        uint matchOrderCount = matchCount[3]; // 15
        execOrderMatchingGasTest(matchOrderCount);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMatchTwentyOrders() public {
        uint matchOrderCount = matchCount[4]; // 20
        execOrderMatchingGasTest(matchOrderCount);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMatchTwentyfiveOrders() public {
        uint matchOrderCount = matchCount[5]; // 25
        execOrderMatchingGasTest(matchOrderCount);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMatchThirtyOrders() public {
        uint matchOrderCount = matchCount[6]; // 30
        execOrderMatchingGasTest(matchOrderCount);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMatchFiftyOrders() public {
        uint matchOrderCount = matchCount[7]; // 50
        execOrderMatchingGasTest(matchOrderCount);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMatchHundredOrders() public {
        uint matchOrderCount = matchCount[8]; // 100
        execOrderMatchingGasTest(matchOrderCount);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsFirstNoFrontendAid() public {
        uint offerIndex = 1 - 1;
        execOrderInsertGasTest(offerIndex, 0);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsFirstWithFrontendAid() public {
        uint offerIndex = 1 - 1;
        execOrderInsertGasTest(offerIndex, 1);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTenthNoFrontendAid() public {
        uint offerIndex = 10 - 1;
        execOrderInsertGasTest(offerIndex, 0);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTenthWithFrontendAid() public {
        uint offerIndex = 10 - 1;
        execOrderInsertGasTest(offerIndex, 1);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTenthWithFrontendAidOldPos() public {
        uint offerIndex = 10 - 1;
        execOrderInsertGasTest(offerIndex, 2);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTenthWithFrontendAidOldPosWorse() public {
        uint offerIndex = 10 - 1;
        execOrderInsertGasTest(offerIndex, 3);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTwentiethNoFrontendAid() public {
        uint offerIndex = 20 - 1;
        execOrderInsertGasTest(offerIndex, 0);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTwentiethWithFrontendAid() public {
        uint offerIndex = 20 - 1;
        execOrderInsertGasTest(offerIndex, 1);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTwentiethWithFrontendAidOldPos() public {
        uint offerIndex = 20 - 1;
        execOrderInsertGasTest(offerIndex, 2);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTwentiethWithFrontendAidOldPosWorse() public {
        uint offerIndex = 20 - 1;
        execOrderInsertGasTest(offerIndex, 3);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsFiftiethNoFrontendAid() public {
        uint offerIndex = 50 - 1;
        execOrderInsertGasTest(offerIndex, 0);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsFiftiethWithFrontendAid() public {
        uint offerIndex = 50 - 1;
        execOrderInsertGasTest(offerIndex, 1);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsFiftiethWithFrontendAidOldPos() public {
        uint offerIndex = 50 - 1;
        execOrderInsertGasTest(offerIndex, 2);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsFiftiethWithFrontendAidOldPosWorse() public {
        uint offerIndex = 50 - 1;
        execOrderInsertGasTest(offerIndex, 3);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsHundredthNoFrontendAid() public {
        uint offerIndex = 100 - 1;
        execOrderInsertGasTest(offerIndex, 0);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsHundredthWithFrontendAid() public {
        uint offerIndex = 100 - 1;
        execOrderInsertGasTest(offerIndex, 1);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsHundredthWithFrontendAidOldPos() public {
        uint offerIndex = 100 - 1;
        execOrderInsertGasTest(offerIndex, 2);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsHundredthWithFrontendAidOldPoWorses() public {
        uint offerIndex = 100 - 1;
        execOrderInsertGasTest(offerIndex, 3);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTwohundredthNoFrontendAid() public {
        uint offerIndex = 200 -1;
        execOrderInsertGasTest(offerIndex, 0);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTwohundredthWithFrontendAid() public {
        uint offerIndex = 200 -1;
        execOrderInsertGasTest(offerIndex, 1);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTwohundredthWithFrontendAidOldPos() public {
        uint offerIndex = 200 -1;
        execOrderInsertGasTest(offerIndex, 2);
        // uncomment following line to run this test!
        // assert(false);
    }

    function testGasMakeOfferInsertAsTwohundredthWithFrontendAidOldPosWorse() public {
        uint offerIndex = 200 -1;
        execOrderInsertGasTest(offerIndex, 3);
        // uncomment following line to run this test!
        // assert(false);
    }
}
contract OrderMatchingTest is DSTest, EventfulMarket, MatchingEvents {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    ERC20 dgd;
    MatchingMarket otc;
    mapping(uint => uint) offerId;
    uint buyAmt;
    uint sellAmt;
    uint buyAmt1;
    uint sellAmt1;
    ERC20 sellGem;
    ERC20 buyGem;
    ERC20 sellGem1;
    ERC20 buyGem1;

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

    function testDustMakerOfferCanceled() public {
        dai.transfer(user1, 30);
        user1.doApprove(otc, 30, dai);
        mkr.approve(otc, 25);
        otc.setDustLimit(dai, 10);
        uint id0 = user1.doLimitOffer(30, dai, 30, mkr, false, 0);
        uint id1 = otc.limitOffer(25, mkr, 25, dai, false, 0);
        assert(!otc.isActive(id0));
        assert(!otc.isActive(id1));
    }

    function testBuyDustOfferCanceled() public {
        dai.transfer(user1, 30);
        user1.doApprove(otc, 30, dai);
        mkr.approve(otc, 25);
        otc.setDustLimit(dai, 10);
        uint id0 = user1.doLimitOffer(30, dai, 30, mkr, false, 0);
        otc.buy(id0, 25);
        assert(!otc.isActive(id0));
    }

    function testDustTakerOfferNotCreated() public {
        dai.transfer(user1, 25);
        user1.doApprove(otc, 25, dai);
        mkr.approve(otc, 30);
        otc.setDustLimit(mkr, 10);
        uint id0 = user1.doLimitOffer(25, dai, 25, mkr, false, 0);
        uint id1 = otc.limitOffer(30, mkr, 30, dai, false, 0);
        assert(!otc.isActive(id0));
        assert(id1 == 0);
    }

    function testFailTooBigOffersToMatch() public {
        uint makerSell = uint128(-1);
        uint makerBuy = uint64(-1);
        uint takerSell = uint128(-1);
        uint takerBuy = uint64(-1);
        dai.transfer(user1, makerSell);
        user1.doApprove(otc, makerSell, dai);
        mkr.approve(otc, takerSell);
        otc.setDustLimit(mkr, takerSell);
        user1.doLimitOffer(makerSell, dai, makerBuy, mkr, false, 0);
        // the below should fail at matching because of overflow
        otc.limitOffer(takerSell, mkr, takerBuy, dai, false, 0);
    }

    function testGetFirstNextUnsortedOfferAfterInsertOne() public {
        mkr.approve(otc, 90);
        offerId[1] = otc.offer(30, mkr, 100, dai);
        offerId[2] = otc.offer(30, mkr, 100, dai);
        offerId[3] = otc.offer(30, mkr, 100, dai);
        otc.insert(offerId[3], 0);
        assertEq(otc.best(mkr, dai), offerId[3]);
    }

    function testGetFirstNextUnsortedOfferAfterInsertTwo() public {
        mkr.approve(otc, 90);
        offerId[1] = otc.offer(30, mkr, 100, dai);
        offerId[2] = otc.offer(30, mkr, 100, dai);
        offerId[3] = otc.offer(30, mkr, 100, dai);
        otc.insert(offerId[3],0);
        otc.insert(offerId[2],0);
        assertEq(otc.best(mkr, dai), offerId[3]);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[2]);
    }

    function testGetFirstNextUnsortedOfferAfterInsertTheree() public {
        mkr.approve(otc, 90);
        offerId[1] = otc.offer(30, mkr, 100, dai);
        offerId[2] = otc.offer(30, mkr, 100, dai);
        offerId[3] = otc.offer(30, mkr, 100, dai);
        otc.insert(offerId[3],0);
        otc.insert(offerId[2],0);
        otc.insert(offerId[1],0);
        assertEq(otc.best(mkr, dai), offerId[3]);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
    }

    function testFailInsertOfferThatIsAlreadyInTheSortedList() public {
        mkr.approve(otc, 30);
        offerId[1] = otc.limitOffer(30, mkr, 100, dai, false, 0);
        otc.insert(offerId[1],0);
        otc.insert(offerId[1],0);
    }

    function testFailInsertOfferThatHasWrongInserPosition() public {
        mkr.approve(otc, 30);
        offerId[1] = otc.limitOffer(30, mkr, 100, dai, false, 0);
        otc.insert(offerId[1],7);  //there is no active offer at pos 7
    }

    function testSetGetDustLimitAmout() public {
        otc.setDustLimit(dai, 100);
        assertEq(otc.dust(dai), 100);
    }

    function testFailOfferSellsLessThanRequired() public {
        mkr.approve(otc, 30);
        otc.setDustLimit(mkr, 31);
        assertEq(otc.dust(mkr), 31);
        offerId[1] = otc.limitOffer(30, mkr, 100, dai, false, 0);
    }

    function testFailNonOwnerCanNotSetSellAmount() public {
        user1.doSetDustLimitAmount(dai,100);
    }

    function testOfferSellsMoreThanOrEqualThanRequired() public {
        mkr.approve(otc, 30);
        otc.setDustLimit(mkr,30);
        assertEq(otc.dust(mkr), 30);
        offerId[1] = otc.limitOffer(30, mkr, 90, dai, false, 0);
    }

    function testErroneousUserHigherIdStillWorks() public {
        dai.transfer(user1, 10);
        user1.doApprove(otc, 10, dai);
        offerId[1] = user1.doLimitOffer(1, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(2, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(4, dai, 1, mkr, false, 0);
        offerId[4] = user1.doLimitOffer(3, dai, 1, mkr, false, offerId[2]);
    }

    function testErroneousUserHigherIdStillWorksOther() public {
        dai.transfer(user1, 11);
        user1.doApprove(otc, 11, dai);
        offerId[1] = user1.doLimitOffer(2, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(3, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(5, dai, 1, mkr, false, 0);
        offerId[4] = user1.doLimitOffer(1, dai, 1, mkr, false, offerId[3]);
    }
    
    function testNonExistentOffersPosStillWorks() public {
        dai.transfer(user1, 10);
        user1.doApprove(otc, 10, dai);
        uint nonExistentOfferId = 4;
        offerId[1] = user1.doLimitOffer(1, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(2, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(4, dai, 1, mkr, false, 0);
        offerId[4] = user1.doLimitOffer(3, dai, 1, mkr, false, nonExistentOfferId);
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
        otc.limitOffer(1504155374, dgd, 18501111110000000000, dai, false, 0);

        uint oldDAIBal = dai.balanceOf(user1);
        uint oldDGDBal = dgd.balanceOf(user1);
        uint DAISell = 1230000000000000000;
        uint DGDBuy = 100000000;

        // `false` and `true` both allow rounding to a slightly higher price
        // in order to find a match.
        user1.doLimitOffer(DAISell, dai, DGDBuy, dgd, false, 0);

        // We should have paid a bit more than we offered to pay.
        uint expectedOverpay = 651528437;
        assertEq(dgd.balanceOf(user1) - oldDGDBal, DGDBuy);
        assertEq(oldDAIBal - dai.balanceOf(user1), DAISell + expectedOverpay);
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
        otc.limitOffer(1504155374, dgd, 18501111110000000000, dai, false, 0);

        uint oldDAIBal = dai.balanceOf(user1);
        uint oldDGDBal = dgd.balanceOf(user1);
        uint DAISell = 1230000000000000000;
        uint DGDBuy = 100000000;

        // `false` and `true` both allow rounding to a slightly higher price
        // in order to find a match.
        user1.doLimitOffer(DAISell, dai, DGDBuy, dgd, false, 0);

        // We should have paid a bit more than we offered to pay.
        uint expectedOverpay = 651528437;
        assertEq(dgd.balanceOf(user1) - oldDGDBal, DGDBuy);
        assertEq(oldDAIBal - dai.balanceOf(user1), DAISell + expectedOverpay);
    }

    function testBestOfferWithOneOffer() public {
        dai.transfer(user1, 1);
        user1.doApprove(otc, 1, dai);
        offerId[1] = user1.doLimitOffer(1, dai, 1, mkr, false, 0);

        assertEq(otc.best(dai, mkr), offerId[1]);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.span(dai, mkr), 1);
    }

    function testBestOfferWithOneOfferWithUserprovidedId() public {
        dai.transfer(user1, 1);
        user1.doApprove(otc, 1, dai);
        offerId[1] = user1.doLimitOffer(1, dai, 1, mkr, false, 0);

        assertEq(otc.best(dai, mkr), offerId[1]);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.span(dai, mkr), 1);
    }

    function testBestOfferWithTwoOffers() public {
        dai.transfer(user1, 25);
        user1.doApprove(otc, 25, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(15, dai, 1, mkr, false, 0);

        assertEq(otc.best(dai, mkr), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.span(dai, mkr), 2);
    }

    function testBestOfferWithTwoOffersWithUserprovidedId() public {
        dai.transfer(user1, 25);
        user1.doApprove(otc, 25, dai);
        offerId[2] = user1.doLimitOffer(15, dai, 1, mkr, false, 0);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, offerId[2]);

        assertEq(otc.best(dai, mkr), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.span(dai, mkr), 2);
    }

    function testBestOfferWithThreeOffers() public {
        dai.transfer(user1, 37);
        user1.doApprove(otc, 37, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(15, dai, 1, mkr, false, 0);

        assertEq(otc.best(dai, mkr), offerId[3]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[3]), 0);
        assertEq(otc.span(dai, mkr), 3);
    }

    function testBestOfferWithThreeOffersMixed() public {
        dai.transfer(user1, 37);
        user1.doApprove(otc, 37, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(15, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);

        assertEq(otc.best(dai, mkr), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[3]);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[1]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[3]), offerId[2]);
        assertEq(otc.span(dai, mkr), 3);
    }

    function testBestOfferWithThreeOffersMixedWithUserProvidedId() public {
        dai.transfer(user1, 37);
        user1.doApprove(otc, 37, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(15, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(12, dai, 1, mkr, false, offerId[2]);

        assertEq(otc.best(dai, mkr), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[3]);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[1]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[3]), offerId[2]);
        assertEq(otc.span(dai, mkr), 3);
    }

    function testBestOfferWithFourOffersDeleteBetween() public {
        dai.transfer(user1, 53);
        user1.doApprove(otc, 53, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(15, dai, 1, mkr, false, 0);
        offerId[4] = user1.doLimitOffer(16, dai, 1, mkr, false, 0);

        assertEq(otc.best(dai, mkr), offerId[4]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[4]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[3]), offerId[4]);
        assertEq(otc.getBetterOffer(offerId[4]), 0);
        assertEq(otc.span(dai, mkr), 4);

        user1.doCancel(offerId[3]);
        assertEq(otc.best(dai, mkr), offerId[4]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[3]), 0);
        assertEq(otc.getWorseOffer(offerId[4]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), offerId[4]);
        assertEq(otc.getBetterOffer(offerId[3]), 0);
        assertEq(otc.getBetterOffer(offerId[4]), 0);
        assertEq(otc.span(dai, mkr), 3);
    }

    function testBestOfferWithFourOffersWithUserprovidedId() public {
        dai.transfer(user1, 53);
        user1.doApprove(otc, 53, dai);
        offerId[4] = user1.doLimitOffer(16, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(15, dai, 1, mkr, false, offerId[4]);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, offerId[3]);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, offerId[2]);

        assertEq(otc.best(dai, mkr), offerId[4]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[4]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[3]), offerId[4]);
        assertEq(otc.getBetterOffer(offerId[4]), 0);
        assertEq(otc.span(dai, mkr), 4);
    }

    function testBestOfferWithFourOffersTwoSamePriceUserProvidedId() public {
        dai.transfer(user1, 50);
        user1.doApprove(otc, 50, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        offerId[4] = user1.doLimitOffer(16, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(12, dai, 1, mkr, false, offerId[2]);

        assertEq(otc.best(dai, mkr), offerId[4]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[3]);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[4]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[2]), offerId[4]);
        assertEq(otc.getBetterOffer(offerId[3]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[4]), 0);
        assertEq(otc.span(dai, mkr), 4);
    }

    function testBestOfferWithTwoOffersDeletedLowest() public {
        dai.transfer(user1, 22);
        user1.doApprove(otc, 22, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[1]);

        assertEq(otc.best(dai, mkr), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.span(dai,mkr), 1);
        assert(!otc.isActive(offerId[1]));
    }

    function testBestOfferWithTwoOffersDeletedHighest() public {
        dai.transfer(user1, 22);
        user1.doApprove(otc, 22, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[2]);

        assertEq(otc.best(dai, mkr), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.span(dai, mkr), 1);
        assert(!otc.isActive(offerId[2]));
    }

    function testBestOfferWithThreeOffersDeletedLowest() public {
        dai.transfer(user1, 36);
        user1.doApprove(otc, 36, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(14, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[1]);
        assertEq(otc.best(dai, mkr), offerId[3]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), 0);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[2]);

        // make sure we retained our offer information.
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getBetterOffer(offerId[2]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[3]), 0);
        assertEq(otc.span(dai, mkr), 2);
        assert(!otc.isActive(offerId[1]));
    }

    function testBestOfferWithThreeOffersDeletedHighest() public {
        dai.transfer(user1, 36);
        user1.doApprove(otc, 36, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(14, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[3]);
        assertEq(otc.best(dai, mkr), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[3]), 0);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[3]), 0);
        assertEq(otc.span(dai, mkr), 2);
        assert(!otc.isActive(offerId[3]));

        expectEventsExact(otc);
        emit LogItemUpdate(offerId[1]);
        emit LogItemUpdate(offerId[2]);
        emit LogItemUpdate(offerId[3]);
        emit LogItemUpdate(offerId[3]);
    }

    function testBestOfferWithTwoOffersWithDifferentTokens() public {
        dai.transfer(user1, 2);
        user1.doApprove(otc, 2, dai);
        offerId[1] = user1.doLimitOffer(1, dai, 1, dgd, false, 0);
        offerId[2] = user1.doLimitOffer(1, dai, 1, mkr, false, 0);
        assertEq(otc.best(dai, dgd), offerId[1]);
        assertEq(otc.best(dai, mkr), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), 0);
        assertEq(otc.span(dai, dgd), 1);
        assertEq(otc.span(dai, mkr), 1);
    }

    function testBestOfferWithFourOffersWithDifferentTokens() public {
        dai.transfer(user1, 55);
        user1.doApprove(otc, 55, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(16, dai, 1, dgd, false, 0);
        offerId[4] = user1.doLimitOffer(17, dai, 1, dgd, false, 0);

        assertEq(otc.best(dai, mkr), offerId[2]);
        assertEq(otc.best(dai, dgd), offerId[4]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[3]), offerId[4]);
        assertEq(otc.getBetterOffer(offerId[4]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[3]), 0);
        assertEq(otc.getWorseOffer(offerId[4]), offerId[3]);
        assertEq(otc.span(dai, mkr), 2);
        assertEq(otc.span(dai, dgd), 2);
    }

    function testBestOfferWithSixOffersWithDifferentTokens() public {
        dai.transfer(user1, 88);
        user1.doApprove(otc, 88, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(15, dai, 1, mkr, false, 0);
        offerId[4] = user1.doLimitOffer(16, dai, 1, dgd, false, 0);
        offerId[5] = user1.doLimitOffer(17, dai, 1, dgd, false, 0);
        offerId[6] = user1.doLimitOffer(18, dai, 1, dgd, false, 0);

        assertEq(otc.best(dai, mkr), offerId[3]);
        assertEq(otc.best(dai, dgd), offerId[6]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[3]), 0);
        assertEq(otc.getBetterOffer(offerId[4]), offerId[5]);
        assertEq(otc.getBetterOffer(offerId[5]), offerId[6]);
        assertEq(otc.getBetterOffer(offerId[6]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[4]), 0);
        assertEq(otc.getWorseOffer(offerId[5]), offerId[4]);
        assertEq(otc.getWorseOffer(offerId[6]), offerId[5]);
        assertEq(otc.span(dai, mkr), 3);
        assertEq(otc.span(dai, dgd), 3);
    }

    function testBestOfferWithEightOffersWithDifferentTokens() public {
        dai.transfer(user1, 106);
        user1.doApprove(otc, 106, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(15, dai, 1, mkr, false, 0);
        offerId[4] = user1.doLimitOffer(16, dai, 1, mkr, false, 0);
        offerId[5] = user1.doLimitOffer(10, dai, 1, dgd, false, 0);
        offerId[6] = user1.doLimitOffer(12, dai, 1, dgd, false, 0);
        offerId[7] = user1.doLimitOffer(15, dai, 1, dgd, false, 0);
        offerId[8] = user1.doLimitOffer(16, dai, 1, dgd, false, 0);

        assertEq(otc.best(dai, mkr), offerId[4]);
        assertEq(otc.best(dai, dgd), offerId[8]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[3]), offerId[4]);
        assertEq(otc.getBetterOffer(offerId[4]), 0);
        assertEq(otc.getBetterOffer(offerId[5]), offerId[6]);
        assertEq(otc.getBetterOffer(offerId[6]), offerId[7]);
        assertEq(otc.getBetterOffer(offerId[7]), offerId[8]);
        assertEq(otc.getBetterOffer(offerId[8]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[4]), offerId[3]);
        assertEq(otc.getWorseOffer(offerId[5]), 0);
        assertEq(otc.getWorseOffer(offerId[6]), offerId[5]);
        assertEq(otc.getWorseOffer(offerId[7]), offerId[6]);
        assertEq(otc.getWorseOffer(offerId[8]), offerId[7]);
        assertEq(otc.span(dai, mkr), 4);
        assertEq(otc.span(dai, dgd), 4);
    }

    function testBestOfferWithFourOffersWithDifferentTokensLowHighDeleted() public {
        dai.transfer(user1, 29);
        user1.doApprove(otc, 39, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[1]);
        offerId[3] = user1.doLimitOffer(8, dai, 1, dgd, false, 0);
        offerId[4] = user1.doLimitOffer(9, dai, 1, dgd, false, 0);
        user1.doCancel(offerId[3]);

        assertEq(otc.best(dai, mkr), offerId[2]);
        assertEq(otc.best(dai, dgd), offerId[4]);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[3]), 0);
        assertEq(otc.getBetterOffer(offerId[4]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), 0);
        assertEq(otc.getWorseOffer(offerId[3]), 0);
        assertEq(otc.getWorseOffer(offerId[4]), 0);
        assertEq(otc.span(dai,mkr), 1);
        assertEq(otc.span(dai,dgd), 1);
        assert(!otc.isActive(offerId[1]));
        assert(!otc.isActive(offerId[3]));
    }

    function testBestOfferWithFourOffersWithDifferentTokensHighLowDeleted() public {
        dai.transfer(user1, 27);
        user1.doApprove(otc, 39, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[2]);
        offerId[3] = user1.doLimitOffer(8, dai, 1, dgd, false, 0);
        offerId[4] = user1.doLimitOffer(9, dai, 1, dgd, false, 0);
        user1.doCancel(offerId[4]);
        assertEq(otc.best(dai, mkr), offerId[1]);
        assertEq(otc.best(dai, dgd), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[3]), 0);
        assertEq(otc.getBetterOffer(offerId[4]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), 0);
        assertEq(otc.getWorseOffer(offerId[3]), 0);
        assertEq(otc.getWorseOffer(offerId[4]), 0);
        assertEq(otc.span(dai,mkr), 1);
        assertEq(otc.span(dai,dgd), 1);
        assert(!otc.isActive(offerId[2]));
        assert(!otc.isActive(offerId[4]));
    }

    function testBestOfferWithSixOffersWithDifferentTokensLowHighDeleted() public {
        dai.transfer(user1, 78);
        user1.doApprove(otc, 88, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(15, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[1]);
        offerId[4] = user1.doLimitOffer(16, dai, 1, dgd, false, 0);
        offerId[5] = user1.doLimitOffer(17, dai, 1, dgd, false, 0);
        offerId[6] = user1.doLimitOffer(18, dai, 1, dgd, false, 0);
        user1.doCancel(offerId[6]);

        assertEq(otc.best(dai, mkr), offerId[3]);
        assertEq(otc.best(dai, dgd), offerId[5]);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getBetterOffer(offerId[2]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[3]), 0);
        assertEq(otc.getBetterOffer(offerId[4]), offerId[5]);
        assertEq(otc.getBetterOffer(offerId[5]), 0);
        assertEq(otc.getBetterOffer(offerId[6]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), 0);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[2]);
        assertEq(otc.getWorseOffer(offerId[4]), 0);
        assertEq(otc.getWorseOffer(offerId[5]), offerId[4]);
        assertEq(otc.getWorseOffer(offerId[6]), 0);
        assertEq(otc.span(dai,mkr), 2);
        assertEq(otc.span(dai,dgd), 2);
        assert(!otc.isActive(offerId[1]));
        assert(!otc.isActive(offerId[6]));
    }

    function testBestOfferWithSixOffersWithDifferentTokensHighLowDeleted() public {
        dai.transfer(user1, 73);
        user1.doApprove(otc, 88, dai);
        offerId[1] = user1.doLimitOffer(10, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(12, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(15, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[3]);
        offerId[4] = user1.doLimitOffer(16, dai, 1, dgd, false, 0);
        offerId[5] = user1.doLimitOffer(17, dai, 1, dgd, false, 0);
        offerId[6] = user1.doLimitOffer(18, dai, 1, dgd, false, 0);
        user1.doCancel(offerId[4]);

        assertEq(otc.best(dai, mkr), offerId[2]);
        assertEq(otc.best(dai, dgd), offerId[6]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[3]), 0); // was best when cancelled
        assertEq(otc.getBetterOffer(offerId[4]), 0);
        assertEq(otc.getBetterOffer(offerId[5]), offerId[6]);
        assertEq(otc.getBetterOffer(offerId[6]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[3]), 0);
        assertEq(otc.getWorseOffer(offerId[4]), 0);
        assertEq(otc.getWorseOffer(offerId[5]), 0);
        assertEq(otc.getWorseOffer(offerId[6]), offerId[5]);
        assertEq(otc.span(dai, mkr), 2);
        assertEq(otc.span(dai, dgd), 2);
        assert(!otc.isActive(offerId[3]));
        assert(!otc.isActive(offerId[4]));
    }

    function testInsertOfferWithUserProvidedIdOfADifferentToken() public {
        dai.transfer(user1, 13);
        user1.doApprove(otc, 13, dai);
        dai.approve(otc, 11);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = otc.limitOffer(11, dai, 1, dgd, false, offerId[1]);
        assert(otc.getBetterOffer(offerId[2]) == 0);
        assert(otc.getWorseOffer(offerId[2]) == 0);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToHighestWrongPos() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[1]);
        offerId[4] = otc.limitOffer(14, dai, 1, mkr, false, offerId[1]);
        assert(otc.getBetterOffer(offerId[4]) == 0);
        assert(otc.getWorseOffer(offerId[4]) == offerId[2]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToBetweenWrongPos() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[2]);
        offerId[4] = otc.limitOffer(14, dai, 1, mkr, false, offerId[2]);
        assert(otc.getBetterOffer(offerId[4]) == 0);
        assert(otc.getWorseOffer(offerId[4]) == offerId[1]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToLowestWrongPos() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[3]);
        offerId[4] = otc.limitOffer(14, dai, 1, mkr, false, offerId[3]);
        assert(otc.getBetterOffer(offerId[4]) == 0);
        assert(otc.getWorseOffer(offerId[4]) == offerId[1]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToHighestWrongPosLowest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 7);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[1]);
        offerId[4] = otc.limitOffer(7, dai, 1, mkr, false, offerId[1]);
        assert(otc.getBetterOffer(offerId[4]) == offerId[3]);
        assert(otc.getWorseOffer(offerId[4]) == 0);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToBetweenWrongPosLowest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 7);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[2]);
        offerId[4] = otc.limitOffer(7, dai, 1, mkr, false, offerId[2]);
        assert(otc.getBetterOffer(offerId[4]) == offerId[3]);
        assert(otc.getWorseOffer(offerId[4]) == 0);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToLowestWrongPosLowest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 7);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[3]);
        offerId[4] = otc.limitOffer(7, dai, 1, mkr, false, offerId[3]);
        assert(otc.getBetterOffer(offerId[4]) == offerId[2]);
        assert(otc.getWorseOffer(offerId[4]) == 0);
    }
    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToHighest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 12);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[1]);
        offerId[4] = otc.limitOffer(12, dai, 1, mkr, false, offerId[1]);
        assert(otc.getBetterOffer(offerId[4]) == 0);
        assert(otc.getWorseOffer(offerId[4]) == offerId[2]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToBetween() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 10);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[2]);
        offerId[4] = otc.limitOffer(10, dai, 1, mkr, false, offerId[2]);
        assert(otc.getBetterOffer(offerId[4]) == offerId[1]);
        assert(otc.getWorseOffer(offerId[4]) == offerId[3]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToLowest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 8);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[3]);
        offerId[4] = otc.limitOffer(8, dai, 1, mkr, false, offerId[3]);
        assert(otc.getBetterOffer(offerId[4]) == offerId[2]);
        assert(otc.getWorseOffer(offerId[4]) == 0);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToHighestWrongPosHighest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[1]);
        offerId[4] = otc.limitOffer(14, dai, 1, mkr, false, offerId[1]);
        assert(otc.getBetterOffer(offerId[4]) == 0);
        assert(otc.getWorseOffer(offerId[4]) == offerId[2]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToBetweenWrongPosHighest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[2]);
        offerId[4] = otc.limitOffer(14, dai, 1, mkr, false, offerId[2]);
        assert(otc.getBetterOffer(offerId[4]) == 0);
        assert(otc.getWorseOffer(offerId[4]) == offerId[1]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToLowestWrongPosHighest() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 14);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[3]);
        offerId[4] = otc.limitOffer(14, dai, 1, mkr, false, offerId[3]);
        assert(otc.getBetterOffer(offerId[4]) == 0);
        assert(otc.getWorseOffer(offerId[4]) == offerId[1]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToHighestWrongPosBetween() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 10);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[1]);
        offerId[4] = otc.limitOffer(10, dai, 1, mkr, false, offerId[1]);
        assert(otc.getBetterOffer(offerId[4]) == offerId[2]);
        assert(otc.getWorseOffer(offerId[4]) == offerId[3]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToBetweenWrongPosBetween() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 10);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[2]);
        offerId[4] = otc.limitOffer(10, dai, 1, mkr, false, offerId[2]);
        assert(otc.getBetterOffer(offerId[4]) == offerId[1]);
        assert(otc.getWorseOffer(offerId[4]) == offerId[3]);
    }

    function testInsertOfferWithUserProvidedIdOfASameTokenHigherToLowestWrongPosBetween() public {
        dai.transfer(user1, 33);
        user1.doApprove(otc, 33, dai);
        dai.approve(otc, 10);
        offerId[1] = user1.doLimitOffer(13, dai, 1, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(11, dai, 1, mkr, false, 0);
        offerId[3] = user1.doLimitOffer(9, dai, 1, mkr, false, 0);
        user1.doCancel(offerId[3]);
        offerId[4] = otc.limitOffer(10, dai, 1, mkr, false, offerId[3]);
        assert(otc.getBetterOffer(offerId[4]) == offerId[2]);
        assert(otc.getWorseOffer(offerId[4]) == 0);
    }

    function testOfferMatchOneOnOneSendAmounts() public {
        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);

        uint myMKRBalanceBefore = mkr.balanceOf(this);
        uint myDAIBalanceBefore = dai.balanceOf(this);
        uint user1MKRBalanceBefore = mkr.balanceOf(user1);
        uint user1DAIBalanceBefore = dai.balanceOf(user1);

        offerId[1] = otc.limitOffer(30, mkr, 100, dai, false, 0);
        offerId[2] = user1.doLimitOffer(100, dai, 30, mkr, false, 0);
        uint myMKRBalanceAfter = mkr.balanceOf(this);
        uint myDAIBalanceAfter = dai.balanceOf(this);
        uint user1MKRBalanceAfter = mkr.balanceOf(user1);
        uint user1DAIBalanceAfter = dai.balanceOf(user1);
        assertEq(myMKRBalanceBefore - myMKRBalanceAfter, 30);
        assertEq(myDAIBalanceAfter - myDAIBalanceBefore, 100);
        assertEq(user1MKRBalanceAfter - user1MKRBalanceBefore, 30);
        assertEq(user1DAIBalanceBefore - user1DAIBalanceAfter, 100);

        /* //REPORTS FALSE ERROR:
        expectEventsExact(otc);
        emit LogItemUpdate(offerId[1]);
        emit LogItemUpdate(offerId[1]);
        emit LogItemUpdate(offerId[2]);*/
    }
    function testOfferMatchOneOnOnePartialSellSendAmounts() public {
        dai.transfer(user1, 50);
        user1.doApprove(otc, 50, dai);
        mkr.approve(otc, 200);

        uint myMKRBalanceBefore = mkr.balanceOf(this);
        uint myDAIBalanceBefore = dai.balanceOf(this);
        uint user1MKRBalanceBefore = mkr.balanceOf(user1);
        uint user1DAIBalanceBefore = dai.balanceOf(user1);

        offerId[1] = otc.limitOffer(200, mkr, 500, dai, false, 0);
        offerId[2] = user1.doLimitOffer(50, dai, 20, mkr, false, 0);
        uint myMKRBalanceAfter = mkr.balanceOf(this);
        uint myDAIBalanceAfter = dai.balanceOf(this);
        uint user1MKRBalanceAfter = mkr.balanceOf(user1);
        uint user1DAIBalanceAfter = dai.balanceOf(user1);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(offerId[1]);

        assertEq(myMKRBalanceBefore - myMKRBalanceAfter, 200);
        assertEq(myDAIBalanceAfter - myDAIBalanceBefore, 50);
        assertEq(user1MKRBalanceAfter - user1MKRBalanceBefore, 20);
        assertEq(user1DAIBalanceBefore - user1DAIBalanceAfter, 50);
        assertEq(sellAmt, 180);
        assertEq(buyAmt, 450);
        assert(!otc.isActive(offerId[2]));

        /* //REPORTS FALSE ERROR:
        expectEventsExact(otc);
        emit LogItemUpdate(offerId[1]);
        emit LogItemUpdate(offerId[1]);
        emit LogItemUpdate(offerId[2]);*/
    }
    function testOfferMatchOneOnOnePartialBuySendAmounts() public {
        dai.transfer(user1, 2000);
        user1.doApprove(otc, 2000, dai);
        mkr.approve(otc, 200);

        uint myMKRBalanceBefore = mkr.balanceOf(this);
        uint myDAIBalanceBefore = dai.balanceOf(this);
        uint user1MKRBalanceBefore = mkr.balanceOf(user1);
        uint user1DAIBalanceBefore = dai.balanceOf(user1);

        offerId[1] = otc.limitOffer(200, mkr, 500, dai, false, 0);
        offerId[2] = user1.doLimitOffer(2000, dai, 800, mkr, false, 0);
        uint myMKRBalanceAfter = mkr.balanceOf(this);
        uint myDAIBalanceAfter = dai.balanceOf(this);
        uint user1MKRBalanceAfter = mkr.balanceOf(user1);
        uint user1DAIBalanceAfter = dai.balanceOf(user1);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(offerId[1]);
        (,, sellAmt1, sellGem1, buyAmt1, buyGem1,,) = otc.offers(offerId[2]);

        assertEq(myMKRBalanceBefore - myMKRBalanceAfter, 200);
        assertEq(myDAIBalanceAfter - myDAIBalanceBefore, 500);
        assertEq(user1MKRBalanceAfter - user1MKRBalanceBefore, 200);
        assertEq(user1DAIBalanceBefore - user1DAIBalanceAfter, 2000);
        assertEq(sellAmt, 0);
        assertEq(buyAmt, 0);
        assertEq(sellAmt1, 1500);
        assertEq(buyAmt1, 600);

        expectEventsExact(otc);
        emit LogItemUpdate(offerId[1]);
        emit LogItemUpdate(offerId[1]);
        emit LogItemUpdate(offerId[2]);
    }
    function testOfferMatchingOneOnOneMatch() public {
        dai.transfer(user1, 1);
        user1.doApprove(otc, 1, dai);
        mkr.approve(otc, 1);
        offerId[1] = user1.doLimitOffer(1, dai, 1, mkr, false, 0);
        offerId[2] = otc.limitOffer(1, mkr, 1, dai, false, 0);

        assertEq(otc.best(dai, mkr), 0);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.span(dai, mkr), 0);
        assert(!otc.isActive(offerId[1]));
        assert(!otc.isActive(offerId[2]));
    }
    function testOfferMatchingOneOnOneMatchCheckOfferPriceRemainsTheSame() public {
        dai.transfer(user1, 5);
        user1.doApprove(otc, 5, dai);
        mkr.approve(otc, 10);
        offerId[1] = user1.doLimitOffer(5, dai, 1, mkr, false, 0);
        offerId[2] = otc.limitOffer(10, mkr, 10, dai, false, 0);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(offerId[2]);

        assertEq(otc.best(dai, mkr), 0);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.span(dai, mkr), 0);
        assertEq(otc.span(mkr, dai), 1);
        assert(!otc.isActive(offerId[1]));
        //assert price of offerId[2] should be the same as before matching
        assertEq(sellAmt, 5);
        assertEq(buyAmt, 5);
        assert(address(sellGem) > 0x0);
        assert(address(buyGem) > 0x0);
    }
    function testOfferMatchingPartialSellTwoOffers() public {
        mkr.transfer(user1, 10);
        user1.doApprove(otc, 10, mkr);
        dai.approve(otc, 5);
        offerId[1] = user1.doLimitOffer(10, mkr, 10, dai, false, 0);
        offerId[2] = otc.limitOffer(5, dai, 5, mkr, false, 0);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(offerId[1]);

        assertEq(otc.best(dai, mkr), 0);
        assertEq(otc.best(mkr, dai), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.span(mkr, dai), 1);
        assertEq(otc.span(dai, mkr), 0);
        assert(!otc.isActive(offerId[2]));
        assertEq(sellAmt, 5);
        assertEq(buyAmt, 5);
        assert(address(sellGem) > 0x0);
        assert(address(buyGem) > 0x0);
    }
    function testOfferMatchingOneOnTwoMatchCheckOfferPriceRemainsTheSame() public {
        dai.transfer(user1, 9);
        user1.doApprove(otc, 9, dai);
        mkr.approve(otc, 10);
        offerId[1] = user1.doLimitOffer(5, dai, 1, mkr, false, 0);
        offerId[1] = user1.doLimitOffer(4, dai, 1, mkr, false, 0);
        offerId[2] = otc.limitOffer(10, mkr, 10, dai, false, 0);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(offerId[2]);

        assertEq(otc.best(dai, mkr), 0);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.span(dai, mkr), 0);
        assertEq(otc.span(mkr, dai), 1);
        assert(!otc.isActive(offerId[1]));
        //assert érice of offerId[2] should be the same as before matching
        assertEq(sellAmt, 1);
        assertEq(buyAmt, 1);
        assert(address(sellGem) > 0x0);
        assert(address(buyGem) > 0x0);
    }
    function testOfferMatchingPartialBuyTwoOffers() public {
        mkr.transfer(user1, 5);
        user1.doApprove(otc, 5, mkr);
        dai.approve(otc, 10);
        offerId[1] = user1.doLimitOffer(5, mkr, 5, dai, false, 0);
        offerId[2] = otc.limitOffer(10, dai, 10, mkr, false, 0);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(offerId[2]);

        assertEq(otc.best(dai, mkr), offerId[2]);
        assertEq(otc.best(mkr, dai), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.span(mkr, dai), 0);
        assertEq(otc.span(dai, mkr), 1);
        assert(!otc.isActive(offerId[1]));
        assertEq(sellAmt, 5);
        assertEq(buyAmt, 5);
        assert(address(sellGem) > 0x0);
        assert(address(buyGem) > 0x0);
    }
    function testOfferMatchingPartialBuyThreeOffers() public {
        mkr.transfer(user1, 15);
        user1.doApprove(otc, 15, mkr);
        dai.approve(otc, 1);
        offerId[1] = user1.doLimitOffer(5, mkr, 10, dai, false, 0);
        offerId[2] = user1.doLimitOffer(10, mkr, 10, dai, false, 0);
        offerId[3] = otc.limitOffer(1, dai, 1, mkr, false, 0);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(offerId[1]);
        (,, sellAmt1, sellGem1, buyAmt1, buyGem1,,) = otc.offers(offerId[2]);

        assertEq(otc.best(mkr, dai), offerId[2]);
        assertEq(otc.best(dai, mkr), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), offerId[1]);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[2]);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.span(mkr, dai), 2);
        assertEq(otc.span(dai, mkr), 0);
        assert(!otc.isActive(offerId[3]));
        assertEq(sellAmt, 5);
        assertEq(buyAmt, 10);
        assertEq(sellAmt1, 9);
        assertEq(buyAmt1, 9);
        assert(address(sellGem) > 0x0);
        assert(address(buyGem) > 0x0);
        assert(address(sellGem1) > 0x0);
        assert(address(buyGem1) > 0x0);
    }
    function testOfferMatchingPartialSellThreeOffers() public {
        mkr.transfer(user1, 6);
        user1.doApprove(otc, 6, mkr);
        dai.approve(otc, 10);
        offerId[1] = user1.doLimitOffer(5, mkr, 10, dai, false, 0);
        offerId[2] = user1.doLimitOffer(1, mkr, 1, dai, false, 0);
        offerId[3] = otc.limitOffer(10, dai, 10, mkr, false, 0);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(offerId[1]);
        (,, sellAmt1, sellGem1, buyAmt1, buyGem1,,) = otc.offers(offerId[3]);

        assertEq(otc.best(mkr, dai), offerId[1]);
        assertEq(otc.best(dai, mkr), offerId[3]);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), 0);
        assertEq(otc.getWorseOffer(offerId[3]), 0);
        assertEq(otc.getBetterOffer(offerId[1]), 0);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[3]), 0);
        assertEq(otc.span(mkr, dai), 1);
        assertEq(otc.span(dai, mkr), 1);
        assert(!otc.isActive(offerId[2]));
        assertEq(sellAmt, 5);
        assertEq(buyAmt, 10);
        assertEq(sellAmt1, 9);
        assertEq(buyAmt1, 9);
        assert(address(sellGem) > 0x0);
        assert(address(buyGem) > 0x0);
        assert(address(sellGem1) > 0x0);
        assert(address(buyGem1) > 0x0);
    }
    function testOfferMatchingPartialSellThreeOffersTwoBuyThreeSell() public {
        dai.transfer(user1, 3);
        user1.doApprove(otc, 3, dai);
        mkr.approve(otc, 12);
        offerId[1] = otc.limitOffer(1, mkr, 10, dai, false, 0);
        offerId[2] = otc.limitOffer(1, mkr,  1, dai, false, 0);
        offerId[3] = otc.limitOffer(10, mkr, 10, dai, false, 0);
        offerId[4] = user1.doLimitOffer(3, dai, 3, mkr, false, 0);
        (,, sellAmt, sellGem, buyAmt, buyGem,,) = otc.offers(offerId[3]);
        (,, sellAmt1, sellGem1, buyAmt1, buyGem1,,) = otc.offers(offerId[1]);

        assertEq(otc.best(mkr, dai), offerId[3]);
        assertEq(otc.best(dai, mkr), 0);
        assertEq(otc.getWorseOffer(offerId[1]), 0);
        assertEq(otc.getWorseOffer(offerId[2]), 0);
        assertEq(otc.getWorseOffer(offerId[3]), offerId[1]);
        assertEq(otc.getWorseOffer(offerId[4]), 0);
        assertEq(otc.getBetterOffer(offerId[1]), offerId[3]);
        assertEq(otc.getBetterOffer(offerId[2]), 0);
        assertEq(otc.getBetterOffer(offerId[3]), 0);
        assertEq(otc.getBetterOffer(offerId[4]), 0);
        assertEq(otc.span(mkr, dai), 2);
        assertEq(otc.span(dai, mkr), 0);
        assert(!otc.isActive(offerId[2]));
        assert(!otc.isActive(offerId[4]));
        assertEq(sellAmt, 8);
        assertEq(buyAmt, 8);
        assertEq(sellAmt1, 1);
        assertEq(buyAmt1, 10);
        assert(address(sellGem) > 0x0);
        assert(address(buyGem) > 0x0);
        assert(address(sellGem1) > 0x0);
        assert(address(buyGem1) > 0x0);
    }

    function testSellAllDai() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.limitOffer(10 ether, mkr, 3200 ether, dai, false, 0);
        otc.limitOffer(10 ether, mkr, 2800 ether, dai, false, 0);

        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        assertEq(otc.sellAllAmount(dai, 4000 ether, mkr, expectedResult), expectedResult);

        otc.limitOffer(10 ether, mkr, 3200 ether, dai, false, 0);
        otc.limitOffer(10 ether, mkr, 2800 ether, dai, false, 0);

        // With 319 wei DAI is not possible to buy 1 wei MKR, then 319 wei DAI can not be sold
        expectedResult = 10 ether * 2800 / 2800;
        assertEq(otc.sellAllAmount(dai, 2800 ether + 319, mkr, expectedResult), expectedResult);

        otc.limitOffer(10 ether, mkr, 2800 ether, dai, false, 0);
        // This time we should be able to buy 1 wei MKR more
        expectedResult = 10 ether * 2800 / 2800 + 1;
        assertEq(otc.sellAllAmount(dai, 2800 ether + 320, mkr, expectedResult), expectedResult);
    }

    function testSellAllMkr() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.limitOffer(3200 ether, dai, 10 ether, mkr, false, 0);
        otc.limitOffer(2800 ether, dai, 10 ether, mkr, false, 0);

        uint expectedResult = 3200 ether * 10 / 10 + 2800 ether * 8 / 10;
        assertEq(otc.sellAllAmount(mkr, 18 ether, dai, expectedResult), expectedResult);
    }

    function testFailSellAllMkr() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.limitOffer(3200 ether, dai, 10 ether, mkr, false, 0);
        otc.limitOffer(2800 ether, dai, 10 ether, mkr, false, 0);

        uint expectedResult = 3200 ether * 10 / 10 + 2800 ether * 8 / 10;
        assertEq(otc.sellAllAmount(mkr, 18 ether, dai, expectedResult + 1), expectedResult);
    }

    function testBuyAllMkr() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.limitOffer(10 ether, mkr, 3200 ether, dai, false, 0);
        otc.limitOffer(10 ether, mkr, 2800 ether, dai, false, 0);

        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        assertEq(otc.buyAllAmount(mkr, 15 ether, dai, expectedResult), expectedResult);
    }

    function testBuyAllDai() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.limitOffer(3200 ether, dai, 10 ether, mkr, false, 0);
        otc.limitOffer(2800 ether, dai, 10 ether, mkr, false, 0);

        uint expectedResult = 10 ether * 3200 / 3200 + 10 ether * 1400 / 2800;
        assertEq(otc.buyAllAmount(dai, 4600 ether, mkr, expectedResult), expectedResult);
    }

    function testFailBuyAllDai() public {
        mkr.approve(otc, uint(-1));
        dai.approve(otc, uint(-1));
        otc.limitOffer(3200 ether, dai, 10 ether, mkr, false, 0);
        otc.limitOffer(2800 ether, dai, 10 ether, mkr, false, 0);

        uint expectedResult = 10 ether * 3200 / 3200 + 10 ether * 1400 / 2800;
        assertEq(otc.buyAllAmount(dai, 4600 ether, mkr, expectedResult - 1), expectedResult);
    }

    function testBuyOffers() public {
        mkr.approve(otc, uint(-1));
        user1.doApprove(otc, uint(-1), dai);
        dai.transfer(user1, 6000 ether);
        offerId[1] = user1.doLimitOffer(3200 ether, dai, 10 ether, mkr, false, 0);
        offerId[2] = user1.doLimitOffer(2800 ether, dai, 10 ether, mkr, false, 0);

        uint initialBalance = mkr.balanceOf(this);
        otc.iocOffer(20 ether, mkr, 6000 ether, dai, false);
        // Just bought one of the offers
        assertEq(mkr.balanceOf(this), initialBalance - 10 ether);
        // First offer (better price) was bought
        (,, sellAmt,, buyAmt,,,) = otc.offers(offerId[1]);
        assertEq(sellAmt, 0);
        assertEq(buyAmt, 0);
        // Second offer (worse price) was not bought
        (,, sellAmt,, buyAmt,,,) = otc.offers(offerId[2]);
        assertEq(sellAmt, 2800 ether);
        assertEq(buyAmt, 10 ether);
    }

    function div(uint x, uint y) internal pure returns (uint z) {
        z = x * 1 ether / y;
    }

    function testForceBuyAmount() public {
        mkr.approve(otc, uint(-1));
        user1.doApprove(otc, uint(-1), dai);
        dai.transfer(user1, 6000 ether);
        offerId[1] = user1.doLimitOffer(3200 ether, dai, 10 ether, mkr, false, 0); // Price: 320
        offerId[2] = user1.doLimitOffer(2800 ether, dai, 10 ether, mkr, false, 0); // Price: 280

        uint initialBalanceMKR = mkr.balanceOf(this);
        uint initialBalanceDAI = dai.balanceOf(this);
        otc.iocOffer(20 ether, mkr, 5000 ether, dai, false); // Price: 250
        assertEq(dai.balanceOf(this), initialBalanceDAI + 5000 ether);
        uint mkrSold = 10 ether + div(1800 ether * 10, 2800 ether);
        assertEq(mkr.balanceOf(this), initialBalanceMKR - mkrSold);
    }

    function testForceSellAmount() public {
        mkr.approve(otc, uint(-1));
        user1.doApprove(otc, uint(-1), dai);
        dai.transfer(user1, 6000 ether);
        offerId[1] = user1.doLimitOffer(3200 ether, dai, 10 ether, mkr, false, 0); // Price: 320
        offerId[2] = user1.doLimitOffer(2800 ether, dai, 10 ether, mkr, false, 0); // Price: 280

        uint initialBalanceMKR = mkr.balanceOf(this);
        uint initialBalanceDAI = dai.balanceOf(this);
        otc.iocOffer(20 ether, mkr, 5000 ether, dai, true); // Price: 250
        assertEq(mkr.balanceOf(this), initialBalanceMKR - 20 ether);
        assertEq(dai.balanceOf(this), initialBalanceDAI + 6000 ether);
    }

    function testForceBuyAmountOffer() public {
        mkr.approve(otc, uint(-1));
        user1.doApprove(otc, uint(-1), dai);
        dai.transfer(user1, 6000 ether);
        offerId[1] = user1.doLimitOffer(3200 ether, dai, 10 ether, mkr, false, 0); // Price: 320
        offerId[2] = user1.doLimitOffer(1400 ether, dai, 5 ether, mkr, false, 0); // Price: 280
        offerId[3] = user1.doLimitOffer(600 ether, dai, 2.5 ether, mkr, false, 0); // Price: 240

        uint initialBalanceMKR = mkr.balanceOf(this);
        uint initialBalanceDAI = dai.balanceOf(this);
        offerId[4] = otc.limitOffer(20 ether, mkr, 5000 ether, dai, false, 0); // Price: 250
        assertEq(dai.balanceOf(this), initialBalanceDAI + 4600 ether);
        (,, sellAmt,, buyAmt,,,) = otc.offers(offerId[4]);
        assertEq(buyAmt, 400 ether);
        uint offerSellAmtToBuyMissingDAI = div(400 ether * 20, 5000 ether);
        assertEq(sellAmt, offerSellAmtToBuyMissingDAI);
        assertEq(mkr.balanceOf(this), initialBalanceMKR - 15 ether - offerSellAmtToBuyMissingDAI);
    }

    function testForceSellAmountOffer() public {
        mkr.approve(otc, uint(-1));
        user1.doApprove(otc, uint(-1), dai);
        dai.transfer(user1, 6000 ether);
        offerId[1] = user1.doLimitOffer(1600 ether, dai, 5 ether, mkr, false, 0); // Price: 320
        offerId[2] = user1.doLimitOffer(1400 ether, dai, 5 ether, mkr, false, 0); // Price: 280
        offerId[3] = user1.doLimitOffer(600 ether, dai, 2.5 ether, mkr, false, 0); // Price: 240

        uint initialBalanceMKR = mkr.balanceOf(this);
        uint initialBalanceDAI = dai.balanceOf(this);
        offerId[4] = otc.limitOffer(12 ether, mkr, 3000 ether, dai, true, 0); // Price: 250
        assertEq(mkr.balanceOf(this), initialBalanceMKR - 12 ether);
        assertEq(dai.balanceOf(this), initialBalanceDAI + 3000 ether);
        (,, sellAmt,, buyAmt,,,) = otc.offers(offerId[4]);
        assertEq(sellAmt, 2 ether);
        uint offerBuyAmtToSellMissingMKR = div(2 ether * 3000, 12 ether);
        assertEq(buyAmt, offerBuyAmtToSellMissingMKR);
    }

    function testEvilOfferPositions() public {
        mkr.approve(otc, uint(-1));
        mkr.transfer(user1, 1000 ether);
        dai.transfer(user1, 1000 ether);
        user1.doApprove(otc, 1000 ether, dai);
        user1.doApprove(otc, 1000 ether, mkr);
        dai.approve(otc, 10 ether);


        offerId[1] = user1.doLimitOffer(1 ether, mkr, 301 ether, dai, false, 1);
        offerId[2] = user1.doLimitOffer(250 ether, dai, 1 ether, mkr, false, 1);
        offerId[3] = user1.doLimitOffer(280 ether, dai, 1 ether, mkr, false, 1);
        offerId[4] = user1.doLimitOffer(275 ether, dai, 1 ether, mkr, false, 1);

        uint oSellAmt;
        uint oBuyAmt;

        (oSellAmt, oBuyAmt,,,,,,) = otc.offers(offerId[1]);
        assert(oSellAmt == 1 ether && oBuyAmt == 301 ether);

        var currentId = otc.best(dai, mkr);
        (oSellAmt, oBuyAmt,,,,,,) = otc.offers(currentId);
        assert(oSellAmt == 280 ether && oBuyAmt == 1 ether);

        currentId = otc.getWorseOffer(currentId);
        (oSellAmt, oBuyAmt,,,,,,) = otc.offers(currentId);
        assert(oSellAmt == 275 ether && oBuyAmt == 1 ether);

        currentId = otc.getWorseOffer(currentId);
        (oSellAmt, oBuyAmt,,,,,,) = otc.offers(currentId);
        assert(oSellAmt == 250 ether && oBuyAmt == 1 ether);
    }
}
