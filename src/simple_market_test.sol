pragma solidity ^0.4.8;

import "ds-test/test.sol";
import "ds-token/base.sol";

import "./simple_market.sol";

contract MarketTester {
    SimpleMarket market;
    function MarketTester(SimpleMarket market_) {
        market = market_;
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
                  , buy_how_much, buy_which_token);
    }
    function doOffer( uint sell_how_much, ERC20 sell_which_token
                    , uint buy_how_much,  ERC20 buy_which_token
                    , uint user_higher_id )
    returns (uint) {
        return market.offer( sell_how_much, sell_which_token
                  , buy_how_much, buy_which_token, user_higher_id);
    }
    function doCancel(uint id) returns (bool _success) {
        return market.cancel(id);
    }
    function getMarket() 
    returns (SimpleMarket)
    {
        return market;
    }
}
contract OrderMatchingGasTest is DSTest {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    ERC20 dgd;
    SimpleMarket otc;
    uint offer_count = 200;
    mapping( uint => uint ) offer;
    mapping( uint => uint ) dai_to_buy;
    mapping( uint => uint ) mkr_to_sell;
    uint [] match_count = [1,5,10,15,20,50,100];
    function setUp() {
        otc = new SimpleMarket();
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
    function insertOffer(uint sell_how_much, ERC20 sell_which_token, 
                         uint buy_how_much, ERC20 buy_which_token) 
    logs_gas 
    returns(bool _success) {
        otc.offer( sell_how_much, sell_which_token, 
                  buy_how_much, buy_which_token);
    }
    //insert single offer
    function insertOffer(uint sell_how_much, ERC20 sell_which_token, 
                         uint buy_how_much, ERC20 buy_which_token, 
                         uint user_higher_id) 
    logs_gas 
    returns(bool _success) {
        otc.offer( sell_how_much, sell_which_token, 
                  buy_how_much, buy_which_token, user_higher_id);
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
        dai_buy =  ( (2 * offer_count - match_order_count  + 1 ) 
                    * match_order_count  ) / 2 ;
        mkr_sell = match_order_count;

        insertOffer(mkr_sell, mkr, dai_buy, dai);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 0);
    }
    /*Test the gas usage of inserting one offer.
    
    Creates offer_index amount of offers of decreasing price then it 
    logs the gas usage of inserting one additional offer. This 
    function is useful to test the cost of sorting in order to do 
    offer matching.*/
    function execOrderInsertGasTest(uint offer_index) {
        createOffers(offer_index + 1);
        insertOffer(offer_index+1, dai, 1, mkr);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 
                 offer_index + 1);
    }
    function testGasMatchOneOrder() {
        var match_order_count = match_count[0]; // 1 
        execOrderMatchingGasTest(match_order_count);
    }
    function testGasMatchFiveOrders() {
        var match_order_count = match_count[1]; // 5 
        execOrderMatchingGasTest(match_order_count);
    }
    function testGasMatchTenOrders() {
        var match_order_count = match_count[2]; // 10 
        execOrderMatchingGasTest(match_order_count);
    }
    function testGasMatchFifteenOrders() {
        var match_order_count = match_count[3]; // 15 
        execOrderMatchingGasTest(match_order_count);
    }
    function testGasMatchTwentyOrders() {
        var match_order_count = match_count[4]; // 20 
        execOrderMatchingGasTest(match_order_count);
    }
    function testGasMatchFiftyOrders() {
        var match_order_count = match_count[5]; // 50 
        execOrderMatchingGasTest(match_order_count);
    }
    function testGasMatchHundredOrders() {
        var match_order_count = match_count[6]; // 100 
        execOrderMatchingGasTest(match_order_count);
    }
    function testGasMakeOfferInsertAsFirstNoFrontendAid(){
        uint offer_index = 1 - 1;
        execOrderInsertGasTest(offer_index);
    }
    function testGasMakeOfferInsertAsFirstWithFrontendAid(){
        uint offer_index = 1 - 1;
        execOrderInsertGasTest(offer_index);
    }
    function testGasMakeOfferInsertAsTenthNoFrontendAid(){
        uint offer_index = 10 - 1;
        execOrderInsertGasTest(offer_index);
    }
    function testGasMakeOfferInsertAsTenthWithFrontendAid(){
        uint offer_index = 10 - 1;
        execOrderInsertGasTest(offer_index);
    }
    function testGasMakeOfferInsertAsTwentiethNoFrontendAid(){
        uint offer_index = 20 - 1;
        execOrderInsertGasTest(offer_index);
    }
    function testGasMakeOfferInsertAsTwentiethWithFrontendAid(){
        uint offer_index = 20 - 1;
        execOrderInsertGasTest(offer_index);
    }
    function testGasMakeOfferInsertAsFiftiethNoFrontendAid(){
        uint offer_index = 50 - 1;
        execOrderInsertGasTest(offer_index);
    }
    function testGasMakeOfferInsertAsFiftiethWithFrontendAid(){
        uint offer_index = 50 - 1;
        execOrderInsertGasTest(offer_index);
    }
    function testGasMakeOfferInsertAsHundredthNoFrontendAid(){
        uint offer_index = 100 - 1;
        execOrderInsertGasTest(offer_index);
    }
    function testGasMakeOfferInsertAsHundredthWithFrontendAid(){
        uint offer_index = 100 - 1;
        execOrderInsertGasTest(offer_index);
    }
    function testGasMakeOfferInsertAsTwohundredthNoFrontendAid(){
        uint offer_index = 200 -1;
        execOrderInsertGasTest(offer_index);
    }
    function testGasMakeOfferInsertAsTwohundredthWithFrontendAid(){
        uint offer_index = 200 -1;
        execOrderInsertGasTest(offer_index);
    }
}
contract OrderMatchingTest is DSTest, EventfulMarket {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    ERC20 dgd;
    SimpleMarket otc;
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
        otc = new SimpleMarket();
        user1 = new MarketTester(otc);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);
        dgd = new DSTokenBase(10 ** 9);
    }
    function testHighestOfferWithOneOffer(){
        dai.transfer(user1, 1 );
        user1.doApprove(otc, 1, dai );
        offer_id[1] = user1.doOffer(1, dai, 1, mkr );
        
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 0);
    }
    function testHighestOfferWithOneOfferWithUserprovidedId(){
        dai.transfer(user1, 1 );
        user1.doApprove(otc, 1, dai );
        offer_id[1] = user1.doOffer(1, dai, 1, mkr , 0);
        
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 0);
    }
    function testHighestOfferWithTwoOffers(){
        dai.transfer(user1, 25 );
        user1.doApprove(otc, 25, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(15, dai, 1, mkr );
        
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[1]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 1);
    }
    function testHighestOfferWithTwoOffersWithUserprovidedId(){
        dai.transfer(user1, 25 );
        user1.doApprove(otc, 25, dai );
        offer_id[2] = user1.doOffer(15, dai, 1, mkr );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr, offer_id[2] );
        
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[1]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 1);
    }
    function testHighestOfferWithThreeOffers(){
        dai.transfer(user1, 37 );
        user1.doApprove(otc, 37, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(15, dai, 1, mkr );
        
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[3]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[1]);
        assertEq( otc.getLowerOfferId(offer_id[3] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[3] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 2);
    }
    function testHighestOfferWithThreeOffersMixed(){
        dai.transfer(user1, 37 );
        user1.doApprove(otc, 37, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(15, dai, 1, mkr );
        offer_id[3] = user1.doOffer(12, dai, 1, mkr );
        
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[3]);
        assertEq( otc.getLowerOfferId(offer_id[3] ), offer_id[1]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[3] ), offer_id[2]);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 2);
    }
    function testHighestOfferWithThreeOffersMixedWithUserProvidedId(){
        dai.transfer(user1, 37 );
        user1.doApprove(otc, 37, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(15, dai, 1, mkr );
        offer_id[3] = user1.doOffer(12, dai, 1, mkr,offer_id[2] );
        
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[3]);
        assertEq( otc.getLowerOfferId(offer_id[3] ), offer_id[1]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[3] ), offer_id[2]);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 2);
    }
    function testHighestOfferWithFourOffersDeleteBetween(){
        dai.transfer(user1, 53 );
        user1.doApprove(otc, 53, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(15, dai, 1, mkr );
        offer_id[4] = user1.doOffer(16, dai, 1, mkr );
        
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[4]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[1]);
        assertEq( otc.getLowerOfferId(offer_id[3] ), offer_id[2]);
        assertEq( otc.getLowerOfferId(offer_id[4] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[3] ), offer_id[4]);
        assertEq( otc.getHigherOfferId(offer_id[4] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 3);

        user1.doCancel(offer_id[3]);
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[4]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[1]);
        assertEq( otc.getLowerOfferId(offer_id[3] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[4] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), offer_id[4]);
        assertEq( otc.getHigherOfferId(offer_id[3] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[4] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 2);
    }
    function testHighestOfferWithFourOffersWithUserprovidedId(){
        dai.transfer(user1, 53 );
        user1.doApprove(otc, 53, dai );
        offer_id[4] = user1.doOffer(16, dai, 1, mkr, 0 );
        offer_id[3] = user1.doOffer(15, dai, 1, mkr, offer_id[4] );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr, offer_id[3] );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr, offer_id[2]);
        
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[4]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[1]);
        assertEq( otc.getLowerOfferId(offer_id[3] ), offer_id[2]);
        assertEq( otc.getLowerOfferId(offer_id[4] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[3] ), offer_id[4]);
        assertEq( otc.getHigherOfferId(offer_id[4] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 3);
    }
    function testHighestOfferWithFourOffersTwoSamePriceUserProvidedId(){
        dai.transfer(user1, 50 );
        user1.doApprove(otc, 50, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[4] = user1.doOffer(16, dai, 1, mkr );
        offer_id[3] = user1.doOffer(12, dai, 1, mkr , offer_id[4]);
        
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[4]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[1]);
        assertEq( otc.getLowerOfferId(offer_id[3] ), offer_id[2]);
        assertEq( otc.getLowerOfferId(offer_id[4] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[3] ), offer_id[4]);
        assertEq( otc.getHigherOfferId(offer_id[4] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 3);
    }
    function testHighestOfferWithTwoOffersDeletedLowest(){
        dai.transfer(user1, 22 );
        user1.doApprove(otc, 22, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        user1.doCancel(offer_id[1]);
        
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[1] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 0);
        assert( !otc.isActive( offer_id[1] ) ); 
    }
    function testHighestOfferWithTwoOffersDeletedHighest(){
        dai.transfer(user1, 22 );
        user1.doApprove(otc, 22, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        user1.doCancel(offer_id[2]);

        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[1] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 0);
        assert( !otc.isActive( offer_id[2] ) ); 
    }
    function testHighestOfferWithThreeOffersDeletedLowest(){
        dai.transfer(user1, 36 );
        user1.doApprove(otc, 36, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(14, dai, 1, mkr );
        user1.doCancel(offer_id[1]);
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[3]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[3] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[2] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[3] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 1);
        assert( !otc.isActive( offer_id[1] ) ); 
    }
    function testHighestOfferWithThreeOffersDeletedHighest(){
        dai.transfer(user1, 36 );
        user1.doApprove(otc, 36, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(14, dai, 1, mkr );
        user1.doCancel(offer_id[3]);
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[1]);
        assertEq( otc.getLowerOfferId(offer_id[3] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[3] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 1);
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
        assertEq( otc.getLowestOffer( dai, dgd ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, dgd ), offer_id[1]);
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,dgd), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 0);
    }
    function testHighestOfferWithFourOffersWithDifferentTokens(){
        dai.transfer(user1, 55 );
        user1.doApprove(otc, 55, dai );
        offer_id[1] = user1.doOffer(10, dai, 1, mkr );
        offer_id[2] = user1.doOffer(12, dai, 1, mkr );
        offer_id[3] = user1.doOffer(16, dai, 1, dgd );
        offer_id[4] = user1.doOffer(17, dai, 1, dgd );

        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getLowestOffer( dai, dgd ), offer_id[3]);
        assertEq( otc.getHighestOffer( dai, dgd ), offer_id[4]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[3] ), offer_id[4]);
        assertEq( otc.getHigherOfferId(offer_id[4] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[1]);
        assertEq( otc.getLowerOfferId(offer_id[3] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[4] ), offer_id[3]);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 1);
        assertEq( otc.getHigherOfferIdSize(dai,dgd), 1);
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

        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[3]);
        assertEq( otc.getLowestOffer( dai, dgd ), offer_id[4]);
        assertEq( otc.getHighestOffer( dai, dgd ), offer_id[6]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[3] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[4] ), offer_id[5]);
        assertEq( otc.getHigherOfferId(offer_id[5] ), offer_id[6]);
        assertEq( otc.getHigherOfferId(offer_id[6] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[1]);
        assertEq( otc.getLowerOfferId(offer_id[3] ), offer_id[2]);
        assertEq( otc.getLowerOfferId(offer_id[4] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[5] ), offer_id[4]);
        assertEq( otc.getLowerOfferId(offer_id[6] ), offer_id[5]);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 2);
        assertEq( otc.getHigherOfferIdSize(dai,dgd), 2);
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

        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[4]);
        assertEq( otc.getLowestOffer( dai, dgd ), offer_id[5]);
        assertEq( otc.getHighestOffer( dai, dgd ), offer_id[8]);
        assertEq( otc.getHigherOfferId( offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId( offer_id[2] ), offer_id[3]);
        assertEq( otc.getHigherOfferId( offer_id[3] ), offer_id[4]);
        assertEq( otc.getHigherOfferId( offer_id[4] ), 0);
        assertEq( otc.getHigherOfferId( offer_id[5] ), offer_id[6]);
        assertEq( otc.getHigherOfferId( offer_id[6] ), offer_id[7]);
        assertEq( otc.getHigherOfferId( offer_id[7] ), offer_id[8]);
        assertEq( otc.getHigherOfferId( offer_id[8] ), 0);
        assertEq( otc.getLowerOfferId( offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId( offer_id[2] ), offer_id[1]);
        assertEq( otc.getLowerOfferId( offer_id[3] ), offer_id[2]);
        assertEq( otc.getLowerOfferId( offer_id[4] ), offer_id[3]);
        assertEq( otc.getLowerOfferId( offer_id[5] ), 0);
        assertEq( otc.getLowerOfferId( offer_id[6] ), offer_id[5]);
        assertEq( otc.getLowerOfferId( offer_id[7] ), offer_id[6]);
        assertEq( otc.getLowerOfferId( offer_id[8] ), offer_id[7]);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 3);
        assertEq( otc.getHigherOfferIdSize(dai,dgd), 3);
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

        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getLowestOffer( dai, dgd ), offer_id[4]);
        assertEq( otc.getHighestOffer( dai, dgd ), offer_id[4]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[3] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[4] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[3] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[4] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 0);
        assertEq( otc.getHigherOfferIdSize(dai,dgd), 0);
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
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getLowestOffer( dai, dgd ), offer_id[3]);
        assertEq( otc.getHighestOffer( dai, dgd ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[3] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[4] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[3] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[4] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 0);
        assertEq( otc.getHigherOfferIdSize(dai,dgd), 0);
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

        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[3]);
        assertEq( otc.getLowestOffer( dai, dgd ), offer_id[4]);
        assertEq( otc.getHighestOffer( dai, dgd ), offer_id[5]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[2] ), offer_id[3]);
        assertEq( otc.getHigherOfferId(offer_id[3] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[4] ), offer_id[5]);
        assertEq( otc.getHigherOfferId(offer_id[5] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[6] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[3] ), offer_id[2]);
        assertEq( otc.getLowerOfferId(offer_id[4] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[5] ), offer_id[4]);
        assertEq( otc.getLowerOfferId(offer_id[6] ), 0);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 1);
        assertEq( otc.getHigherOfferIdSize(dai,dgd), 1);
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

        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[1]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getLowestOffer( dai, dgd ), offer_id[5]);
        assertEq( otc.getHighestOffer( dai, dgd ), offer_id[6]);
        assertEq( otc.getHigherOfferId(offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId(offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[3] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[4] ), 0);
        assertEq( otc.getHigherOfferId(offer_id[5] ), offer_id[6]);
        assertEq( otc.getHigherOfferId(offer_id[6] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[2] ), offer_id[1]);
        assertEq( otc.getLowerOfferId(offer_id[3] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[4] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[5] ), 0);
        assertEq( otc.getLowerOfferId(offer_id[6] ), offer_id[5]);
        assertEq( otc.getHigherOfferIdSize(dai,mkr), 1);
        assertEq( otc.getHigherOfferIdSize(dai,dgd), 1);
        assert( !otc.isActive( offer_id[3] ) );
        assert( !otc.isActive( offer_id[4] ) );
    }
    function testFailInsertOfferWithUserProvidedIdOfADifferentToken(){
        dai.transfer(user1, 13 );
        user1.doApprove(otc, 13, dai );
        mkr.approve(otc, 11);
        offer_id[1] = user1.doOffer(13, dai, 1, mkr );
        offer_id[2] = otc.offer(11, mkr, 1, dgd , offer_id[1]);
    }
    function testOfferMatchOneOnOneSendAmounts() {
        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);

        var my_mkr_balance_before = mkr.balanceOf(this);
        var my_dai_balance_before = dai.balanceOf(this);
        var user1_mkr_balance_before = mkr.balanceOf(user1);
        var user1_dai_balance_before = dai.balanceOf(user1);

        offer_id[1] = otc.offer( 30, mkr, 100, dai );
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

        offer_id[1] = otc.offer( 200, mkr, 500, dai );
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

        offer_id[1] = otc.offer( 200, mkr, 500, dai );
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
        offer_id[2] = otc.offer( 1, mkr, 1, dai );

        assertEq( otc.getLowestOffer( dai, mkr ), 0);
        assertEq( otc.getHighestOffer( dai, mkr ), 0);
        assertEq( otc.getHigherOfferId( offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId( offer_id[1] ), 0);
        assertEq( otc.getHigherOfferIdSize( dai, mkr ), 0);
        assert( !otc.isActive(offer_id[1]) );
        assert( !otc.isActive(offer_id[2]) );
    } 
    function testOfferMatchingPartialSellTwoOffers(){
        mkr.transfer(user1, 10 );
        user1.doApprove(otc, 10, mkr );
        dai.approve(otc, 5);
        offer_id[1] = user1.doOffer( 10, mkr, 10, dai );
        offer_id[2] = otc.offer( 5, dai, 5, mkr );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[1]);

        assertEq( otc.getLowestOffer( dai, mkr ), 0);
        assertEq( otc.getHighestOffer( dai, mkr ), 0);
        assertEq( otc.getLowestOffer( mkr, dai ), offer_id[1]);
        assertEq( otc.getHighestOffer( mkr, dai ), offer_id[1]);
        assertEq( otc.getLowerOfferId( offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId( offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId( offer_id[1] ), 0);
        assertEq( otc.getHigherOfferId( offer_id[2] ), 0);
        assertEq( otc.getHigherOfferIdSize( mkr, dai ), 0);
        assertEq( otc.getHigherOfferIdSize( dai, mkr ), 0);
        assert( !otc.isActive(offer_id[2]) );
        assertEq( sell_val, 5);
        assertEq( buy_val, 5);
    } 
    function testOfferMatchingPartialBuyTwoOffers(){
        mkr.transfer(user1, 5 );
        user1.doApprove(otc, 5, mkr );
        dai.approve(otc, 10);
        offer_id[1] = user1.doOffer( 5, mkr, 5, dai );
        offer_id[2] = otc.offer( 10, dai, 10, mkr );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[2]);

        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[2]);
        assertEq( otc.getLowestOffer( mkr, dai ), 0);
        assertEq( otc.getHighestOffer( mkr, dai ), 0);
        assertEq( otc.getLowerOfferId( offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId( offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId( offer_id[1] ), 0);
        assertEq( otc.getHigherOfferId( offer_id[2] ), 0);
        assertEq( otc.getHigherOfferIdSize( mkr, dai ), 0);
        assertEq( otc.getHigherOfferIdSize( dai, mkr ), 0);
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
        offer_id[3] = otc.offer( 1, dai, 1, mkr );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[1]);
        var ( sell_val1, sell_token1, buy_val1, buy_token1 ) = otc.getOffer(offer_id[2]);

        assertEq( otc.getLowestOffer( mkr, dai ), offer_id[1]);
        assertEq( otc.getHighestOffer( mkr, dai ), offer_id[2]);
        assertEq( otc.getLowestOffer( dai, mkr ), 0);
        assertEq( otc.getHighestOffer( dai, mkr ), 0);
        assertEq( otc.getLowerOfferId( offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId( offer_id[2] ), offer_id[1]);
        assertEq( otc.getHigherOfferId( offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId( offer_id[2] ), 0);
        assertEq( otc.getHigherOfferIdSize( mkr, dai ), 1);
        assertEq( otc.getHigherOfferIdSize( dai, mkr ), 0);
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
        offer_id[3] = otc.offer( 10, dai, 10, mkr );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[1]);
        var ( sell_val1, sell_token1, buy_val1, buy_token1 ) = otc.getOffer(offer_id[3]);

        assertEq( otc.getLowestOffer( mkr, dai ), offer_id[1]);
        assertEq( otc.getHighestOffer( mkr, dai ), offer_id[1]);
        assertEq( otc.getLowestOffer( dai, mkr ), offer_id[3]);
        assertEq( otc.getHighestOffer( dai, mkr ), offer_id[3]);
        assertEq( otc.getLowerOfferId( offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId( offer_id[2] ), 0);
        assertEq( otc.getLowerOfferId( offer_id[3] ), 0);
        assertEq( otc.getHigherOfferId( offer_id[1] ), 0);
        assertEq( otc.getHigherOfferId( offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId( offer_id[3] ), 0);
        assertEq( otc.getHigherOfferIdSize( mkr, dai ), 0);
        assertEq( otc.getHigherOfferIdSize( dai, mkr ), 0);
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
        offer_id[1] = otc.offer( 1, mkr, 10, dai );
        offer_id[2] = otc.offer( 10, mkr, 10, dai );
        offer_id[3] = otc.offer( 1, mkr, 1, dai );
        offer_id[4] = user1.doOffer( 3, dai, 3, mkr );
        var ( sell_val, sell_token, buy_val, buy_token ) = otc.getOffer(offer_id[2]);
        var ( sell_val1, sell_token1, buy_val1, buy_token1 ) = otc.getOffer(offer_id[1]);
        address user1_address = address(user1);
        address my_address = address(this);
        address dai_address = address(dai);
        address mkr_address = address(mkr);
        assertEq( otc.getLowestOffer( mkr, dai ), offer_id[1]);
        assertEq( otc.getHighestOffer( mkr, dai ), offer_id[2]);
        assertEq( otc.getLowestOffer( dai, mkr ), 0);
        assertEq( otc.getHighestOffer( dai, mkr ), 0);
        assertEq( otc.getLowerOfferId( offer_id[1] ), 0);
        assertEq( otc.getLowerOfferId( offer_id[2] ), offer_id[1]);
        assertEq( otc.getLowerOfferId( offer_id[3] ), 0);
        assertEq( otc.getLowerOfferId( offer_id[4] ), 0);
        assertEq( otc.getHigherOfferId( offer_id[1] ), offer_id[2]);
        assertEq( otc.getHigherOfferId( offer_id[2] ), 0);
        assertEq( otc.getHigherOfferId( offer_id[3] ), 0);
        assertEq( otc.getHigherOfferId( offer_id[4] ), 0);
        assertEq( otc.getHigherOfferIdSize( mkr, dai ), 1);
        assertEq( otc.getHigherOfferIdSize( dai, mkr ), 0);
        assert( !otc.isActive(offer_id[3]) );
        assert( !otc.isActive(offer_id[4]) );
        assertEq( sell_val, 8);
        assertEq( buy_val, 8);
        assertEq( sell_val1, 1);
        assertEq( buy_val1, 10);
    } 
}
contract SimpleMarketTest is DSTest, EventfulMarket {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    SimpleMarket otc;
    bool buy_enabled;
    function setUp() {
        otc = new SimpleMarket();
        user1 = new MarketTester(otc);
        buy_enabled = otc.isBuyEnabled();
        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);
    }
    function testBasicTrade() {
        if(buy_enabled){
            dai.transfer(user1, 100);
            user1.doApprove(otc, 100, dai);
            mkr.approve(otc, 30);

            var my_mkr_balance_before = mkr.balanceOf(this);
            var my_dai_balance_before = dai.balanceOf(this);
            var user1_mkr_balance_before = mkr.balanceOf(user1);
            var user1_dai_balance_before = dai.balanceOf(user1);

            var id = otc.offer( 30, mkr, 100, dai );
            assert(user1.doBuy(id, 30));
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
    }
    function testPartiallyFilledOrderMkr() {
        if(buy_enabled){
            dai.transfer(user1, 30);
            user1.doApprove(otc, 30, dai);
            mkr.approve(otc, 200);

            var my_mkr_balance_before = mkr.balanceOf(this);
            var my_dai_balance_before = dai.balanceOf(this);
            var user1_mkr_balance_before = mkr.balanceOf(user1);
            var user1_dai_balance_before = dai.balanceOf(user1);

            var id = otc.offer( 200, mkr, 500, dai );
            assert(user1.doBuy(id, 10));
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
    }
    function testPartiallyFilledOrderDai() {
        if(buy_enabled){
            mkr.transfer(user1, 10);
            user1.doApprove(otc, 10, mkr);
            dai.approve(otc, 500);

            var my_mkr_balance_before = mkr.balanceOf(this);
            var my_dai_balance_before = dai.balanceOf(this);
            var user1_mkr_balance_before = mkr.balanceOf(user1);
            var user1_dai_balance_before = dai.balanceOf(user1);

            var id = otc.offer( 500, dai, 200, mkr );
            assert(user1.doBuy(id, 10));
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
    }
    function testPartiallyFilledOrderMkrExcessQuantity() {
        if(buy_enabled){
            dai.transfer(user1, 30);
            user1.doApprove(otc, 30, dai);
            mkr.approve(otc, 200);

            var my_mkr_balance_before = mkr.balanceOf(this);
            var my_dai_balance_before = dai.balanceOf(this);
            var user1_mkr_balance_before = mkr.balanceOf(user1);
            var user1_dai_balance_before = dai.balanceOf(user1);

            var id = otc.offer( 200, mkr, 500, dai );
            assert(!user1.doBuy(id, 201));

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
    }
    function testInsufficientlyFilledOrder() {
        if(buy_enabled){
            mkr.approve(otc, 30);
            var id = otc.offer( 30, mkr, 10, dai );

            dai.transfer(user1, 1);
            user1.doApprove(otc, 1, dai);
            var success = user1.doBuy(id, 1);
            assert(!success);
        }
    }
    function testCancel() {
        mkr.approve(otc, 30);
        var id = otc.offer( 30, mkr, 100, dai );
        assert(otc.cancel(id));

        expectEventsExact(otc);
        ItemUpdate(id);
        ItemUpdate(id);
    }
    function testFailCancelNotOwner() {
        mkr.approve(otc, 30);
        var id = otc.offer( 30, mkr, 100, dai );
        user1.doCancel(id);
    }
    function testFailCancelInactive() {
        mkr.approve(otc, 30);
        var id = otc.offer( 30, mkr, 100, dai );
        assert(otc.cancel(id));
        otc.cancel(id);
    }
    function testFailBuyInactive() {
        if(buy_enabled){
            mkr.approve(otc, 30);
            var id = otc.offer( 30, mkr, 100, dai );
            assert(otc.cancel(id));
            otc.buy(id, 0);
        }else{
            assert(false);
        }
    }
    function testFailOfferNotEnoughFunds() {
        mkr.transfer(address(0x0), mkr.balanceOf(this) - 29);
        var id = otc.offer(30, mkr, 100, dai);
    }
    function testFailBuyNotEnoughFunds() {
        if(buy_enabled){
            var id = otc.offer(30, mkr, 101, dai);
            log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
            user1.doApprove(otc, 101, dai);
            log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
            log_named_uint("user1 dai balance before", dai.balanceOf(user1));
            assert(user1.doBuy(id, 101));
            log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
            log_named_uint("user1 dai balance after", dai.balanceOf(user1));
        }else{
            assert(false);
        }
    }
    function testFailBuyNotEnoughApproval() {
        if(buy_enabled){
            var id = otc.offer(30, mkr, 100, dai);
            log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
            user1.doApprove(otc, 99, dai);
            log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
            log_named_uint("user1 dai balance before", dai.balanceOf(user1));
            assert(user1.doBuy(id, 100));
            log_named_uint("user1 dai allowance", dai.allowance(user1, otc));
            log_named_uint("user1 dai balance after", dai.balanceOf(user1));
        }else{
            assert(false);
        }
    }
    function testFailOfferSameToken() {
        dai.approve(otc, 200);
        otc.offer(100, dai, 100, dai);
    }
    function testBuyTooMuch() {
        if(buy_enabled){
            mkr.approve(otc, 30);
            var id = otc.offer( 30, mkr, 100, dai );
            assert(!otc.buy(id, 50));
        }
    }
    function testFailOverflow() {
        if(buy_enabled){
            mkr.approve(otc, 30);
            var id = otc.offer( 30, mkr, 100, dai );
            // this should throw because of safeMul being used.
            // other buy failures will return false
            otc.buy(id, uint(-1));
        }else{
            assert(false);
        }
    }
}

contract TransferTest is DSTest {
    MarketTester user1;
    ERC20 dai;
    ERC20 mkr;
    SimpleMarket otc;
    bool buy_enabled;
    function setUp() {
        otc = new SimpleMarket();
        user1 = new MarketTester(otc);
        buy_enabled = otc.isBuyEnabled();

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        dai.transfer(user1, 100);
        user1.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);
    }
}

contract OfferTransferTest is TransferTest {
    function testOfferTransfersFromSeller() {
        var balance_before = mkr.balanceOf(this);
        var id = otc.offer( 30, mkr, 100, dai );
        var balance_after = mkr.balanceOf(this);

        assertEq(balance_before - balance_after, 30);
    }
    function testOfferTransfersToMarket() {
        var balance_before = mkr.balanceOf(otc);
        var id = otc.offer( 30, mkr, 100, dai );
        var balance_after = mkr.balanceOf(otc);

        assertEq(balance_after - balance_before, 30);
    }
}

contract BuyTransferTest is TransferTest {
    function testBuyTransfersFromBuyer() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );

            var balance_before = dai.balanceOf(user1);
            user1.doBuy(id, 30);
            var balance_after = dai.balanceOf(user1);

            assertEq(balance_before - balance_after, 100);
        }
    }
    function testBuyTransfersToSeller() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );

            var balance_before = dai.balanceOf(this);
            user1.doBuy(id, 30);
            var balance_after = dai.balanceOf(this);

            assertEq(balance_after - balance_before, 100);
        }
    }
    function testBuyTransfersFromMarket() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );

            var balance_before = mkr.balanceOf(otc);
            user1.doBuy(id, 30);
            var balance_after = mkr.balanceOf(otc);

            assertEq(balance_before - balance_after, 30);
        }
    }
    function testBuyTransfersToBuyer() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );

            var balance_before = mkr.balanceOf(user1);
            user1.doBuy(id, 30);
            var balance_after = mkr.balanceOf(user1);

            assertEq(balance_after - balance_before, 30);
        }
    }
}

