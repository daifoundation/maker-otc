pragma solidity ^0.4.8;

contract FallbackFailer {
  function () {
    throw;
  }
}
