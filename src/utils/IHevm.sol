// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

interface IHevm {
    function warp(uint) external;
    function roll(uint) external;
    function store(address,bytes32,bytes32) external;
    function load(address,bytes32) external returns (bytes32);
}