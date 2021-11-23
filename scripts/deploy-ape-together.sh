#!/usr/bin/env bash
. $(dirname $0)/common.sh
. $(dirname $0)/deploy-helpers.sh

OPERATOR=0x37e6365d4f6aE378467b0e24c9065Ce5f06D70bF

# Create Set Token
COMPONENTS="[0x8f3cf7ad23cd3cadbd9735aff958023239c6a063]"
UNITS="[1000000000000000000]"

SET_TOKEN=$(createSet $COMPONENTS $UNITS $OPERATOR "ApeTogether" "APE")

# Deploy OwlNFT
NFT_ADDR=$(dapp create OwlNFT $BASE_URI)
! dapp verify-contract src/ape-together/OwlNFT.sol:OwlNFT $NFT_ADDR $BASE_URI

# Deploy BaseManagerV2
MANAGER_ARGS="$SET_TOKEN $OPERATOR $OPERATOR"
MANAGER_ADDR=$(dapp create BaseManagerV2 $MANAGER_ARGS)
! dapp verify-contract lib/index-coop-smart-contracts/contracts/manager/BaseManagerV2.sol:BaseManagerV2 $MANAGER_ADDR $MANAGER_ARGS


# Deploy ApeRebalanceExtension
MIN_WETH=15
START_TIME=1636525425
EPOCH_LENGTH=604800     # 7 days
MAX_COMPONENTS=10

REBALANCE_ARGS="$MANAGER_ADDR $GENERAL_INDEX_MODULE $NFT_ADDR $SUSHI_ROUTER $QUICKSWAP_ROUTER $WETH $MIN_WETH $START_TIME $EPOCH_LENGTH $MAX_COMPONENTS"
REBALANCE_ADDR=$(dapp create ApeRebalanceExtension $REBALANCE_ARGS)
! dapp verify-contract src/ape-together/ApeRebalanceExtension.sol:ApeRebalanceExtension $REBALANCE_ADDR $REBALANCE_ARGS


echo "Deploy Complete"
echo "Set Token Address: $SET_TOKEN"
echo "OwlNFT Address: $NFT_ADDR"
echo "Manager Address: $MANAGER_ADDR"
echo "Rebalance Extension Address: $REBALANCE_ADDR"