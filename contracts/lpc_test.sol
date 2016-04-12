import 'dapple/test.sol';

import 'maker-user/mock.sol';
import 'maker-user/interfaces.sol';

import 'feedbase/feedbase.sol';

import 'type.sol';
import 'factory.sol';
import 'lpc.sol';

contract LPCtest is Test, MakerUser(MakerUserLinkType(0x2))
{
    FeedBase fb;
    uint64 dai_mkr;
    BasicLiquidityProvider lpc;
    BasicLiquidityProviderFactory lpc_factory;
    function setUp() {
        _M = new MakerUserMockRegistry();
        fb = new FeedBase(_M);
        lpc_factory = new BasicLiquidityProviderFactory(fb, _M);

        dai_mkr = fb.claim();
        lpc = lpc_factory.create();
    }
    function testBasics() {
        var price = toWei(10);
        fb.setFeed(dai_mkr, bytes32(price), block.timestamp + 100);
        lpc.setConfig("MKR", "DAI", true, dai_mkr, false, 0, toWei(1)/100, toWei(1)/100000);
        transfer(lpc, toWei(10), "MKR");
        var buyCost1 = lpc.buyCost(price, "MKR", toWei(1), "DAI");
        var buyCost2 = lpc.buyCost(price, "MKR", toWei(2), "DAI");
        log_uint(buyCost1);
        approve(lpc, toWei(buyCost1), "DAI");
        var before_mkr = balanceOf(this, "MKR");
        var before_dai = balanceOf(this, "DAI");
        var returned_buyCost = lpc.buy("MKR", toWei(1), "DAI");
        var after_mkr = balanceOf(this, "MKR");
        var after_dai = balanceOf(this, "DAI");
        assertEq(returned_buyCost, buyCost1);
        assertEq(after_mkr - before_mkr, toWei(1));
        assertEq(before_dai - after_dai, buyCost1);
    }
}
