##### MakerOTC

[![MKROTC Header](https://ipfs.pics/ipfs/QmSf9qocg51spsrgMB5G6HS33ydwtLvHjv51tyW9Z3Y4uu)]()
---
[![Slack Status](http://slack.makerdao.com/badge.svg)](https:/slack.makerdao.com)
[![Stories in Ready](https://badge.waffle.io/MakerDAO/maker-otc.png?label=ready&title=Ready)](https://waffle.io/MakerDAO/maker-otc)



This is a simple on-chain OTC market for MKR. You can either pick an order from the order book (in which case delivery will happen instantly), or submit a new order yourself. Accepted offers are always completely executed, there are no partial trades.


## Overview

This dapp uses Meteor as frontend; the contract side can be tested and deployed using dapple.

## Usage (for Users)

Ensure you have a locally running ethereum node.

## Installation (for Developers)

Requirements:

* geth `brew install ethereum` (or [`apt-get` for ubuntu](https://github.com/ethereum/go-ethereum/wiki/Installation-Instructions-for-Ubuntu))
* solidity https://solidity.readthedocs.org/en/latest/installing-solidity.html
* meteor `curl https://install.meteor.com/ | sh`
* Global dapple, `npm install -g dapple meteor-build-client`

Clone and install:

```bash
git clone https://github.com/MakerDAO/maker-otc
cd maker-otc
git submodule update --init --recursive
```

## Usage (for Developers)

There is a helpful blockchain script for development, which will use a clever mining script similar to Embark. This is entirely optional; you can use any testnet config via RPC on port 8545 and deploy via dapple as normal.

To start the blockchain script:

```bash
npm run blockchain
```

In a new terminal window, you can then build and deploy the dapp:

```bash
npm run deploy
```
To run the frontend, start meteor:

```bash
cd frontend && meteor
```

You can access the user interface on [http://localhost:3000/](http://localhost:3000/)

If you find that dapple is deploying to EVM rather than than geth, please modify `~/.dapplerc`:

```yaml
environments:
  default:
    # comment out default config
    # ethereum: internal
    # replace with real ethereum node
    ethereum:
      host: localhost
      port: '8545'
```

## TODOs
```
- Use wei (10^18) denominations
- USD Price estimation
- MakerUser integration
- Check that the contract actually exists
- UI improvements to show actions as a label instead of with colors

- Deploy to testnet
```

## Icebox
```
- Mist integration
- Estimate gas properly
```

## Acknowledgements
* Atomic Trade contract by [Nikolai Mushegian](https://github.com/nmushegian)
* User interface design by [Daniel Brockman](https://github.com/dbrock)
* Blockchain Script by [Chris Hitchcott](https://github.com/hitchcott)
