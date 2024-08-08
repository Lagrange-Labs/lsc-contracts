// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "eigenlayer-middleware/libraries/BN254.sol";
import "../../../contracts/interfaces/IBLSKeyChecker.sol";

library BLSProofHelper {
    using BN254 for BN254.G1Point;

    function generateBLSKeyWithProof(uint256[] memory privateKeys, bytes32 messageHash)
        internal
        view
        returns (IBLSKeyChecker.BLSKeyWithProof memory keyWithProof)
    {
        uint256 length = privateKeys.length;
        keyWithProof.blsG1PublicKeys = new uint256[2][](length);
        for (uint256 i; i < length; i++) {
            BN254.G1Point memory pubKey = BN254.generatorG1().scalar_mul(privateKeys[i]);
            keyWithProof.blsG1PublicKeys[i] = [pubKey.X, pubKey.Y];
        }
        // TODO: need to calculate aggG2PublicKey

        BN254.G1Point memory aggSignature;
        for (uint256 i; i < length; i++) {
            aggSignature = aggSignature.plus(BN254.hashToG1(messageHash).scalar_mul(privateKeys[i]));
        }
        keyWithProof.signature[0] = aggSignature.X;
        keyWithProof.signature[1] = aggSignature.Y;
    }

    function calcG1PubKey(uint256 privateKey) internal view returns (uint256[2] memory g1PubKey) {
        BN254.G1Point memory pubKey = BN254.generatorG1().scalar_mul(privateKey);
        g1PubKey = [pubKey.X, pubKey.Y];
    }

    function calcG1PubKeys(uint256[] memory privateKey) internal view returns (uint256[2][] memory g1PubKeys) {
        uint256 length = privateKey.length;
        g1PubKeys = new uint256[2][](length);
        for (uint256 i; i < length; i++) {
            g1PubKeys[i] = calcG1PubKey(privateKey[i]);
        }
    }

    function generateBLSSignature(uint256[] memory privateKeys, bytes32 messageHash)
        internal
        view
        returns (uint256[2] memory signature)
    {
        uint256 length = privateKeys.length;
        BN254.G1Point memory aggSignature;
        for (uint256 i; i < length; i++) {
            aggSignature = aggSignature.plus(BN254.hashToG1(messageHash).scalar_mul(privateKeys[i]));
        }
        signature[0] = aggSignature.X;
        signature[1] = aggSignature.Y;
    }
}
