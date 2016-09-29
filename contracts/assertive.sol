pragma solidity ^0.4.1;

contract Assertive {
    function assert(bool assertion) internal {
        if (!assertion) throw;
    }
}
