We want to integrate btc relay to Maker Market.

There are many ways this could be imlemented and developed. For now
we will try and generate a proof of concept, which can then be made
into a minimum viable product.

Constraints:

1. separate order book from SimpleMarket

We'll start by making a PoC in the backend. This will require
creating a new contract in which BTC/TOKEN offers can be made, where
TOKEN is any of the tokens that SimpleMarket can accept.


Backend workflow:

Selling token for BTC:


Seller calls .offer(100, 'MKR', 5, 'BTC', BTCADDRESS)

    anything but 'BTC' should fail (for now)

    BTCADDRESS is a seller controlled address at which they expect
    payment.

    assert BTCADDRESS is valid?

    entry into orderbook with orderID

    100 MKR transferFrom seller


Buyer calls .buy(orderid)

    Offer is LOCKED to buyer address

    Contract awaits confirmation of btc tx to BTCADDRESS

    On confirmation, funds transferred to buyer.

    Needs anti abuse consideration, or someone can lock all orders.


    Offer has a bool `locked` attribute.

    When an Offer is Locked, it cannot be canceled by the creator.
    Only btc payment verification or a timeout can unlock an offer.



Selling BTC for token:

Flow here is different to above. We can't transferFrom BTC from the
seller because we have no way to interact with the Bitcoin chain.

We need to make a provisional offer, that only has token transfer
when it is filled and btc transaction is verified.


Seller calls .offer(5, 'BTC', 100, 'MKR')

    entry into orderbook


Buyer calls .buy(orderid, BTCADDRESS)

    transferFrom buyer

    Offer is LOCKED

    Contract awaits confirmation of btc tx to BTCADDRESS


Problem here: the seller needs to be paying attention to the
orderbook, or they'll miss the transaction window. This isn't
great.

Really, they should be automating this, with a bot that watches the
orderbook that can effect the btc transfer.
