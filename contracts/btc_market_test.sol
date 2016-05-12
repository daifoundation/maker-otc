import 'maker-user/user_test.sol';
import 'btc_market.sol';

contract MockBTCRelay {
    BTCTxParser parser;
    function MockBTCRelay() {
        parser = new BTCTxParser();
    }
    function relayTx(bytes rawTransaction, int256 transactionIndex,
                     int256[] merkleSibling, int256 blockHash,
                     int256 contractAddress)
        returns (int256)
    {
        // see testRelayTx for full tx details
        bytes memory _txHash = "\x29\xc0\x2a\x5d\x57\x29\x30\xe6\xd3\xde\x6f\xad\x45\xbb\xfd\x8d\x1a\x73\x22\x0f\x86\xf1\xad\xf4\xcd\x1d\xe6\x33\x2c\x33\xac\x3c";
        var txHash = parser.getBytesLE(_txHash, 0, 32);
        var processor = MockProcessor(contractAddress);
        return processor.processTransaction(rawTransaction, txHash);
    }
}

contract MockProcessor {
    function processTransaction(bytes txBytes, uint256 txHash)
        returns (int256) {}
}

contract BTCMarketTest is Test
                           , MakerUserGeneric(new MakerUserMockRegistry())
                           , EventfulMarket
{
    MakerUserTester user1;
    MakerUserTester user2;
    BTCMarket otc;
    MockBTCRelay relay;
    BTCTxParser parser;

    function setUp() {
        relay = new MockBTCRelay();
        otc = new BTCMarket(_M, relay);
        parser = new BTCTxParser();
        user1 = new MakerUserTester(_M);
        user1._target(otc);
        user2 = new MakerUserTester(_M);
        user2._target(otc);
        transfer(user1, 100, "DAI");
        user1.doApprove(otc, 100, "DAI");
        approve(otc, 30, "MKR");
    }
    function testOfferBuyBitcoin() {
        bytes20 seller_btc_address = 0x123;
        var id = otc.offer(30, "MKR", 10, "BTC", seller_btc_address);
        assertEq(id, 1);
        assertEq(otc.last_offer_id(), id);

        var (sell_how_much, sell_which_token,
             buy_how_much, buy_which_token) = otc.getOffer(id);

        assertEq(sell_how_much, 30);
        assertEq32(sell_which_token, "MKR");

        assertEq(buy_how_much, 10);
        assertEq32(buy_which_token, "BTC");

        assertEq20(otc.getBtcAddress(id), seller_btc_address);
    }
    function testFailOfferSellBitcoin() {
        otc.offer(30, "BTC", 10, "MKR", 0x11);
    }
    function testFailOfferBuyNotBitcoin() {
        otc.offer(30, "MKR", 10, "DAI", 0x11);
    }
    function testOfferTransferFrom() {
        var my_mkr_balance_before = balanceOf(this, "MKR");
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        var my_mkr_balance_after = balanceOf(this, "MKR");

        var transferred = my_mkr_balance_before - my_mkr_balance_after;

        assertEq(transferred, 30);
    }
    function testBuyLocking() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        assertEq(otc.isLocked(id), false);
        BTCMarket(user1).buy(id);
        assertEq(otc.isLocked(id), true);
    }
    function testCancelUnlocked() {
        var my_mkr_balance_before = balanceOf(this, "MKR");
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        var my_mkr_balance_after = balanceOf(this, "MKR");
        otc.cancel(id);
        var my_mkr_balance_after_cancel = balanceOf(this, "MKR");

        var diff = my_mkr_balance_before - my_mkr_balance_after_cancel;
        assertEq(diff, 0);
    }
    function testFailCancelInactive() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        otc.cancel(id);
        otc.cancel(id);
    }
    function testFailCancelNonOwner() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        BTCMarket(user1).cancel(id);
    }
    function testFailCancelLocked() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        BTCMarket(user1).buy(id);
        otc.cancel(id);
    }
    function testFailBuyLocked() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        BTCMarket(user1).buy(id);
        BTCMarket(user2).buy(id);
    }
    function testConfirm() {
        // after calling `buy` and sending bitcoin, buyer should call
        // `confirm` to associate the offer with a bitcoin transaction hash
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        BTCMarket(user1).buy(id);

        assertEq(otc.isConfirmed(id), false);
        var txHash = 1234;
        BTCMarket(user1).confirm(id, txHash);
        assertEq(otc.isConfirmed(id), true);
    }
    function testFailConfirmNonBuyer() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        BTCMarket(user1).buy(id);
        BTCMarket(user2).confirm(id, 123);
    }
    function testGetOfferByTxHash() {
        var id = otc.offer(30, "MKR", 10, "BTC", 0x11);
        BTCMarket(user1).buy(id);

        var txHash = 1234;
        BTCMarket(user1).confirm(id, txHash);
        assertEq(otc.getOfferByTxHash(txHash), id);
    }
    function testLinkedRelay() {
        assertEq(otc.getRelay(), relay);
    }
    function testRelayTx() {
        var fail = _relayTx();
        // return 1 => unsuccessful check.
        assertEq(fail, 1);

        // see _relayTx for associated transaction
        bytes memory _txHash = "\x29\xc0\x2a\x5d\x57\x29\x30\xe6\xd3\xde\x6f\xad\x45\xbb\xfd\x8d\x1a\x73\x22\x0f\x86\xf1\xad\xf4\xcd\x1d\xe6\x33\x2c\x33\xac\x3c";
        // convert hex txHash to uint
        var txHash = parser.getBytesLE(_txHash, 0, 32);

        var id = otc.offer(30, "MKR", 10, "BTC", 0x8078624453510cd314398e177dcd40dff66d6f9e);
        BTCMarket(user1).buy(id);
        BTCMarket(user1).confirm(id, txHash);

        var success = _relayTx();
        // return 0 => successful check.
        assertEq(success, 0);
    }
    function _relayTx() returns (int256) {
        // txid: 29c02a5d572930e6d3de6fad45bbfd8d1a73220f86f1adf4cd1de6332c33ac3c
        // txid literal: \x29\xc0\x2a\x5d\x57\x29\x30\xe6\xd3\xde\x6f\xad\x45\xbb\xfd\x8d\x1a\x73\x22\x0f\x86\xf1\xad\xf4\xcd\x1d\xe6\x33\x2c\x33\xac\x3c
        // value: 12345678
        // value: 11223344
        // address: 1CiHhyL4BuD21EJYJBFfUgRKyjPGgB3pVd
        // address: 1LG1HY5P53rkUwcwaXAxx1432UDCyfVq9M
        // script: OP_DUP OP_HASH160 8078624453510cd314398e177dcd40dff66d6f9e OP_EQUALVERIFY OP_CHECKSIG
        // script: OP_DUP OP_HASH160 d340de07e3d72fe70c2d18493e6e3d4c4a3f4ce3 OP_EQUALVERIFY OP_CHECKSIG
        // hex: 0100000001a58cbbcbad45625f5ed1f20458f393fe1d1507e254265f09d9746232da4800240000000000ffffffff024e61bc00000000001976a9148078624453510cd314398e177dcd40dff66d6f9e88ac3041ab00000000001976a914d340de07e3d72fe70c2d18493e6e3d4c4a3f4ce388ac00000000
        // hex literal: \x01\x00\x00\x00\x01\xa5\x8c\xbb\xcb\xad\x45\x62\x5f\x5e\xd1\xf2\x04\x58\xf3\x93\xfe\x1d\x15\x07\xe2\x54\x26\x5f\x09\xd9\x74\x62\x32\xda\x48\x00\x24\x00\x00\x00\x00\x00\xff\xff\xff\xff\x02\x4e\x61\xbc\x00\x00\x00\x00\x00\x19\x76\xa9\x14\x80\x78\x62\x44\x53\x51\x0c\xd3\x14\x39\x8e\x17\x7d\xcd\x40\xdf\xf6\x6d\x6f\x9e\x88\xac\x30\x41\xab\x00\x00\x00\x00\x00\x19\x76\xa9\x14\xd3\x40\xde\x07\xe3\xd7\x2f\xe7\x0c\x2d\x18\x49\x3e\x6e\x3d\x4c\x4a\x3f\x4c\xe3\x88\xac\x00\x00\x00\x00

        bytes memory mockBytes = "\x01\x00\x00\x00\x01\xa5\x8c\xbb\xcb\xad\x45\x62\x5f\x5e\xd1\xf2\x04\x58\xf3\x93\xfe\x1d\x15\x07\xe2\x54\x26\x5f\x09\xd9\x74\x62\x32\xda\x48\x00\x24\x00\x00\x00\x00\x00\xff\xff\xff\xff\x02\x4e\x61\xbc\x00\x00\x00\x00\x00\x19\x76\xa9\x14\x80\x78\x62\x44\x53\x51\x0c\xd3\x14\x39\x8e\x17\x7d\xcd\x40\xdf\xf6\x6d\x6f\x9e\x88\xac\x30\x41\xab\x00\x00\x00\x00\x00\x19\x76\xa9\x14\xd3\x40\xde\x07\xe3\xd7\x2f\xe7\x0c\x2d\x18\x49\x3e\x6e\x3d\x4c\x4a\x3f\x4c\xe3\x88\xac\x00\x00\x00\x00";
        int256 txIndex = 100;
        int256[] memory siblings;
        int256 blockHash = 100;
        int256 contractAddress = int256(otc);

        return relay.relayTx(mockBytes, txIndex, siblings, blockHash, contractAddress);
    }
}
