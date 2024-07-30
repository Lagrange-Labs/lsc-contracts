// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BN254} from "eigenlayer-middleware/libraries/BN254.sol";

import "../interfaces/IBLSKeyChecker.sol";
import "../library/BLSKeyChecker.sol";

contract BLSKeyCheckerMock is BLSKeyChecker {
    constructor() {}

    function checkBLSKeyWithProof(address operator, BLSKeyWithProof calldata keyWithProof) external returns (bool) {
        _validateBLSKeyWithProof(operator, keyWithProof);
        return true;
    }
}
