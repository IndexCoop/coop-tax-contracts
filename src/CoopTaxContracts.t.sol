// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "ds-test/test.sol";

import "./CoopTaxContracts.sol";

contract CoopTaxContractsTest is DSTest {
    CoopTaxContracts contracts;

    function setUp() public {
        contracts = new CoopTaxContracts();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
