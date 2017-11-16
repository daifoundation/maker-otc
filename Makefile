SHELL = bash

export ETH_GAS = 4000000
export SOLC_FLAGS = --optimize
export ETH_GAS_PRICE=4000000000
export ETH_FROM ?= $(shell seth rpc eth_coinbase)

era = $(shell echo `date +%s`)
lifetime = $(shell echo $$((60*60*24*365)))
closetime = $(shell echo $$(($(era) + $(lifetime))))

all:; dapp build
test:; dapp test
deploy:; dapp create MatchingMarket $(closetime)
