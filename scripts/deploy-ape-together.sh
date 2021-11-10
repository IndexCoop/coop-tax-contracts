#!/usr/bin/env bash
. $(dirname $0)/common.sh
. $(dirname $0)/deploy-helpers.sh

OPERATOR=0x37e6365d4f6aE378467b0e24c9065Ce5f06D70bF

# Create Set Token
# COMPONENTS="[0xC99ab7Ffa5a4CB9a06Ee68652fE74B6C59c67284]"
# UNITS="[1000000000000000000]"

# SET_TOKEN=$(createSet $COMPONENTS $UNITS $OPERATOR "ApeTogether" "APE")

# echo "Set Token Address: $SET_TOKEN"

# # Deploy OwlNFT
# NFT_ADDR=$(dapp create OwlNFT)
# $(dapp verify-contract src/ape-together/OwlNFT.sol:OwlNFT $NFT_ADDR)

# Deploy BaseManagerV2
SET_TOKEN=0x37e6365d4f6aE378467b0e24c9065Ce5f06D70bF
MANAGER_ARGS="$SET_TOKEN $OPERATOR $OPERATOR"
MANAGER_ADDR=$(dapp create BaseManagerV2 $MANAGER_ARGS)
$(dapp verify-contract lib/index-coop-smart-contracts/contracts/manager/BaseManagerV2.sol:BaseManagerV2 $MANAGER_ADDR $MANAGER_ARGS)


# Deploy ApeRebalanceExtension
ENG=0x37e6365d4f6aE378467b0e24c9065Ce5f06D70bF
START_TIME=1635994617
EPOCH_LENGTH=604800     # 7 days
MAX_COMPONENTS=10

REBALANCE_ARGS="$MANAGER_ADDR $GENERAL_INDEX_MODULE $NFT_ADDR $ENG $START_TIME $EPOCH_LENGTH $MAX_COMPONENTS"
REBALANCE_ADDR=$(dapp create ApeRebalanceExtension $REBALANCE_ARGS)
$(dapp verify-contract src/ape-together/ApeRebalanceExtension.sol:ApeRebalanceExtension $REBALANCE_ADDR $REBALANCE_ARGS)