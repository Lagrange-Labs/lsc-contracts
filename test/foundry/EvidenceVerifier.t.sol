// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/protocol/EvidenceVerifier.sol";
import "../../contracts/interfaces/ILagrangeCommittee.sol";
import "../../contracts/interfaces/IEvidenceVerifier.sol";

contract EvidenceVerifierTest is Test {
    EvidenceVerifier public verifier;
    Evidence evidence;

    function setUp() public {
        verifier = new EvidenceVerifier(ILagrangeCommittee(address(0)), IStakeManager(address(0)));

        evidence.operator = address(0x516D6C27C23CEd21BF7930E2a01F0BcA9A141a0d);
        evidence.blockHash = 0xafe58890693444d9116c940a5ff4418723e7f75869b30c9d8e4528e147cb4b7f;
        evidence.currentCommitteeRoot = 0x9c11dac30afc6d443066d31976ece1015527da8d1c6f5e540ce649970f2e9129;
        evidence.nextCommitteeRoot = 0x0538f196c8c36715f077e40f62b62795d83a4d82fddff30511375c9f6917a26b;
        evidence.chainID = 1337;
        evidence.blockNumber = 0x3;
        evidence.l1BlockNumber = 0x1;
        evidence.blockSignature =
            hex"b3ad75be8554f25871e395268a2aec2d1d65003e70d4cd5b1560f37a85c7917fb82d66e22829c333043b4d6c3434151b13fb6b60d06f150132390f177c7891e97213c34cc843937f5e372035dcbb8be32ba6bf61a1545bdc2aafabd0fb60c5a4";
        evidence.commitSignature =
            hex"92111f5796ebde2f4b56c3765eaa55a3b6e239831ac08ebbdf62b1319545d6cf5399fc2d00b0f8dc7249483db038c62a67a992e005f7964968ae987c62c8613b1c";
    }

    function testGetCommitHash() public {
        bytes32 commitHash = verifier.getCommitHash(evidence);

        assertEq(commitHash, 0xb63341673d94ef9a7e86926be02601f40b1dc500be8a2b96bcc5b36d6c92690d);
    }

    function testVerifyECDSASignature() public {
        bool result = verifier.checkCommitSignature(evidence);

        assertTrue(result);
    }
}
