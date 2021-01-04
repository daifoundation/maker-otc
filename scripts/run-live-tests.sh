#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
cd ..

dapp build
DAPP_TEST_NUMBER=11607594 hevm dapp-test --json-file=out/dapp.sol.json --rpc=https://parity-mainnet.makerfoundation.com:8545 --match live