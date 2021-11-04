#!/usr/bin/env bash

createSet() {
    COMPONENTS=$1
    UNITS=$2
    MANAGER=$3
    NAME=$4
    SYMBOL=$5

    MODULES="[$GENERAL_INDEX_MODULE,$BASIC_ISSUANCE_MODULE]"
    CREATE_SET_ARGS="$COMPONENTS $UNITS $MODULES $MANAGER \"$NAME\" \"$SYMBOL\""

    SIG="create(address[],int256[],address[],address,string,string)"

    GAS=$(seth estimate $SET_CREATOR $SIG $CREATE_SET_ARGS)
    seth send $SET_CREATOR $SIG $CREATE_SET_ARGS --gas=$GAS

    ADDR="0x$(seth logs $SET_CREATOR | jq --slurp '.[-1].topics[1]' | cut -c28-67)"

    echo $ADDR
}