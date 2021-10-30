// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import { SetFixture } from "./utils/SetFixture.sol";

contract CoopTaxContracts {
    constructor() public {
        SetFixture setFixture = new SetFixture(address(this));
    }
}
