/// expiring_market.sol

//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.4.23;

import "ds-auth/auth.sol";
import "./simple_market.sol";

// Simple Market with a market lifetime. When the closeTime has been reached,
// offers can only be cancelled (offer and buy will throw).

contract ExpiringMarket is DSAuth, SimpleMarket {
    uint64 public closeTime;

    constructor(uint64 closeTime_) public {
        closeTime = closeTime_;
    }

    // After closeTime has been reached, no new offers are allowed
    modifier canOffer {
        require(!isClosed(), "Market is closed, no new offers allowed.");
        _;
    }

    // After close, no new buys are allowed
    modifier canBuy(uint id) {
        require(isActive(id), "Offer has been canceled, taken, or never existed, thus can not be bought.");
        require(!isClosed(), "Market is closed, buy is not allowed.");
        _;
    }

    // After close, anyone can cancel an offer
    modifier canCancel(uint id) {
        require(isActive(id), "Offer has been canceled, taken, or never existed, thus can not be canceled.");
        require((msg.sender == getOwner(id)) || isClosed(), "Sender is not the owner and Market is not closed");
        _;
    }

    function isClosed() public view returns (bool closed) {
        return getTime() > closeTime;
    }

    function getTime() public view returns (uint64) {
        return uint64(now);
    }
}
