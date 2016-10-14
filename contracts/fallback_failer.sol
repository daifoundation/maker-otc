pragma solidity ^0.4.2;

contract FallbackFailer {
  function () {
    throw;
  }
}
