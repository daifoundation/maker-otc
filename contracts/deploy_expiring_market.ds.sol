pragma solidity ^0.4.2;

import "dapple/script.sol";
import "./expiring_market.sol";

contract DeployExpiringMarket is Script {
  function DeployExpiringMarket () {
    exportObject("otc", new ExpiringMarket(2 weeks));
  }
}