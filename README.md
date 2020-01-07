# This is a simple on-chain OTC market for ERC20-compatible tokens.

This repository contains implementation of the protocol to exchange ERC20 compliant tokens using fully decentralized, on-chain order book and matching engine. The protocol is used by OasisDEX, eth2dai.com and many other DeFi projects. 

## Design Consideration

The protocol uses on-chain order book and matching engine. The primary advantage of such approach is that the liquidity is avaiable for other smart contracts that can access it in one atomic ethereum transaction. The second advantage is that the protocol is fully decentralized without any need for an operator. 

Order book for each market is implemented as two double-linked sorted lists, one for each side of the market. At any one time the list should be sorted. 

The second important design choice is the use of the Escrow model for Makers - every order on the order book needs to be "backed up" by the liquidity that is escrowed in the contract. Although such approach locks down liquidity, it guarantees zero-risk, instantenous settlement. 

## API

Smart Contract API for exchange users consists of four groups of calls:

1. API for accessing sorted order book and matching engine - this is the API that will be used by most users. 
2. API for Takers to execute a special type of order - fill-or-kill - that was used for example by Oasis.Direct (or is used now by eth2dai Instant tab). This order will never stay on the order book - if it cannot be matched, the transaction will revert
3. API for accessing “unsorted order book” - largely deprecated. Unsorted order book is meant as a placeholder for orders before they will be put in the sorted order book by external actors. It could also be used for OTC trades, although there is no guarantee that the order will not be moved to the sorted order book as it can be done by anyone. Putting order into the unsorted orderbook costs much less gas (as there is no matching). This feature of the matching market will likely be removed in the next version of the contract. 
4. Administrative functions to set market parameters

### Matching Engine calls

* `getBestOffer()` - gets offer from the top of the order book - note that BUY side and SELL side are actually two different order books, for example WETHDAI and DAIWETH
* `getWorseOffer()`/`getBetterOffer()` - navigates through the order book
* `getOfferCount()` - returns the size of the order book
* `getOffer()` - returns information about the order with a given orderId 
* `buy()` - fills specific order (cherrypicks). Calling this function executes and settles the trade in one atomic transaction. This function can be called externally by the user, it is also called internally by the matching engine (see offer() method)
* `take()` - byte32 version of buy()
* `cancel()` - cancels an order with a given orderId
* `kill()` - byte32 version of cancel
* `offer(pay_amt, pay_gem, buy_amt, buy_gem, pos)` - the main API of the matching engine, **this method should be used 99% of the time !** - it tries to match the offer with the best offer on the order book and if this is not possible, it places the order on the order book of the “opposite” side of the market. There are three possible scenarios:
  1. Order is not matched and is put into the order book - sender becomes Maker
  2. Order is fully matched - sender becomes Taker
  3. Order is partially matched - both Make and Take transactions are made
Maker who is certain that their offer will not be matched should always send optional pos parameter hinting matching engine where the order in the order book should be placed. If pos is not given, matching engine will linearly scan order book from the top to find a right place for the offer - this will consume a lot of gas with potential out-of-gas error.
* `offer(pay_amt, pay_gem, buy_amt, buy_gem, pos, rounding)` - allows for overwriting rounding parameter which is set to TRUE as a default. 

### Fill-Or-Kill Orders
* `sellAllAmount(pay_gem, pay_amt, buy_gem, min_fill_amount)` - attempts to spend all pay tokens to buy specified minimum buy tokens. More tokens may be bought if it is possible. So, for example, when buying 1 ETH for 300 DAI, all 300 DAI will be spent and possibly 1.034 ETH will be bought if the current market price is 290. Transaction reverts if more than 300 DAI would have to be spent to buy 1 ETH
* `buyAllAmount(buy_gem, buy_amt, pay_gem, max_fill_amount)` - attempts to buy a specified amount of buy tokens for specified amount of pay tokens up to a certain price. So, for example, when buying 1 ETH for 300 DAI, possibly only 290 DAI will be spent if the current market price is 290. Transaction reverts if more than 300 DAI would have to be spent to buy 1 ETH, similarly to sellAllAmount().  
* `getBuyAmount(buy_gem, pay_gem, pay_amt)` - returns how much of buy_gem can be bought by paying pay_amt of pay_gem
* `getPayAmount(pay_gem, buy_gem, buy_amt)` - returns how much of pay_gem one needs to pay to buy buy_amt of buy_gem

### Unsorted List Operations
* `offer(pay_amt, pay_gem, buy_amt, buy_gem)` - creates offer in an unsorted list, 
* `make(pay_gem, buy_gem, pay_amt, buy_amt)` - byte32 version of offer(pay_amt, pay_gem, buy_amt, buy_gem()) 
* `del_rank()`
* `getFirstUnsortedOffer()`
* `getNextUnsortedOffer()`
* `isOfferSorted()`

### Administrative methods
* `stop()` - stops the market
* `setMinSell()`/`getMinSell()` - sets/gets the dust limit for a token 

