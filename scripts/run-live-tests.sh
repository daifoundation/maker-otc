#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
cd ..

dapp --use solc:0.5.12 build


echo "Testing on forked mainnet (with txt.origin == msg.sender)"
export DAPP_TEST_ORIGIN=0x3be95e4159a131e56a84657c4ad4d43ec7cd865d # fool otc contract that we do direct calls
export DAPP_TEST_NUMBER=11607594
hevm dapp-test --json-file=out/dapp.sol.json --rpc=https://parity-mainnet.makerfoundation.com:8545 --match "origin"

echo "Testing indirect calls on forked mainnet (txt.origin != msg.sender)"
export DAPP_TEST_ORIGIN=0x0
hevm dapp-test --json-file=out/dapp.sol.json --rpc=https://parity-mainnet.makerfoundation.com:8545 --match "indirect"
