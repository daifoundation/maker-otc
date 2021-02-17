# This is a simple on-chain OTC market for ERC20-compatible tokens.

This repository contains implementation of the protocol to exchange ERC20 compliant tokens using fully decentralized, on-chain order book and matching engine. The protocol is used by OasisDEX, eth2dai.com and many other DeFi projects. 


## Development

```
./scripts/run-tests.sh # run unit tests
./scripts/run-live-tests.sh # runs tests against the mainnet
```

## Design Consideration

The protocol uses on-chain order book and matching engine. The primary advantage of such approach is that the liquidity is avaiable for other smart contracts that can access it in one atomic ethereum transaction. The second advantage is that the protocol is fully decentralized without any need for an operator. 

Order book for each market is implemented as two double-linked sorted lists, one for each side of the market. At any one time the list should be sorted. 

The second important design choice is the use of the Escrow model for Makers - every order on the order book needs to be "backed up" by the liquidity that is escrowed in the contract. Although such approach locks down liquidity, it guarantees zero-risk, instantenous settlement. 

## API

Please refer to [https://oasisdex.com/docs/references/smart-contract].