-include .env

build    :; dapp build
clean  :; dapp clean
test   :; dapp test

deploy :; @./scripts/deploy-ape-together.sh