contract PartialBuyTransferTest is TransferTest {
    function testBuyTransfersFromBuyer() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );

            var balance_before = dai.balanceOf(user1);
            user1.doBuy(id, 15);
            var balance_after = dai.balanceOf(user1);

            assertEq(balance_before - balance_after, 50);
        }
    }
    function testBuyTransfersToSeller() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );

            var balance_before = dai.balanceOf(this);
            user1.doBuy(id, 15);
            var balance_after = dai.balanceOf(this);

            assertEq(balance_after - balance_before, 50);
        }
    }
    function testBuyTransfersFromMarket() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );

            var balance_before = mkr.balanceOf(otc);
            user1.doBuy(id, 15);
            var balance_after = mkr.balanceOf(otc);

            assertEq(balance_before - balance_after, 15);
        }
    }
    function testBuyTransfersToBuyer() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );

            var balance_before = mkr.balanceOf(user1);
            user1.doBuy(id, 15);
            var balance_after = mkr.balanceOf(user1);

            assertEq(balance_after - balance_before, 15);
        }
    }
    function testBuyOddTransfersFromBuyer() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );

            var balance_before = dai.balanceOf(user1);
            user1.doBuy(id, 17);
            var balance_after = dai.balanceOf(user1);

            assertEq(balance_before - balance_after, 56);
        }
    }
}

