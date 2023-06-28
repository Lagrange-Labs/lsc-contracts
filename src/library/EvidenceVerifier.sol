// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "solidity-rlp/contracts/Helper.sol";

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

    uint public constant BLOCK_HEADER_NUMBER_INDEX = 8;
    uint public constant BLOCK_HEADER_EXTRADATA_INDEX = 12;

    uint public constant CHAIN_ID_MAINNET = 1;
    uint public constant CHAIN_ID_OPTIMISM = 10;
    uint public constant CHAIN_ID_BASE = 84531;
    uint public constant CHAIN_ID_ARBITRUM_NITRO = 421613;

    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;
    using RLPReader for bytes;

    function calculateBlockHash(bytes memory rlpData) public pure returns (bytes32) {
        return keccak256(rlpData);
    }
    
    function checkAndDecodeRLP(bytes memory rlpData, bytes32 comparisonBlockHash) public pure returns (RLPReader.RLPItem[] memory) {
        bytes32 blockHash = keccak256(rlpData);
        require(blockHash == comparisonBlockHash, "Hash of RLP data diverges from comparison block hash");
        RLPReader.RLPItem[] memory decoded = rlpData.toRlpItem().toList();
	return decoded;
    }

    function verifyBlockNumber(uint comparisonNumber, bytes memory rlpData, bytes32 comparisonBlockHash, uint256 chainID) public pure returns (bool) {
        if (chainID == CHAIN_ID_ARBITRUM_NITRO) {
            return true; // TODO: add the logic
        }
    
        RLPReader.RLPItem[] memory decoded = checkAndDecodeRLP(rlpData, comparisonBlockHash);
        RLPReader.RLPItem memory blockNumberItem = decoded[BLOCK_HEADER_NUMBER_INDEX];
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
    function checkCommitSignature(Evidence calldata evidence) public pure returns (bool) {
        bytes32 commitHash = getCommitHash(evidence);
        address recoveredAddress = ECDSA.recover(commitHash, evidence.commitSignature);
        return recoveredAddress == evidence.operator;
    }

    // get the hash of the commit request
    function getCommitHash(Evidence calldata evidence) public pure returns (bytes32) {
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

/*
    IRollupCore	public ArbRollupCore;
    IOutbox	public ArbOutbox;
    
    function verifyArbBlockNumber(uint comparisonNumber, bytes memory rlpData, bytes32 comparisonBlockHash, uint256 chainID) external view returns (bool) {
        RLPReader.RLPItem[] memory decoded = checkAndDecodeRLP(rlpData, comparisonBlockHash);
        RLPReader.RLPItem memory extraDataItem = decoded[BLOCK_HEADER_EXTRADATA_INDEX];
        RLPReader.RLPItem memory blockNumberItem = decoded[BLOCK_HEADER_NUMBER_INDEX];
        
        bytes32 extraData = bytes32(extraDataItem.toUintStrict()); //TODO Maybe toUint() - please test this specifically with several cases.
        bytes32 l2Hash = ArbOutbox.roots[extraData];
        if (l2Hash == bytes32(0)) {
            // No such confirmed node... TODO determine how these should be handled
            return false;
        }
        uint number = blockNumberItem.toUint();
        
        bool hashCheck = l2hash == comparisonBlockHash;
        bool numberCheck = number == comparisonNumber;
        bool res = hashCheck && numberCheck;
        return res;
    }
    
    IICanonicalTransactionChain public Optimism;
    
    function verifyOptBlockNumber(uint comparisonNumber, bytes32 comparisonBatchRoot, uint256 chainID) external view returns (bool) {
        // BlockHash does not seem to be available, but root and number can be verified onchain.
//        uint number = 
        bool res = false;
        return res;
    }
*/

}
