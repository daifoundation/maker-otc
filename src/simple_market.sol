pragma solidity ^0.4.18;

import "ds-math/math.sol";
import "erc20/erc20.sol";

contract EventfulMarket {
    event LogItemUpdate(uint id);
    event LogTrade(uint sellAmt, address indexed sellGem, uint buyAmt, address indexed buyGem);
    event LogMake(
        bytes32  indexed  id,
        bytes32  indexed  pair,
        address  indexed  maker,
        ERC20             sellGem,
        ERC20             buyGem,
        uint128           sellAmt,
        uint128           buyAmt,
        uint64            timestamp
    );
    event LogTake(
        bytes32           id,
        bytes32  indexed  pair,
        address  indexed  maker,
        ERC20             sellGem,
        ERC20             buyGem,
        address  indexed  taker,
        uint128           takeAmt,
        uint128           giveAmt,
        uint64            timestamp
    );
    event LogKill(
        bytes32  indexed  id,
        bytes32  indexed  pair,
        address  indexed  maker,
        ERC20             sellGem,
        ERC20             buyGem,
        uint128           sellAmt,
        uint128           buyAmt,
        uint64            timestamp
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
        require(isActive(id));
        _;
    }

    modifier canCancel(uint id) {
        require(isActive(id));
        require(getOwner(id) == msg.sender);
        _;
    }

    modifier canOffer {
        _;
    }

    modifier synchronized {
        require(!locked);
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

    // Accept given `quantity` of an offer. Transfers funds from caller to
    // offer maker, and from market to caller.
    function buy(uint id, uint quantity)
        public
        canBuy(id)
        synchronized
        returns (bool)
    {
        OfferInfo memory offer = offers[id];
        uint spend = mul(quantity, offer.oBuyAmt) / offer.oSellAmt;

        require(uint128(spend) == spend);
        require(uint128(quantity) == quantity);

        // For backwards semantic compatibility.
        if (quantity == 0 || spend == 0 || quantity > offer.sellAmt || spend > offer.buyAmt)
        {
            return false;
        }

        offers[id].sellAmt = sub(offer.sellAmt, quantity);
        offers[id].buyAmt = sub(offer.buyAmt, spend);
        require(offer.buyGem.transferFrom(msg.sender, offer.owner, spend));
        require(offer.sellGem.transfer(msg.sender, quantity));

        emit LogItemUpdate(id);
        emit LogTake(
            bytes32(id),
            keccak256(abi.encodePacked(offer.sellGem, offer.buyGem)),
            offer.owner,
            offer.sellGem,
            offer.buyGem,
            msg.sender,
            uint128(quantity),
            uint128(spend),
            uint64(now)
        );
        emit LogTrade(quantity, offer.sellGem, spend, offer.buyGem);

        if (offers[id].sellAmt == 0) {
            delete offers[id];
        }

        return true;
    }

    // Cancel an offer. Refunds offer maker.
    function cancel(uint id)
        public
        canCancel(id)
        synchronized
        returns (bool success)
    {
        // Read-only offer. Modify an offer by directly accessing offers[id]
        OfferInfo memory offer = offers[id];
        delete offers[id];

        require(offer.sellGem.transfer(offer.owner, offer.sellAmt));

        emit LogItemUpdate(id);
        emit LogKill(
            bytes32(id),
            keccak256(abi.encodePacked(offer.sellGem, offer.buyGem)),
            offer.owner,
            offer.sellGem,
            offer.buyGem,
            uint128(offer.sellAmt),
            uint128(offer.buyAmt),
            uint64(now)
        );

        success = true;
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    function offer(uint sellAmt, ERC20 sellGem, uint buyAmt, ERC20 buyGem)
        public
        canOffer
        synchronized
        returns (uint id)
    {
        require(uint128(sellAmt) == sellAmt);
        require(uint128(buyAmt) == buyAmt);
        require(sellAmt > 0);
        require(sellGem != ERC20(0x0));
        require(buyAmt > 0);
        require(buyGem != ERC20(0x0));
        require(sellGem != buyGem);

        OfferInfo memory info;
        info.oSellAmt = sellAmt;
        info.oBuyAmt = buyAmt;
        info.sellAmt = sellAmt;
        info.sellGem = sellGem;
        info.buyAmt = buyAmt;
        info.buyGem = buyGem;
        info.owner = msg.sender;
        info.timestamp = uint64(now);
        id = ++lastOfferId;
        offers[id] = info;

        require(sellGem.transferFrom(msg.sender, this, sellAmt));

        emit LogItemUpdate(id);
        emit LogMake(
            bytes32(id),
            keccak256(abi.encodePacked(sellGem, buyGem)),
            msg.sender,
            sellGem,
            buyGem,
            uint128(sellAmt),
            uint128(buyAmt),
            uint64(now)
        );
    }
}
