// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBLSKeyChecker {
    struct BLSKeyWithProof {
        uint256[2][] blsG1PublicKeys;
        uint256[2][2] aggG2PublicKey;
        uint256[2] signature;
        bytes32 salt;
        uint256 expiry;
    }

    function isSaltSpent(address operator, bytes32 salt) external view returns (bool);

    function calculateKeyWithProofHash(address operator, bytes32 salt, uint256 expiry)
        external
        view
        returns (bytes32);

    function domainSeparator() external view returns (bytes32);
}
