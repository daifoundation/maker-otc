#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
cd ..

dapp --use solc:0.5.12 build


echo "Testing on forked mainnet"
export DAPP_TEST_ORIGIN=0x47f5b4ddafd69a6271f3e15518076e0305a2c722 # fool otc contract that we do direct calls
export DAPP_TEST_NUMBER=11607594
hevm dapp-test --json-file=out/dapp.sol.json --rpc=https://parity-mainnet.makerfoundation.com:8545 --match live

echo "Testing indirect calls on forked mainnet"
export DAPP_TEST_ORIGIN=0x0
hevm dapp-test --json-file=out/dapp.sol.json --rpc=https://parity-mainnet.makerfoundation.com:8545 --match Indirect
