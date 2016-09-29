pragma solidity ^0.4.1;

contract FallbackFailer {
  function () {
    throw;
  }
}
