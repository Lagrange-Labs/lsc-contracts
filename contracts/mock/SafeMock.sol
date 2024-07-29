// SPDX-License-Identifier: BUSL-1.1

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.20;

import "@safe/contracts/Safe.sol";

contract SafeMock is Safe {
    constructor() {
        threshold = 0;
    }
}
