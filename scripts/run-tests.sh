#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
cd ..

LIVE_TESTS_FILE="matching_market_live.t.sol"

function clean() {
    mv "/tmp/$LIVE_TESTS_FILE" ./src/
}
trap clean EXIT

mv "./src/$LIVE_TESTS_FILE" /tmp

export DAPP_TEST_ORIGIN=0x3be95e4159a131e56a84657c4ad4d43ec7cd865d # this address is needed to fool smart contract to think that we are making a direct calls (HEVM limitation)
dapp --use solc:0.5.12 test
