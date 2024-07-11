// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IBLSKeyChecker {
    struct BLSKeyWithProof {
        uint256[2][] blsG1PublicKeys;
        uint256[2][2] aggG2PublicKey;
        uint256[2] signature;
        bytes32 salt;
        uint256 expiry;
    }

    function checkBLSKeyWithProof(address operator, BLSKeyWithProof calldata keyWithProof)
        external
        view
        returns (bool);
}
