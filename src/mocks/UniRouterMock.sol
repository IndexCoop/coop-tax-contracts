// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

contract UniRouterMock {

    uint256 amountOut;
    address public factory;

    constructor(uint256 _amountOut, address _factory) public {
        amountOut = _amountOut;
        factory = _factory;
    }

    function getAmountsOut(uint amountIn, address[] memory path) public view returns (uint[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[path.length-1] = amountOut;
    }
}