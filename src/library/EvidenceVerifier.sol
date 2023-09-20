// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {OptimismVerifier} from "./OptimismVerifier.sol";
import {ArbitrumVerifier} from "./ArbitrumVerifier.sol";
import {IRecursiveHeaderVerifier} from "../interfaces/IRecursiveHeaderVerifier.sol";
import {IOptimismVerifier} from "../interfaces/IOptimismVerifier.sol";
import {IArbitrumVerifier} from "../interfaces/IArbitrumVerifier.sol";
import {IMantleVerifier} from "../interfaces/IMantleVerifier.sol";
import {Common} from "./Common.sol";

contract EvidenceVerifier is Common, OwnableUpgradeable {
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
        bool status;
        bytes correctRawHeader;
        bytes32 checkpointBlockHash;
        bytes headerProof;
        bytes extraData;
    }

    uint public constant CHAIN_ID_MAINNET = 1;
    uint public constant CHAIN_ID_OPTIMISM_BEDROCK = 420;
    uint public constant CHAIN_ID_BASE = 84531;
    uint public constant CHAIN_ID_ARBITRUM_NITRO = 421613;
    uint public constant CHAIN_ID_MANTLE_TESTNET = 5001;

    IOptimismVerifier public OptVerify;
    IArbitrumVerifier public ArbVerify;
    IMantleVerifier   public MntVerify;
    IRecursiveHeaderVerifier public RHVerify;

    function verifyHeaderProof(
        bytes calldata headerProof
    ) public view returns (bool) {
        //1. Decode headerProof bytes to necessary inputs
        //2. Call RHVerify contract and supply decoded inputs
        //3. Return result of verification.
        return false;
    }

    function calculateBlockHash(
        bytes memory rlpData
    ) public pure returns (bytes32) {
        return keccak256(rlpData);
    }

    // Verify that comparisonNumber (block number) is in raw block header (rlpData) and raw block header matches comparisonBlockHash.  ChainID provides for network segmentation.
    function verifyBlock(
        uint comparisonNumber,
        bytes memory rlpData,
        bytes32 comparisonBlockHash,
        bytes calldata headerProof,
        bytes calldata extraData,
        uint256 chainID
    ) public view returns (bool) {
        // verify block number and hash
        bool res = _verifyBlockNumber(
            comparisonNumber,
            rlpData,
            comparisonBlockHash,
            chainID
        );
        if (!res) return false;

        // verify checkpoint
        res = false;
        if (chainID == CHAIN_ID_ARBITRUM_NITRO) {
            res = ArbVerify.verifyArbBlock(
                rlpData,
                comparisonNumber,
                comparisonBlockHash,
                headerProof,
                extraData,
                RHVerify
            );
        } else if (chainID == CHAIN_ID_OPTIMISM_BEDROCK) {
            res = OptVerify.verifyOptBlock(
                rlpData,
                comparisonNumber,
                comparisonBlockHash,
                headerProof,
                extraData,
                RHVerify
            );
        } else if (chainID == CHAIN_ID_MANTLE_TESTNET) {
            bytes memory checkpointRLP; // TODO
            res = MntVerify.verifyMntBlock(
                rlpData,
                comparisonBlockHash,
                checkpointRLP,
                headerProof,
                extraData,
                RHVerify
            );
        }
        return res;
    }

    function toUint(bytes memory src) internal pure returns (uint) {
        uint value;
        for (uint i = 0; i < src.length; i++) {
            value = value * 256 + uint(uint8(src[i]));
        }
        return value;
    }

    // check the evidence identity and the ECDSA signature
    function checkCommitSignature(
        Evidence calldata evidence
    ) public pure returns (bool) {
        bytes32 commitHash = getCommitHash(evidence);
        address recoveredAddress = ECDSA.recover(
            commitHash,
            evidence.commitSignature
        );
        return recoveredAddress == evidence.operator;
    }

    // get the hash of the commit request
    function getCommitHash(
        Evidence calldata evidence
    ) public pure returns (bytes32) {
        return
            keccak256(
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
}
