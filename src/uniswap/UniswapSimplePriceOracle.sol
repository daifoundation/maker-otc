pragma solidity >=0.5.0;

import "./UniswapLibrary.sol";

contract UniswapSimplePriceOracle {
    address uniswapFactory;

    constructor(address _uniswapFactory) public {
        uniswapFactory = _uniswapFactory;
    }

    function getPriceFor(address tokenA, address tokenB, uint256 tokenAAmt) public view returns (uint256) {
      (uint reserve0, uint reserve1) = UniswapV2Library.getReserves(uniswapFactory, tokenA, tokenB);
        uint256 dust = UniswapV2Library.getAmountOut(tokenAAmt, reserve0, reserve1);

        return dust;
    }
}
