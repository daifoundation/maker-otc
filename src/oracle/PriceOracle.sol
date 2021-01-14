pragma solidity >=0.5.0;

interface PriceOracle {
  function getPriceFor(address tokenA, address tokenB, uint256 tokenAAmt) external returns (uint256);
}