pragma solidity ^0.4.8;

import "ds-test/test.sol";
import "ds-token/base.sol";

import "./matching_market.sol";

contract MarketTester {
    MatchingMarket market;
    function MarketTester(MatchingMarket  market_) {
        market = market_;
    }
    function doSetMinSellAmount(ERC20 sell_which_token, uint min_amount)
    returns (bool)
    {
        return market.setMinSell(sell_which_token, min_amount);
    }
    function doGetMinSellAmount(ERC20 sell_which_token)
    returns (uint)
    {
        return market.getMinSell(sell_which_token);
    }
    function doApprove(address spender, uint value, ERC20 token) {
        token.approve(spender, value);
    }
    function doBuy(uint id, uint buy_how_much) returns (bool _success) {
        return market.buy(id, buy_how_much);
    }
    function doOffer( uint sell_how_much, ERC20 sell_which_token
                    , uint buy_how_much,  ERC20 buy_which_token )
    returns (uint) {
        return market.offer( sell_how_much, sell_which_token
                  , buy_how_much, buy_which_token, 0);
    }
    function doOffer( uint sell_how_much, ERC20 sell_which_token
                    , uint buy_how_much,  ERC20 buy_which_token
                    , uint pos )
    returns (uint) {
        return market.offer( sell_how_much, sell_which_token
                  , buy_how_much, buy_which_token, pos);
    }
    function doCancel(uint id) returns (bool _success) {
        return market.cancel(id);
    }
    function getMarket() 
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
    function setUp() {
        otc = new MatchingMarket(50000);
        user1 = new MarketTester(otc);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);
        dgd = new DSTokenBase(10 ** 9);
        dai.transfer(user1, 10 ** 6 );
        user1.doApprove(otc, 10 ** 6 / 2, dai );
        mkr.approve(otc, 10 ** 6);
        dai.approve(otc, 10 ** 6 / 2);
        //setup offers that will be matched later
        //determine how much dai, mkr must be bought and sold 
        //to match a certain number(match_count) of offers 
    }
    // non overflowing multiplication
    function safeMul(uint a, uint b) internal returns (uint c) {
        c = a * b;
        assert(a == 0 || c / a == b);
    }
    function insertOffer(uint sell_how_much, ERC20 sell_which_token, 
                         uint buy_how_much, ERC20 buy_which_token) 
    logs_gas 
    returns(bool _success) {
        otc.offer( sell_how_much, sell_which_token, 
                  buy_how_much, buy_which_token, 0);
    }
    //insert single offer
    function insertOffer(uint sell_how_much, ERC20 sell_which_token, 
                         uint buy_how_much, ERC20 buy_which_token, 
                         uint pos) 
    logs_gas 
    returns(bool _success) {
        otc.offer( sell_how_much, sell_which_token, 
                  buy_how_much, buy_which_token, pos);
    }
    //creates offer_count number of offers of increasing price
    function createOffers(uint offer_count) {
        for( uint offer_index = 0; offer_index < offer_count; offer_index++){
            offer[offer_index] = user1.doOffer(offer_index+1, dai, 1, mkr );
        }
    }
    // Creates test to match match_order_count number of orders 
    function execOrderMatchingGasTest(uint match_order_count) {
        uint mkr_sell; 
        uint dai_buy;
        uint offer_count = match_order_count + 1;

        createOffers(offer_count);
        dai_buy =  safeMul( offer_count, offer_count + 1 ) / 2;
        mkr_sell = dai_buy;

        insertOffer(mkr_sell, mkr, dai_buy, dai);
        assertEq( otc.hos(dai,mkr), 0);
    }
    /*Test the gas usage of inserting one offer.
    
    Creates offer_index amount of offers of decreasing price then it 
    logs the gas usage of inserting one additional offer. This 
    function is useful to test the cost of sorting in order to do 
    offer matching.*/
    function execOrderInsertGasTest(uint offer_index) {
        createOffers(offer_index + 1);
        insertOffer(offer_index+1, dai, 1, mkr);
        assertEq( otc.hos(dai,mkr), 
                 offer_index + 1);
    }
    function testGasMatchOneOrder() {
        var match_order_count = match_count[0]; // 1 
        execOrderMatchingGasTest(match_order_count);
        assert(false);
    }
    function testGasMatchFiveOrders() {
        var match_order_count = match_count[1]; // 5 
        execOrderMatchingGasTest(match_order_count);
        assert(false);
    }
    function testGasMatchTenOrders() {
        var match_order_count = match_count[2]; // 10 
        execOrderMatchingGasTest(match_order_count);
        assert(false);
    }
    function testGasMatchFifteenOrders() {
        var match_order_count = match_count[3]; // 15 
        execOrderMatchingGasTest(match_order_count);
        assert(false);
    }
    function testGasMatchTwentyOrders() {
        var match_order_count = match_count[4]; // 20 
        execOrderMatchingGasTest(match_order_count);
        assert(false);
    }
    function testGasMatchTwentyfiveOrders() {
        var match_order_count = match_count[5]; // 25 
        execOrderMatchingGasTest(match_order_count);
        assert(false);
    }
    function testGasMatchThirtyOrders() {
        var match_order_count = match_count[6]; // 30 
        execOrderMatchingGasTest(match_order_count);
        assert(false);
    }
    function testGasMatchFiftyOrders() {
        var match_order_count = match_count[7]; // 50 
        execOrderMatchingGasTest(match_order_count);
        assert(false);
    }
    function testGasMatchHundredOrders() {
        var match_order_count = match_count[8]; // 100 
        execOrderMatchingGasTest(match_order_count);
        assert(false);
    }
    function testGasMakeOfferInsertAsFirstNoFrontendAid(){
        uint offer_index = 1 - 1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
    function testGasMakeOfferInsertAsFirstWithFrontendAid(){
        uint offer_index = 1 - 1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
    function testGasMakeOfferInsertAsTenthNoFrontendAid(){
        uint offer_index = 10 - 1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
    function testGasMakeOfferInsertAsTenthWithFrontendAid(){
        uint offer_index = 10 - 1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
    function testGasMakeOfferInsertAsTwentiethNoFrontendAid(){
        uint offer_index = 20 - 1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
    function testGasMakeOfferInsertAsTwentiethWithFrontendAid(){
        uint offer_index = 20 - 1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
    function testGasMakeOfferInsertAsFiftiethNoFrontendAid(){
        uint offer_index = 50 - 1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
    function testGasMakeOfferInsertAsFiftiethWithFrontendAid(){
        uint offer_index = 50 - 1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
    function testGasMakeOfferInsertAsHundredthNoFrontendAid(){
        uint offer_index = 100 - 1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
    function testGasMakeOfferInsertAsHundredthWithFrontendAid(){
        uint offer_index = 100 - 1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
    function testGasMakeOfferInsertAsTwohundredthNoFrontendAid(){
        uint offer_index = 200 -1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
    function testGasMakeOfferInsertAsTwohundredthWithFrontendAid(){
        uint offer_index = 200 -1;
        execOrderInsertGasTest(offer_index);
        assert(false);
    }
}
contract OrderMatchingTest is DSTest, EventfulMarket {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    ERC20 dgd;
    MatchingMarket otc;
    mapping( uint => uint ) offer_id;
    uint buy_val;
    uint sell_val;
    uint buy_val1;
    uint sell_val1;
    ERC20 sell_token;
    ERC20 buy_token;
    ERC20 sell_token1;
    ERC20 buy_token1;
    function setUp() {
        otc = new MatchingMarket(50000);
        user1 = new MarketTester(otc);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);
        dgd = new DSTokenBase(10 ** 9);
    }
    function testSetGetMinSellAmout(){
        otc.setMinSell(dai,100);
        assertEq( otc.getMinSell(dai), 100);
    }
    function testFailOfferSellsLessThanRequired(){
        mkr.approve(otc, 30);
        otc.setMinSell(mkr,31);
        assertEq( otc.getMinSell(mkr), 31);
        offer_id[1] = otc.offer( 30, mkr, 100, dai, 0 );
    }
    function testFailNonOwnerCanNotSetSellAmount(){
        user1.doSetMinSellAmount(dai,100);
    }
    function testOfferSellsMoreThanOrEqualThanRequired(){
        mkr.approve(otc, 30);
        otc.setMinSell(mkr,30);
        assertEq( otc.getMinSell(mkr), 30);
        offer_id[1] = otc.offer( 30, mkr, 100, dai, 0 );
    }
    function testErroneousUserHigherIdStillWorks(){
        dai.transfer(user1, 10 );
        user1.doApprove(otc, 10, dai );
        offer_id[1] =  user1.doOffer(1,	    dai,	1,	mkr);
        offer_id[2] =  user1.doOffer(2,     dai,	1,	mkr);
        offer_id[3] =  user1.doOffer(4,     dai,	1,	mkr);
        offer_id[4] =  user1.doOffer(3,	    dai,	1,	mkr, offer_id[2]);
    }
    function testErroneousUserHigherIdStillWorksOther(){
        dai.transfer(user1, 11 );
        user1.doApprove(otc, 11, dai );
        offer_id[1] =  user1.doOffer(2,	    dai,	1,	mkr);
        offer_id[2] =  user1.doOffer(3,     dai,	1,	mkr);
        offer_id[3] =  user1.doOffer(5,     dai,	1,	mkr);
        offer_id[4] =  user1.doOffer(1,	    dai,	1,	mkr, offer_id[3]);
    }
    function testNonExistentOffersUserHigherIdStillWorks(){
        dai.transfer(user1, 10 );
        user1.doApprove(otc, 10, dai );
        uint non_existent_offer_id = 100000;
        offer_id[1] =  user1.doOffer(1,	    dai,	1,	mkr);
        offer_id[2] =  user1.doOffer(2,     dai,	1,	mkr);
        offer_id[3] =  user1.doOffer(4,     dai,	1,	mkr);
        offer_id[4] =  user1.doOffer(3,	    dai,	1,	mkr, non_existent_offer_id);
    }

    function testHighestOfferWithOneOffer(){
        dai.transfer(user1, 1 );
        user1.doApprove(otc, 1, dai );
        offer_id[1] = user1.doOffer(1, dai, 1, mkr );
        
        assertEq( otc.hes( dai, mkr ), offer_id[1]);
        assertEq( otc.hoi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.hos(dai,mkr), 0);
    }
    function testHighestOfferWithOneOfferWithUserprovidedId(){
        dai.transfer(user1, 1 );
        user1.doApprove(otc, 1, dai );
        offer_id[1] = user1.doOffer(1, dai, 1, mkr , 0);
        
        assertEq( otc.hes( dai, mkr ), offer_id[1]);
        assertEq( otc.hoi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.hos(dai,mkr), 0);
    }
    function testHighestOfferWithTwoOffers(){
        dai.transfer(user1, 25 );
        user1.doApprove(otc, 25, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(15, dai, 1, mkr );
        
        assertEq( otc.hes( dai, mkr ), offer_id[2]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[1]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.hos(dai,mkr), 1);
    }
    function testHighestOfferWithTwoOffersWithUserprovidedId(){
        dai.transfer(user1, 25 );
        user1.doApprove(otc, 25, dai );
        offer_id[2] = user1.doOffer(15, dai, 1, mkr );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr, offer_id[2] );
        
        assertEq( otc.hes( dai, mkr ), offer_id[2]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[1]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.hos(dai,mkr), 1);
    }
    function testHighestOfferWithThreeOffers(){
        dai.transfer(user1, 37 );
        user1.doApprove(otc, 37, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(15, dai, 1, mkr );
        
        assertEq( otc.hes( dai, mkr ), offer_id[3]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[1]);
        assertEq( otc.loi(offer_id[3] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[2] ), offer_id[3]);
        assertEq( otc.hoi(offer_id[3] ), 0);
        assertEq( otc.hos(dai,mkr), 2);
    }
    function testHighestOfferWithThreeOffersMixed(){
        dai.transfer(user1, 37 );
        user1.doApprove(otc, 37, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(15, dai, 1, mkr );
        offer_id[3] = user1.doOffer(12, dai, 1, mkr );
        
        assertEq( otc.hes( dai, mkr ), offer_id[2]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[3]);
        assertEq( otc.loi(offer_id[3] ), offer_id[1]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[3]);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.hoi(offer_id[3] ), offer_id[2]);
        assertEq( otc.hos(dai,mkr), 2);
    }
    function testHighestOfferWithThreeOffersMixedWithUserProvidedId(){
        dai.transfer(user1, 37 );
        user1.doApprove(otc, 37, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(15, dai, 1, mkr );
        offer_id[3] = user1.doOffer(12, dai, 1, mkr,offer_id[2] );
        
        assertEq( otc.hes( dai, mkr ), offer_id[2]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[3]);
        assertEq( otc.loi(offer_id[3] ), offer_id[1]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[3]);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.hoi(offer_id[3] ), offer_id[2]);
        assertEq( otc.hos(dai,mkr), 2);
    }
    function testHighestOfferWithFourOffersDeleteBetween(){
        dai.transfer(user1, 53 );
        user1.doApprove(otc, 53, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(15, dai, 1, mkr );
        offer_id[4] = user1.doOffer(16, dai, 1, mkr );
        
        assertEq( otc.hes( dai, mkr ), offer_id[4]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[1]);
        assertEq( otc.loi(offer_id[3] ), offer_id[2]);
        assertEq( otc.loi(offer_id[4] ), offer_id[3]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[2] ), offer_id[3]);
        assertEq( otc.hoi(offer_id[3] ), offer_id[4]);
        assertEq( otc.hoi(offer_id[4] ), 0);
        assertEq( otc.hos(dai,mkr), 3);

        user1.doCancel(offer_id[3]);
        assertEq( otc.hes( dai, mkr ), offer_id[4]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[1]);
        assertEq( otc.loi(offer_id[3] ), 0);
        assertEq( otc.loi(offer_id[4] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[2] ), offer_id[4]);
        assertEq( otc.hoi(offer_id[3] ), 0);
        assertEq( otc.hoi(offer_id[4] ), 0);
        assertEq( otc.hos(dai,mkr), 2);
    }
    function testHighestOfferWithFourOffersWithUserprovidedId(){
        dai.transfer(user1, 53 );
        user1.doApprove(otc, 53, dai );
        offer_id[4] = user1.doOffer(16, dai, 1, mkr, 0 );
        offer_id[3] = user1.doOffer(15, dai, 1, mkr, offer_id[4] );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr, offer_id[3] );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr, offer_id[2]);
        
        assertEq( otc.hes( dai, mkr ), offer_id[4]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[1]);
        assertEq( otc.loi(offer_id[3] ), offer_id[2]);
        assertEq( otc.loi(offer_id[4] ), offer_id[3]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[2] ), offer_id[3]);
        assertEq( otc.hoi(offer_id[3] ), offer_id[4]);
        assertEq( otc.hoi(offer_id[4] ), 0);
        assertEq( otc.hos(dai,mkr), 3);
    }
    function testHighestOfferWithFourOffersTwoSamePriceUserProvidedId(){
        dai.transfer(user1, 50 );
        user1.doApprove(otc, 50, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[4] = user1.doOffer(16, dai, 1, mkr );
        offer_id[3] = user1.doOffer(12, dai, 1, mkr , offer_id[2]);
        
        assertEq( otc.hes( dai, mkr ), offer_id[4]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[3]);
        assertEq( otc.loi(offer_id[3] ), offer_id[1]);
        assertEq( otc.loi(offer_id[4] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[3]);
        assertEq( otc.hoi(offer_id[2] ), offer_id[4]);
        assertEq( otc.hoi(offer_id[3] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[4] ), 0);
        assertEq( otc.hos(dai,mkr), 3);
    }
    function testHighestOfferWithTwoOffersDeletedLowest(){
        dai.transfer(user1, 22 );
        user1.doApprove(otc, 22, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        user1.doCancel(offer_id[1]);
        
        assertEq( otc.hes( dai, mkr ), offer_id[2]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), 0);
        assertEq( otc.hoi(offer_id[1] ), 0);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.hos(dai,mkr), 0);
        assert( !otc.isActive( offer_id[1] ) ); 
    }
    function testHighestOfferWithTwoOffersDeletedHighest(){
        dai.transfer(user1, 22 );
        user1.doApprove(otc, 22, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        user1.doCancel(offer_id[2]);

        assertEq( otc.hes( dai, mkr ), offer_id[1]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), 0);
        assertEq( otc.hoi(offer_id[1] ), 0);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.hos(dai,mkr), 0);
        assert( !otc.isActive( offer_id[2] ) ); 
    }
    function testHighestOfferWithThreeOffersDeletedLowest(){
        dai.transfer(user1, 36 );
        user1.doApprove(otc, 36, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(14, dai, 1, mkr );
        user1.doCancel(offer_id[1]);
        assertEq( otc.hes( dai, mkr ), offer_id[3]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), 0);
        assertEq( otc.loi(offer_id[3] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[1] ), 0);
        assertEq( otc.hoi(offer_id[2] ), offer_id[3]);
        assertEq( otc.hoi(offer_id[3] ), 0);
        assertEq( otc.hos(dai,mkr), 1);
        assert( !otc.isActive( offer_id[1] ) ); 
    }
    function testHighestOfferWithThreeOffersDeletedHighest(){
        dai.transfer(user1, 36 );
        user1.doApprove(otc, 36, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(14, dai, 1, mkr );
        user1.doCancel(offer_id[3]);
        assertEq( otc.hes( dai, mkr ), offer_id[2]);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[1]);
        assertEq( otc.loi(offer_id[3] ), 0);
        assertEq( otc.hoi(offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.hoi(offer_id[3] ), 0);
        assertEq( otc.hos(dai,mkr), 1);
        assert( !otc.isActive( offer_id[3] ) ); 

        expectEventsExact(otc);
        ItemUpdate(offer_id[1]);
        ItemUpdate(offer_id[2]);
        ItemUpdate(offer_id[3]);
        ItemUpdate(offer_id[3]);
    }
    function testHighestOfferWithTwoOffersWithDifferentTokens(){
        dai.transfer(user1, 2 );
        user1.doApprove(otc, 2, dai );
        offer_id[1] = user1.doOffer(1, dai, 1, dgd );
        offer_id[2] = user1.doOffer(1, dai, 1, mkr );
        assertEq( otc.hes( dai, dgd ), offer_id[1]);
        assertEq( otc.hes( dai, mkr ), offer_id[2]);
        assertEq( otc.hoi(offer_id[1] ), 0);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), 0);
        assertEq( otc.hos(dai,dgd), 0);
        assertEq( otc.hos(dai,mkr), 0);
    }
    function testHighestOfferWithFourOffersWithDifferentTokens(){
        dai.transfer(user1, 55 );
        user1.doApprove(otc, 55, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(16, dai, 1, dgd );
        offer_id[4] = user1.doOffer(17, dai, 1, dgd );

        assertEq( otc.hes( dai, mkr ), offer_id[2]);
        assertEq( otc.hes( dai, dgd ), offer_id[4]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.hoi(offer_id[3] ), offer_id[4]);
        assertEq( otc.hoi(offer_id[4] ), 0);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[1]);
        assertEq( otc.loi(offer_id[3] ), 0);
        assertEq( otc.loi(offer_id[4] ), offer_id[3]);
        assertEq( otc.hos(dai,mkr), 1);
        assertEq( otc.hos(dai,dgd), 1);
    }
    function testHighestOfferWithSixOffersWithDifferentTokens(){
        dai.transfer(user1, 88 );
        user1.doApprove(otc, 88, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(15, dai, 1, mkr );
        offer_id[4] = user1.doOffer(16, dai, 1, dgd );
        offer_id[5] = user1.doOffer(17, dai, 1, dgd );
        offer_id[6] = user1.doOffer(18, dai, 1, dgd );

        assertEq( otc.hes( dai, mkr ), offer_id[3]);
        assertEq( otc.hes( dai, dgd ), offer_id[6]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[2] ), offer_id[3]);
        assertEq( otc.hoi(offer_id[3] ), 0);
        assertEq( otc.hoi(offer_id[4] ), offer_id[5]);
        assertEq( otc.hoi(offer_id[5] ), offer_id[6]);
        assertEq( otc.hoi(offer_id[6] ), 0);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[1]);
        assertEq( otc.loi(offer_id[3] ), offer_id[2]);
        assertEq( otc.loi(offer_id[4] ), 0);
        assertEq( otc.loi(offer_id[5] ), offer_id[4]);
        assertEq( otc.loi(offer_id[6] ), offer_id[5]);
        assertEq( otc.hos(dai,mkr), 2);
        assertEq( otc.hos(dai,dgd), 2);
    }
    function testHighestOfferWithEightOffersWithDifferentTokens(){
        dai.transfer(user1, 106 );
        user1.doApprove(otc, 106, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(15, dai, 1, mkr );
        offer_id[4] = user1.doOffer(16, dai, 1, mkr );
        offer_id[5] = user1.doOffer(10, dai, 1, dgd );
        offer_id[6] = user1.doOffer(12, dai, 1, dgd );
        offer_id[7] = user1.doOffer(15, dai, 1, dgd );
        offer_id[8] = user1.doOffer(16, dai, 1, dgd );

        assertEq( otc.hes( dai, mkr ), offer_id[4]);
        assertEq( otc.hes( dai, dgd ), offer_id[8]);
        assertEq( otc.hoi( offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi( offer_id[2] ), offer_id[3]);
        assertEq( otc.hoi( offer_id[3] ), offer_id[4]);
        assertEq( otc.hoi( offer_id[4] ), 0);
        assertEq( otc.hoi( offer_id[5] ), offer_id[6]);
        assertEq( otc.hoi( offer_id[6] ), offer_id[7]);
        assertEq( otc.hoi( offer_id[7] ), offer_id[8]);
        assertEq( otc.hoi( offer_id[8] ), 0);
        assertEq( otc.loi( offer_id[1] ), 0);
        assertEq( otc.loi( offer_id[2] ), offer_id[1]);
        assertEq( otc.loi( offer_id[3] ), offer_id[2]);
        assertEq( otc.loi( offer_id[4] ), offer_id[3]);
        assertEq( otc.loi( offer_id[5] ), 0);
        assertEq( otc.loi( offer_id[6] ), offer_id[5]);
        assertEq( otc.loi( offer_id[7] ), offer_id[6]);
        assertEq( otc.loi( offer_id[8] ), offer_id[7]);
        assertEq( otc.hos(dai,mkr), 3);
        assertEq( otc.hos(dai,dgd), 3);
    }
    function testHighestOfferWithFourOffersWithDifferentTokensLowHighDeleted(){
        dai.transfer(user1, 29 );
        user1.doApprove(otc, 39, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        user1.doCancel( offer_id[1] );
        offer_id[3] = user1.doOffer(8, dai, 1, dgd );
        offer_id[4] = user1.doOffer(9, dai, 1, dgd );
        user1.doCancel( offer_id[3] );

        assertEq( otc.hes( dai, mkr ), offer_id[2]);
        assertEq( otc.hes( dai, dgd ), offer_id[4]);
        assertEq( otc.hoi(offer_id[1] ), 0);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.hoi(offer_id[3] ), 0);
        assertEq( otc.hoi(offer_id[4] ), 0);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), 0);
        assertEq( otc.loi(offer_id[3] ), 0);
        assertEq( otc.loi(offer_id[4] ), 0);
        assertEq( otc.hos(dai,mkr), 0);
        assertEq( otc.hos(dai,dgd), 0);
        assert( !otc.isActive( offer_id[1] ) );
        assert( !otc.isActive( offer_id[3] ) );
    }
    function testHighestOfferWithFourOffersWithDifferentTokensHighLowDeleted(){
        dai.transfer(user1, 27 );
        user1.doApprove(otc, 39, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        user1.doCancel(offer_id[2]);
        offer_id[3] = user1.doOffer(8, dai, 1, dgd );
        offer_id[4] = user1.doOffer(9, dai, 1, dgd );
        user1.doCancel(offer_id[4]);
        assertEq( otc.hes( dai, mkr ), offer_id[1]);
        assertEq( otc.hes( dai, dgd ), offer_id[3]);
        assertEq( otc.hoi(offer_id[1] ), 0);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.hoi(offer_id[3] ), 0);
        assertEq( otc.hoi(offer_id[4] ), 0);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), 0);
        assertEq( otc.loi(offer_id[3] ), 0);
        assertEq( otc.loi(offer_id[4] ), 0);
        assertEq( otc.hos(dai,mkr), 0);
        assertEq( otc.hos(dai,dgd), 0);
        assert( !otc.isActive( offer_id[2] ) );
        assert( !otc.isActive( offer_id[4] ) );
    }
    function testHighestOfferWithSixOffersWithDifferentTokensLowHighDeleted(){
        dai.transfer(user1, 78 );
        user1.doApprove(otc, 88, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(15, dai, 1, mkr );
        user1.doCancel( offer_id[1] );
        offer_id[4] = user1.doOffer(16, dai, 1, dgd );
        offer_id[5] = user1.doOffer(17, dai, 1, dgd );
        offer_id[6] = user1.doOffer(18, dai, 1, dgd );
        user1.doCancel( offer_id[6] );

        assertEq( otc.hes( dai, mkr ), offer_id[3]);
        assertEq( otc.hes( dai, dgd ), offer_id[5]);
        assertEq( otc.hoi(offer_id[1] ), 0);
        assertEq( otc.hoi(offer_id[2] ), offer_id[3]);
        assertEq( otc.hoi(offer_id[3] ), 0);
        assertEq( otc.hoi(offer_id[4] ), offer_id[5]);
        assertEq( otc.hoi(offer_id[5] ), 0);
        assertEq( otc.hoi(offer_id[6] ), 0);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), 0);
        assertEq( otc.loi(offer_id[3] ), offer_id[2]);
        assertEq( otc.loi(offer_id[4] ), 0);
        assertEq( otc.loi(offer_id[5] ), offer_id[4]);
        assertEq( otc.loi(offer_id[6] ), 0);
        assertEq( otc.hos(dai,mkr), 1);
        assertEq( otc.hos(dai,dgd), 1);
        assert( !otc.isActive( offer_id[1] ) );
        assert( !otc.isActive( offer_id[6] ) );
    }
    function testHighestOfferWithSixOffersWithDifferentTokensHighLowDeleted(){
        dai.transfer(user1, 73 );
        user1.doApprove(otc, 88, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(15, dai, 1, mkr );
        user1.doCancel( offer_id[3] );
        offer_id[4] = user1.doOffer(16, dai, 1, dgd );
        offer_id[5] = user1.doOffer(17, dai, 1, dgd );
        offer_id[6] = user1.doOffer(18, dai, 1, dgd );
        user1.doCancel( offer_id[4] );

        assertEq( otc.hes( dai, mkr ), offer_id[2]);
        assertEq( otc.hes( dai, dgd ), offer_id[6]);
        assertEq( otc.hoi(offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi(offer_id[2] ), 0);
        assertEq( otc.hoi(offer_id[3] ), 0);
        assertEq( otc.hoi(offer_id[4] ), 0);
        assertEq( otc.hoi(offer_id[5] ), offer_id[6]);
        assertEq( otc.hoi(offer_id[6] ), 0);
        assertEq( otc.loi(offer_id[1] ), 0);
        assertEq( otc.loi(offer_id[2] ), offer_id[1]);
        assertEq( otc.loi(offer_id[3] ), 0);
        assertEq( otc.loi(offer_id[4] ), 0);
        assertEq( otc.loi(offer_id[5] ), 0);
        assertEq( otc.loi(offer_id[6] ), offer_id[5]);
        assertEq( otc.hos(dai,mkr), 1);
        assertEq( otc.hos(dai,dgd), 1);
        assert( !otc.isActive( offer_id[3] ) );
        assert( !otc.isActive( offer_id[4] ) );
    }
    function testFailInsertOfferWithUserProvidedIdOfADifferentToken(){
        dai.transfer(user1, 13 );
        user1.doApprove(otc, 13, dai );
        mkr.approve(otc, 11);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr );
        offer_id[2] = otc.offer(11, mkr, 1, dgd , offer_id[1] );
    }
    function testOfferMatchOneOnOneSendAmounts() {
        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        offer_id[1] = otc.offer( 30, mkr, 100, dai, 0 );
        offer_id[2] = user1.doOffer( 100, dai, 30, mkr);
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        assertEq( my_mkr_balance_before - my_mkr_balance_after , 30 );
        assertEq( my_dai_balance_after - my_dai_balance_before , 100 );
        assertEq( user1_mkr_balance_after - user1_mkr_balance_before , 30 );
        assertEq( user1_dai_balance_before - user1_dai_balance_after , 100 );

        /* //REPORTS FALSE ERROR: 
        expectEventsExact(otc);
        ItemUpdate(offer_id[1]);
        ItemUpdate(offer_id[1]);
        ItemUpdate(offer_id[2]);*/
    }
    function testOfferMatchOneOnOnePartialSellSendAmounts() {
        dai.transfer(user1, 50);
        user1.doApprove(otc, 50, dai);
        mkr.approve(otc, 200);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        offer_id[1] = otc.offer( 200, mkr, 500, dai, 0 );
        offer_id[2] = user1.doOffer( 50, dai, 20, mkr);
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
        ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[1]);

        assertEq( my_mkr_balance_before - my_mkr_balance_after , 200 );
        assertEq( my_dai_balance_after - my_dai_balance_before , 50 );
        assertEq( user1_mkr_balance_after - user1_mkr_balance_before , 20 );
        assertEq( user1_dai_balance_before - user1_dai_balance_after , 50 );
        assertEq( sell_val , 180 );
        assertEq( buy_val , 450 );
        assert( !otc.isActive(offer_id[2]));

        /* //REPORTS FALSE ERROR: 
        expectEventsExact(otc);
        ItemUpdate(offer_id[1]);
        ItemUpdate(offer_id[1]);
        ItemUpdate(offer_id[2]);*/
    }
    function testOfferMatchOneOnOnePartialBuySendAmounts() {
        dai.transfer(user1, 2000);
        user1.doApprove(otc, 2000, dai);
        mkr.approve(otc, 200);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        offer_id[1] = otc.offer( 200, mkr, 500, dai, 0 );
        offer_id[2] = user1.doOffer( 2000, dai, 800, mkr);
        var my_mkr_balance_after = mkr.balanceOf(this);
        var my_dai_balance_after = dai.balanceOf(this);
        var user1_mkr_balance_after = mkr.balanceOf(user1);
        var user1_dai_balance_after = dai.balanceOf(user1);
         ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[1]);
         ( sell_val1, sell_token1, buy_val1, buy_token1 ) = otc.getOffer(offer_id[2]);

        assertEq( my_mkr_balance_before - my_mkr_balance_after , 200 );
        assertEq( my_dai_balance_after - my_dai_balance_before , 500 );
        assertEq( user1_mkr_balance_after - user1_mkr_balance_before , 200 );
        assertEq( user1_dai_balance_before - user1_dai_balance_after , 2000 );
        assertEq( sell_val , 0 );
        assertEq( buy_val , 0 );
        assertEq( sell_val1 , 1500 );
        assertEq( buy_val1 , 600 );

        expectEventsExact(otc);
        ItemUpdate(offer_id[1]);
        ItemUpdate(offer_id[1]);
        ItemUpdate(offer_id[2]);
    }
    function testOfferMatchingOneOnOneMatch(){
        dai.transfer(user1, 1);
        user1.doApprove(otc, 1, dai );
        mkr.approve(otc, 1);
        offer_id[1] = user1.doOffer( 1, dai, 1, mkr );
        offer_id[2] = otc.offer( 1, mkr, 1, dai, 0 );

        assertEq( otc.hes( dai, mkr ), 0);
        assertEq( otc.hoi( offer_id[1] ), 0);
        assertEq( otc.loi( offer_id[1] ), 0);
        assertEq( otc.hos( dai, mkr ), 0);
        assert( !otc.isActive(offer_id[1]) );
        assert( !otc.isActive(offer_id[2]) );
    } 
    function testOfferMatchingOneOnOneMatchCheckOfferPriceRemainsTheSame(){
        dai.transfer(user1, 5);
        user1.doApprove(otc, 5, dai );
        mkr.approve(otc, 10);
        offer_id[1] = user1.doOffer( 5, dai, 1, mkr );
        offer_id[2] = otc.offer( 10, mkr, 10, dai, 0 );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[2]);

        assertEq( otc.hes( dai, mkr ), 0);
        assertEq( otc.hoi( offer_id[1] ), 0);
        assertEq( otc.loi( offer_id[1] ), 0);
        assertEq( otc.hos( dai, mkr ), 0);
        assert( !otc.isActive(offer_id[1]) );
        //assert érice of offer_id[2] should be the same as before matching
        assertEq( sell_val , 9);
        assertEq( buy_val  , 9);
    } 
    function testOfferMatchingPartialSellTwoOffers(){
        mkr.transfer(user1, 10 );
        user1.doApprove(otc, 10, mkr );
        dai.approve(otc, 5);
        offer_id[1] = user1.doOffer( 10, mkr, 10, dai );
        offer_id[2] = otc.offer( 5, dai, 5, mkr, 0 );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[1]);

        assertEq( otc.hes( dai, mkr ), 0);
        assertEq( otc.hes( mkr, dai ), offer_id[1]);
        assertEq( otc.loi( offer_id[1] ), 0);
        assertEq( otc.loi( offer_id[2] ), 0);
        assertEq( otc.hoi( offer_id[1] ), 0);
        assertEq( otc.hoi( offer_id[2] ), 0);
        assertEq( otc.hos( mkr, dai ), 0);
        assertEq( otc.hos( dai, mkr ), 0);
        assert( !otc.isActive(offer_id[2]) );
        assertEq( sell_val, 5);
        assertEq( buy_val, 5);
    } 
    function testOfferMatchingOneOnTwoMatchCheckOfferPriceRemainsTheSame(){
        dai.transfer(user1, 9);
        user1.doApprove(otc, 9, dai );
        mkr.approve(otc, 10);
        offer_id[1] = user1.doOffer( 5, dai, 1, mkr );
        offer_id[1] = user1.doOffer( 4, dai, 1, mkr );
        offer_id[2] = otc.offer( 10, mkr, 10, dai, 0 );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[2]);

        assertEq( otc.hes( dai, mkr ), 0);
        assertEq( otc.hoi( offer_id[1] ), 0);
        assertEq( otc.loi( offer_id[1] ), 0);
        assertEq( otc.hos( dai, mkr ), 0);
        assert( !otc.isActive(offer_id[1]) );
        //assert érice of offer_id[2] should be the same as before matching
        assertEq( sell_val , 8);
        assertEq( buy_val  , 8);
    } 
    function testOfferMatchingPartialBuyTwoOffers(){
        mkr.transfer(user1, 5 );
        user1.doApprove(otc, 5, mkr );
        dai.approve(otc, 10);
        offer_id[1] = user1.doOffer( 5, mkr, 5, dai );
        offer_id[2] = otc.offer( 10, dai, 10, mkr, 0 );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[2]);

        assertEq( otc.hes( dai, mkr ), offer_id[2]);
        assertEq( otc.hes( mkr, dai ), 0);
        assertEq( otc.loi( offer_id[1] ), 0);
        assertEq( otc.loi( offer_id[2] ), 0);
        assertEq( otc.hoi( offer_id[1] ), 0);
        assertEq( otc.hoi( offer_id[2] ), 0);
        assertEq( otc.hos( mkr, dai ), 0);
        assertEq( otc.hos( dai, mkr ), 0);
        assert( !otc.isActive(offer_id[1]) );
        assertEq( sell_val, 5);
        assertEq( buy_val, 5);
    } 
    function testOfferMatchingPartialBuyThreeOffers(){
        mkr.transfer(user1, 15 );
        user1.doApprove(otc, 15, mkr );
        dai.approve(otc, 1);
        offer_id[1] = user1.doOffer( 5, mkr, 10, dai );
        offer_id[2] = user1.doOffer( 10, mkr, 10, dai );
        offer_id[3] = otc.offer( 1, dai, 1, mkr, 0 );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[1]);
        var ( sell_val1, sell_token1, buy_val1, buy_token1 ) = otc.getOffer(offer_id[2]);

        assertEq( otc.hes( mkr, dai ), offer_id[2]);
        assertEq( otc.hes( dai, mkr ), 0);
        assertEq( otc.loi( offer_id[1] ), 0);
        assertEq( otc.loi( offer_id[2] ), offer_id[1]);
        assertEq( otc.hoi( offer_id[1] ), offer_id[2]);
        assertEq( otc.hoi( offer_id[2] ), 0);
        assertEq( otc.hos( mkr, dai ), 1);
        assertEq( otc.hos( dai, mkr ), 0);
        assert( !otc.isActive(offer_id[3]) );
        assertEq( sell_val, 5);
        assertEq( buy_val, 10);
        assertEq( sell_val1, 9);
        assertEq( buy_val1, 9);
    } 
    function testOfferMatchingPartialSellThreeOffers(){
        mkr.transfer(user1, 6 );
        user1.doApprove(otc, 6, mkr );
        dai.approve(otc, 10);
        offer_id[1] = user1.doOffer( 5, mkr, 10, dai );
        offer_id[2] = user1.doOffer( 1, mkr, 1, dai );
        offer_id[3] = otc.offer( 10, dai, 10, mkr, 0 );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[1]);
        var ( sell_val1, sell_token1, buy_val1, buy_token1 ) = otc.getOffer(offer_id[3]);

        assertEq( otc.hes( mkr, dai ), offer_id[1]);
        assertEq( otc.hes( dai, mkr ), offer_id[3]);
        assertEq( otc.loi( offer_id[1] ), 0);
        assertEq( otc.loi( offer_id[2] ), 0);
        assertEq( otc.loi( offer_id[3] ), 0);
        assertEq( otc.hoi( offer_id[1] ), 0);
        assertEq( otc.hoi( offer_id[2] ), 0);
        assertEq( otc.hoi( offer_id[3] ), 0);
        assertEq( otc.hos( mkr, dai ), 0);
        assertEq( otc.hos( dai, mkr ), 0);
        assert( !otc.isActive(offer_id[2]) );
        assertEq( sell_val, 5);
        assertEq( buy_val, 10);
        assertEq( sell_val1, 9);
        assertEq( buy_val1, 9);
    } 
    function testOfferMatchingPartialSellThreeOffersTwoBuyThreeSell(){
        dai.transfer(user1, 3);
        user1.doApprove(otc, 3, dai );
        mkr.approve(otc, 12);
        offer_id[1] = otc.offer(     1, mkr, 10, dai, 0 );
        offer_id[2] = otc.offer(     1, mkr,  1, dai, 0 );
        offer_id[3] = otc.offer(    10, mkr, 10, dai, 0 );
        offer_id[4] = user1.doOffer( 3, dai,  3, mkr );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[3]);
        var ( sell_val1, sell_token1, buy_val1, buy_token1 ) = otc.getOffer(offer_id[1]);
        address user1_address = address(user1);
        address my_address = address(this);
        address dai_address = address(dai);
        address mkr_address = address(mkr);
        assertEq( otc.hes( mkr, dai ), offer_id[3]);
        assertEq( otc.hes( dai, mkr ), 0);
        assertEq( otc.loi( offer_id[1] ), 0);
        assertEq( otc.loi( offer_id[2] ), 0);
        assertEq( otc.loi( offer_id[3] ), offer_id[1]);
        assertEq( otc.loi( offer_id[4] ), 0);
        assertEq( otc.hoi( offer_id[1] ), offer_id[3]);
        assertEq( otc.hoi( offer_id[2] ), 0);
        assertEq( otc.hoi( offer_id[3] ), 0);
        assertEq( otc.hoi( offer_id[4] ), 0);
        assertEq( otc.hos( mkr, dai ), 1);
        assertEq( otc.hos( dai, mkr ), 0);
        assert( !otc.isActive(offer_id[2]) );
        assert( !otc.isActive(offer_id[4]) );
        assertEq( sell_val, 8);
        assertEq( buy_val, 8);
        assertEq( sell_val1, 1);
        assertEq( buy_val1, 10);
    } 
}


