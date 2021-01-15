pragma solidity ^0.5.12;

import "ds-test/test.sol";
import "./matching_market.sol";
import "./oracle/UniswapSimplePriceOracle.sol";

contract LiveTest is DSTest {
    function test_originSetMinSellForWETH() public {
        // mainnet addresses
        address uniswapFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        UniswapSimplePriceOracle priceOracle = new UniswapSimplePriceOracle(uniswapFactory);
        MatchingMarket otc = new MatchingMarket(dai, 10 ether, address(priceOracle));
        
        otc.setMinSell(ERC20(weth));

        uint256 expectedWethAmount = 8207693541443256; // 10 DAI in eth
        assertEq(otc.getMinSell(ERC20(weth)), expectedWethAmount);
    }

    function testFail_originSetMinSellForDAI() public {
        // mainnet addresses
        address uniswapFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

        UniswapSimplePriceOracle priceOracle = new UniswapSimplePriceOracle(uniswapFactory);
        MatchingMarket otc = new MatchingMarket(dai, 10 ether, address(priceOracle));
        
        // this reverts
        otc.setMinSell(ERC20(dai));
    }

    function test_originSetMinSellForBAT() public {
        // mainnet addresses
        address uniswapFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        address bat = 0x0D8775F648430679A709E98d2b0Cb6250d2887EF;

        UniswapSimplePriceOracle priceOracle = new UniswapSimplePriceOracle(uniswapFactory);
        MatchingMarket otc = new MatchingMarket(dai, 10 ether, address(priceOracle));
        
        otc.setMinSell(ERC20(bat));

        uint256 expectedBatAmount = 37835208948564443771; // 10 DAI in bat
        assertEq(otc.getMinSell(ERC20(bat)), expectedBatAmount);
    }
}

contract IndirectCallsTest is DSTest {
    function testFail_indirectCallToSetMinSell() public {
        // mainnet addresses
        address uniswapFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        address bat = 0x0D8775F648430679A709E98d2b0Cb6250d2887EF;

        UniswapSimplePriceOracle priceOracle = new UniswapSimplePriceOracle(uniswapFactory);
        MatchingMarket otc = new MatchingMarket(dai, 10 ether, address(priceOracle));

        // fails
        otc.setMinSell(ERC20(bat));
    }
}
