import 'makeruser/user_test.sol';
import 'seller.sol';

contract AtomicSellerTest is Test
                           , MakerUserGeneric(new MakerUserMockRegistry())
                           , ItemUpdateEvent
{
    MakerUserTester user1;
    AtomicSeller otc;
    function setUp() {
        otc = new AtomicSeller(_M);
        user1 = new MakerUserTester(_M);
        user1._target(otc);
        transfer(user1, 100, "DAI");
        user1.doApprove(otc, 100, "DAI");
        approve(otc, 30, "MKR");
    }
    function testBasicTrade() {
        user1.doApprove(otc, 100, "DAI");
        var my_mkr_balance_before = balanceOf(this, "MKR");
        var my_dai_balance_before = balanceOf(this, "DAI");
        var user1_mkr_balance_before = balanceOf(user1, "MKR");
        var user1_dai_balance_before = balanceOf(user1, "DAI");

        var id = otc.offer( 30, "MKR", 100, "DAI" );
        AtomicSeller(user1).buy(id);
        var my_mkr_balance_after = balanceOf(this, "MKR");
        var my_dai_balance_after = balanceOf(this, "DAI");
        var user1_mkr_balance_after = balanceOf(user1, "MKR");
        var user1_dai_balance_after = balanceOf(user1, "DAI");
        assertEq( 30, my_mkr_balance_before - my_mkr_balance_after );
        assertEq( 100, my_dai_balance_after - my_dai_balance_before );
        assertEq( 30, user1_mkr_balance_after - user1_mkr_balance_before );
        assertEq( 100, user1_dai_balance_before - user1_dai_balance_after );

        expectEventsExact(otc);
        ItemUpdate(id);
        ItemUpdate(id);
    }
    function testCancel() {
        approve(otc, 30, "MKR");
        var id = otc.offer( 30, "MKR", 100, "DAI" );
        otc.cancel(id);

        expectEventsExact(otc);
        ItemUpdate(id);
        ItemUpdate(id);
    }

    function testFailOfferNotEnoughFunds() {
        transfer(address(0x0), balanceOf(this, "MKR")-29, "MKR");
        var id = otc.offer(30, "MKR", 100, "DAI");
    }
    function testFailBuyNotEnoughFunds() {
        throw;
        var id = otc.offer(30, "MKR", 101, "DAI");
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        user1.doApprove(otc, 101, "DAI");
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        log_named_uint("user1 dai balance before", balanceOf(user1, "DAI"));
        AtomicSeller(user1).buy(id);
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        log_named_uint("user1 dai balance after", balanceOf(user1,"DAI"));
    }
    function testFailBuyNotEnoughApproval() {
        throw;
        var id = otc.offer(30, "MKR", 100, "DAI");
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        user1.doApprove(otc, 99, "DAI");
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        log_named_uint("user1 dai balance before", balanceOf(user1, "DAI"));
        AtomicSeller(user1).buy(id);
        log_named_uint("user1 dai allowance", allowance(user1, otc, "DAI"));
        log_named_uint("user1 dai balance after", balanceOf(user1,"DAI"));
    }
}