contract CancelTransferTest is TransferTest {
    function testCancelTransfersFromMarket() {
        var id = otc.offer( 30, mkr, 100, dai );

        var balance_before = mkr.balanceOf(otc);
        otc.cancel(id);
        var balance_after = mkr.balanceOf(otc);

        assertEq(balance_before - balance_after, 30);
    }
    function testCancelTransfersToSeller() {
        var id = otc.offer( 30, mkr, 100, dai );

        var balance_before = mkr.balanceOf(this);
        otc.cancel(id);
        var balance_after = mkr.balanceOf(this);

        assertEq(balance_after - balance_before, 30);
    }
    function testCancelPartialTransfersFromMarket() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );
            user1.doBuy(id, 15);

            var balance_before = mkr.balanceOf(otc);
            otc.cancel(id);
            var balance_after = mkr.balanceOf(otc);

            assertEq(balance_before - balance_after, 15);
        }
    }
    function testCancelPartialTransfersToSeller() {
        if(buy_enabled){
            var id = otc.offer( 30, mkr, 100, dai );
            user1.doBuy(id, 15);

            var balance_before = mkr.balanceOf(this);
            otc.cancel(id);
            var balance_after = mkr.balanceOf(this);

            assertEq(balance_after - balance_before, 15);
        }
    }
}

contract GasTest is DSTest {
    ERC20 dai;
    ERC20 mkr;
    SimpleMarket otc;
    bool buy_enabled;
    uint id;

    function setUp() {
        otc = new SimpleMarket();
        buy_enabled = otc.isBuyEnabled();

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        mkr.approve(otc, 60);
        dai.approve(otc, 100);

        id = otc.offer( 30, mkr, 100, dai );
    }
    function testNewMarket()
        logs_gas
    {
        new SimpleMarket();
    }
    function testNewOffer()
        logs_gas
    {
        otc.offer( 30, mkr, 100, dai );
    }
    function testBuy()
        logs_gas
    {
        if(buy_enabled){
            otc.buy(id, 30);
        }
    }
    function testBuyPartial()
        logs_gas
    {
        if(buy_enabled){
            otc.buy(id, 15);
        }
    }
    function testCancel()
        logs_gas
    {
        otc.cancel(id);
    }
}
