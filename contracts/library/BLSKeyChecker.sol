// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BN254} from "eigenlayer-middleware/libraries/BN254.sol";

import "../interfaces/IBLSKeyChecker.sol";

abstract contract BLSKeyChecker is IBLSKeyChecker {
    using BN254 for BN254.G1Point;

    uint256 internal constant PAIRING_EQUALITY_CHECK_GAS = 120000;

    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    bytes32 public constant BLS_KEY_WITH_PROOF_TYPEHASH =
        keccak256("BLSKeyWithProof(address operator,bytes32 salt,uint256 expiry)");

    /// @custom:storage-location erc7201:lagrange.blskeychecker.storage
    struct SaltStorage {
        mapping(address => mapping(bytes32 => bool)) operatorSalts;
    }

    // keccak256(abi.encode(uint256(keccak256("lagrange.blskeychecker.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SaltStorageLocation = 0x51615ea63289f14fdd891b383e2929b2f73c675cf292e602b5fceb059f7a4700;

    function _getSaltStorage() private pure returns (SaltStorage storage $) {
        assembly {
            $.slot := SaltStorageLocation
        }
    }

    function _validateBLSKeyWithProof(address operator, BLSKeyWithProof memory keyWithProof) internal {
        require(
            keyWithProof.expiry >= block.timestamp, "BLSKeyChecker.checkBLSKeyWithProof: operator signature expired"
        );
        SaltStorage storage $ = _getSaltStorage();
        require(!$.operatorSalts[operator][keyWithProof.salt], "BLSKeyChecker.checkBLSKeyWithProof: salt already spent");

        $.operatorSalts[operator][keyWithProof.salt] = true;

        BN254.G1Point memory aggG1 = BN254.G1Point(0, 0);
        for (uint256 i = 0; i < keyWithProof.blsG1PublicKeys.length; i++) {
            aggG1 = aggG1.plus(BN254.G1Point(keyWithProof.blsG1PublicKeys[i][0], keyWithProof.blsG1PublicKeys[i][1]));
        }

        BN254.G2Point memory aggG2 = BN254.G2Point(keyWithProof.aggG2PublicKey[0], keyWithProof.aggG2PublicKey[1]);

        // check the pairing equation e(g1, aggG2) == e(aggG1, -g2)
        // to ensure that the aggregated G2 public key is correct
        (bool pairing, bool valid) =
            BN254.safePairing(BN254.generatorG1(), aggG2, aggG1, BN254.negGeneratorG2(), PAIRING_EQUALITY_CHECK_GAS);
        require(pairing && valid, "BLSKeyChecker.checkBLSKeyWithProof: invalid BLS key");

        BN254.G1Point memory sig = BN254.G1Point(keyWithProof.signature[0], keyWithProof.signature[1]);

        BN254.G1Point memory msgHash =
            BN254.hashToG1(calculateKeyWithProofHash(operator, keyWithProof.salt, keyWithProof.expiry));

        // check the BLS signature
        (pairing, valid) = BN254.safePairing(sig, BN254.negGeneratorG2(), msgHash, aggG2, PAIRING_EQUALITY_CHECK_GAS);
        require(pairing && valid, "BLSKeyChecker.checkBLSKeyWithProof: invalid BLS signature");
    }

    function isSaltSpent(address operator, bytes32 salt) public view returns (bool) {
        SaltStorage storage $ = _getSaltStorage();
        return $.operatorSalts[operator][salt];
    }

    function calculateKeyWithProofHash(address operator, bytes32 salt, uint256 expiry) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(BLS_KEY_WITH_PROOF_TYPEHASH, operator, salt, expiry));
        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));

        return digestHash;
    }

    function domainSeparator() public view returns (bytes32) {
        return
            keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256("Lagrange State Committee"), block.chainid, address(this)));
    }
}
