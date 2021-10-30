// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

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
