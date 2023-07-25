// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Common} from "./Common.sol";
import "solidity-rlp/contracts/Helper.sol";
import {OptimismVerifier} from "./OptimismVerifier.sol";
import {ArbitrumVerifier} from "./ArbitrumVerifier.sol";

contract EvidenceVerifier {
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
        bytes rawBlockHeader;
    }

    uint public constant CHAIN_ID_MAINNET = 1;
    uint public constant CHAIN_ID_OPTIMISM_BEDROCK = 420;
    uint public constant CHAIN_ID_BASE = 84531;
    uint public constant CHAIN_ID_ARBITRUM_NITRO = 421613;

    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;
    using RLPReader for bytes;

    function _verifyRawHeaderSequence(
        bytes32 latestHash,
        bytes[] calldata sequence
    ) public view returns (bool) {
        bytes32 blockHash;
        for (uint256 i = 0; i < sequence.length; i++) {
            RLPReader.RLPItem[] memory decoded = sequence[i]
                .toRlpItem()
                .toList();
            RLPReader.RLPItem memory prevHash = decoded[0]; // prevHash/parentHash
            bytes32 cmpHash = bytes32(prevHash.toUint());
            if (i > 0 && cmpHash != blockHash) return false;
            blockHash = keccak256(sequence[i]);
        }
        if (latestHash != blockHash) {
            return false;
        }
        return true;
    }

    function calculateBlockHash(
        bytes memory rlpData
    ) public pure returns (bytes32) {
        return keccak256(rlpData);
    }

    // Verify that comparisonNumber (block number) is in raw block header (rlpData) and raw block header matches comparisonBlockHash.  ChainID provides for network segmentation.
    function verifyBlockNumber(
        uint comparisonNumber,
        bytes memory rlpData,
        bytes32 comparisonBlockHash,
        uint256 chainID
    ) public pure returns (bool) {
        if (chainID == CHAIN_ID_ARBITRUM_NITRO) {
            return true;
        } else if (chainID == CHAIN_ID_OPTIMISM_BEDROCK) {
            return true;
        }

        RLPReader.RLPItem[] memory decoded = Common.checkAndDecodeRLP(
            rlpData,
            comparisonBlockHash
        );
        RLPReader.RLPItem memory blockNumberItem = decoded[
            Common.BLOCK_HEADER_NUMBER_INDEX
        ];
        uint number = blockNumberItem.toUint();
        bool res = number == comparisonNumber;
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
