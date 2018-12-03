/// simple_market.sol

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

import "ds-math/math.sol";
import "erc20/erc20.sol";

contract EventfulMarket {
    event LogOffer(
        bytes32  indexed    id,
        bytes32  indexed    pair,
        address  indexed    maker,
        ERC20               sellGem,
        ERC20               buyGem,
        uint                sellAmt,
        uint                buyAmt,
        uint64              timestamp
    );
    event LogBuy(
        bytes32             id,
        bytes32  indexed    pair,
        address  indexed    maker,
        ERC20               sellGem,
        ERC20               buyGem,
        address  indexed    taker,
        uint                takeAmt,
        uint                giveAmt,
        uint64              timestamp
    );
    event LogCancel(
        bytes32  indexed    id,
        bytes32  indexed    pair,
        address  indexed    maker,
        ERC20               sellGem,
        ERC20               buyGem,
        uint                sellAmt,
        uint                buyAmt,
        uint64              timestamp
    );
}

contract SimpleMarket is EventfulMarket, DSMath {
    uint public lastOfferId;
    mapping (uint => OfferInfo) public offers;
    bool locked;

    struct OfferInfo {
        uint     oSellAmt;  // Original sellAmt, always calculate price with this
        uint     oBuyAmt;   // Original buyAmt, always calculate price with this
        uint     sellAmt;
        ERC20    sellGem;
        uint     buyAmt;
        ERC20    buyGem;
        address  owner;
        uint64   timestamp;
    }

    modifier canBuy(uint id) {
        require(isActive(id), "Offer has been canceled, taken, or never existed, thus can not be bought.");
        _;
    }

    modifier canCancel(uint id) {
        require(isActive(id), "Offer has been canceled, taken, or never existed, thus can not be canceled.");
        require(getOwner(id) == msg.sender, "Only owner can cancel offer.");
        _;
    }

    modifier canOffer {
        _;
    }

    modifier nonReentrant {
        require(!locked, "Reentrancy detected.");
        locked = true;
        _;
        locked = false;
    }

    function isActive(uint id) public view returns (bool active) {
        return offers[id].timestamp > 0;
    }

    function getOwner(uint id) public view returns (address owner) {
        return offers[id].owner;
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    function offer(uint sellAmt, ERC20 sellGem, uint buyAmt, ERC20 buyGem) public returns (uint id) {
        id = offer(sellAmt, sellGem, buyAmt, buyGem, msg.sender);
    }

    function offer(uint sellAmt, ERC20 sellGem, uint buyAmt, ERC20 buyGem, address owner)
        public
        canOffer
        nonReentrant
        returns (uint id)
    {
        require(uint128(sellAmt) == sellAmt, "Sell amount should be less than 2^129-1.");
        require(uint128(buyAmt) == buyAmt, "Buy amount should be less than 2^129-1.");
        require(sellAmt > 0, "Sell amount can not be zero.");
        require(sellGem != ERC20(0x0), "Sell token should not be a zero address.");
        require(buyAmt > 0, "Buy amount should not be zero.");
        require(buyGem != ERC20(0x0), "Buy token should not be a zero address.");
        require(sellGem != buyGem, "You should not sell the same token that you buy.");

        OfferInfo memory offerInfo;
        offerInfo.oSellAmt = sellAmt;
        offerInfo.oBuyAmt = buyAmt;
        offerInfo.sellAmt = sellAmt;
        offerInfo.sellGem = sellGem;
        offerInfo.buyAmt = buyAmt;
        offerInfo.buyGem = buyGem;
        offerInfo.owner = owner;
        offerInfo.timestamp = uint64(now);
        id = ++lastOfferId;
        offers[id] = offerInfo;

        require(sellGem.transferFrom(msg.sender, address(this), sellAmt));

        emit LogOffer(
            bytes32(id),
            keccak256(abi.encodePacked(sellGem, buyGem)),
            owner,
            sellGem,
            buyGem,
            sellAmt,
            buyAmt,
            uint64(now)
        );
    }

    // Accept given `quantity` of an offer. Transfers funds from caller to
    // offer maker, and from market to caller.
    function buy(uint id, uint quantity)
        public
        canBuy(id)
        nonReentrant
        returns (bool)
    {
        OfferInfo memory offerInfo = offers[id];
        uint spend = mul(quantity, offerInfo.oBuyAmt) / offerInfo.oSellAmt;

        require(uint128(spend) == spend, "Sell amount should be less than 2^129-1.");
        require(uint128(quantity) == quantity, "Buy amount should be less than 2^129-1.");

        // For backwards semantic compatibility.
        if (quantity == 0 || spend == 0 || quantity > offerInfo.sellAmt || spend > offerInfo.buyAmt) {
            return false;
        }

        offers[id].sellAmt = sub(offerInfo.sellAmt, quantity);
        offers[id].buyAmt = sub(offerInfo.buyAmt, spend);
        require(offerInfo.buyGem.transferFrom(msg.sender, offerInfo.owner, spend), "Buy token could not be transferred.");
        require(offerInfo.sellGem.transfer(msg.sender, quantity), "Sell token could not be transferred.");

        emit LogBuy(
            bytes32(id),
            keccak256(abi.encodePacked(offerInfo.sellGem, offerInfo.buyGem)),
            offerInfo.owner,
            offerInfo.sellGem,
            offerInfo.buyGem,
            msg.sender,
            quantity,
            spend,
            uint64(now)
        );

        if (offers[id].sellAmt == 0) {
            delete offers[id];
        }

        return true;
    }

    // Cancel an offer. Refunds offer maker.
    function cancel(uint id)
        public
        canCancel(id)
        nonReentrant
        returns (bool success)
    {
        // Read-only offer. Modify an offer by directly accessing offers[id]
        OfferInfo memory offerInfo = offers[id];
        delete offers[id];

        require(offerInfo.sellGem.transfer(offerInfo.owner, offerInfo.sellAmt), "Sell token could not be transferred.");

        emit LogCancel(
            bytes32(id),
            keccak256(abi.encodePacked(offerInfo.sellGem, offerInfo.buyGem)),
            offerInfo.owner,
            offerInfo.sellGem,
            offerInfo.buyGem,
            offerInfo.sellAmt,
            offerInfo.buyAmt,
            uint64(now)
        );

        success = true;
    }
}
