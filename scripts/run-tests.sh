#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
cd ..

dapp build

export DAPP_TEST_ORIGIN=0xb353c6c70829fd39756d165f363f72008b9ae1e3 # this address is needed to fool smart contract to think that we are making a direct calls (HEVM limitation)
dapp test
