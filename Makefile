SHELL = bash

export SETH_GAS = 3500000
export SOLC_FLAGS = --optimize

era = $(shell echo `date +%s`)
lifetime = $(shell echo $$((60*60*24*365)))
closetime = $(shell echo $$(($(era) + $(lifetime))))

all:; dapp build
test:; dapp test
deploy:; dapp create MatchingMarket $(closetime)
