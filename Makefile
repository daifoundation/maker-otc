lifetime = 604800
export SOLC_FLAGS = --optimize

all:; dapp build
test:; dapp test

deploy:; seth send --new 0x"`cat out/ExpiringMarket.bin`" \
"ExpiringMarket(uint256)" $(lifetime) -G 3000000
