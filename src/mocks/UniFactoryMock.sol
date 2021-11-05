// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

contract UniFactoryMock {
    address pair;

    constructor(address _pair) public {
        pair = _pair;
    }

    function getPair(address /* _token0 */, address /* _token1 */) external view returns (address) {
        return pair;
    }
}