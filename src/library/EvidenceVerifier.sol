// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {OptimismVerifier} from "./OptimismVerifier.sol";
import {ArbitrumVerifier} from "./ArbitrumVerifier.sol";
import {ISlashingSingleVerifierTriage} from "../interfaces/ISlashingSingleVerifierTriage.sol";
import {ISlashingAggregateVerifierTriage} from "../interfaces/ISlashingAggregateVerifierTriage.sol";
import {Common} from "./Common.sol";

contract EvidenceVerifier is Common {
    // Evidence is the data structure to store the slashing evidence.
    struct Evidence {
        address operator;
        bytes32 blockHash;
        bytes32 correctBlockHash;
        bytes32 currentCommitteeRoot;
        bytes32 correctCurrentCommitteeRoot;
        bytes32 nextCommitteeRoot;
        bytes32 correctNextCommitteeRoot;
        uint256 blockNumber;
        uint256 epochBlockNumber;
        bytes blockSignature; // 96-byte
        bytes commitSignature; // 65-byte
        uint32 chainID;
        bytes attestBlockHeader;
        //bytes checkpointBlockHeader;
        bytes sigProof;
        bytes aggProof;
    }

    uint256 public constant CHAIN_ID_MAINNET = 1;
    uint256 public constant CHAIN_ID_OPTIMISM_BEDROCK = 420;
    uint256 public constant CHAIN_ID_BASE = 84531;
    uint256 public constant CHAIN_ID_ARBITRUM_NITRO = 421613;

    OptimismVerifier OptVerify;
    ArbitrumVerifier ArbVerify;

    function setArbAddr(ArbitrumVerifier _arb) public {
        ArbVerify = _arb;
    }

    function setOptAddr(OptimismVerifier _opt) public {
        OptVerify = _opt;
    }

    function getArbAddr() public view returns (address /*onlyOwner*/ ) {
        return address(ArbVerify);
    }

    function getOptAddr() public view returns (address /*onlyOwner*/ ) {
        return address(OptVerify);
    }

    function calculateBlockHash(bytes memory rlpData) public pure returns (bytes32) {
        return keccak256(rlpData);
    }

    // Verify that comparisonNumber (block number) is in raw block header (rlpData) and raw block header matches comparisonBlockHash.  ChainID provides for network segmentation.
    function verifyBlockNumber(
        uint256 comparisonNumber,
        bytes memory rlpData,
        bytes32 comparisonBlockHash,
        uint256 chainID
    ) public pure returns (bool) {
        bool res = _verifyBlockNumber(comparisonNumber, rlpData, comparisonBlockHash, chainID);
        bool success = false;
        if (chainID == CHAIN_ID_ARBITRUM_NITRO) {
            //            (success, checkpoint) = verifyArbBlock();
        } else if (chainID == CHAIN_ID_OPTIMISM_BEDROCK) {
            //            (success, checkpoint) = verifyOptBlock();
        }
        if (!success) {}
        return res;
    }

    function toUint(bytes memory src) internal pure returns (uint256) {
        uint256 value;
        for (uint256 i = 0; i < src.length; i++) {
            value = value * 256 + uint256(uint8(src[i]));
        }
        return value;
    }

    // check the evidence identity and the ECDSA signature
    function checkCommitSignature(Evidence calldata evidence) public pure returns (bool) {
        bytes32 commitHash = getCommitHash(evidence);
        address recoveredAddress = ECDSA.recover(commitHash, evidence.commitSignature);
        return recoveredAddress == evidence.operator;
    }

    // get the hash of the commit request
    function getCommitHash(Evidence calldata evidence) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                evidence.blockHash,
                evidence.currentCommitteeRoot,
                evidence.nextCommitteeRoot,
                evidence.blockNumber,
                evidence.epochBlockNumber,
                evidence.blockSignature,
                evidence.chainID
            )
        );
    }

    function _getChainHeader(bytes32 blockHash, uint256 blockNumber, uint32 chainID)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 _chainHeader1;
        uint256 _chainHeader2;

        bytes memory chainHeader = abi.encodePacked(blockHash, uint256(blockNumber), uint32(chainID));

        bytes32 chHash = keccak256(chainHeader);
        bytes16 ch1 = bytes16(chHash);
        bytes16 ch2 = bytes16(chHash << 128);

        bytes32 _ch1 = bytes32(ch1) >> 128;
        bytes32 _ch2 = bytes32(ch2) >> 128;

        _chainHeader1 = uint256(_ch1);
        _chainHeader2 = uint256(_ch2);

        return (_chainHeader1, _chainHeader2);
    }

    function _computeRouteIndex(uint256 committeeSize) internal pure returns (uint256) {
        uint256 routeIndex = 1;
        while (routeIndex < committeeSize) {
            routeIndex = routeIndex * 2;
        }
        return routeIndex;
    }
}
