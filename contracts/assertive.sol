pragma solidity ^0.4.8;

contract Assertive {
    function assert(bool assertion) internal {
        if (!assertion) throw;
    }
}
