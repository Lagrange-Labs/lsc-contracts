// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "solidity-rlp/contracts/Helper.sol";

library LibEvidenceVerifier {

    uint public constant BLOCK_HEADER_NUMBER_INDEX = 8;
    uint public constant BLOCK_HEADER_EXTRADATA_INDEX = 12;

    uint public constant CHAIN_ID_MAINNET = 1;
    uint public constant CHAIN_ID_OPTIMISM = 10;
    uint public constant CHAIN_ID_BASE = 84531;
    uint public constant CHAIN_ID_ARBITRUM_NITRO = 421613;

    function calculateBlockHash(bytes memory rlpData) public pure returns (bytes32) {
        return keccak256(rlpData);
    }

    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;
    using RLPReader for bytes;
    
    function checkAndDecodeRLP(bytes memory rlpData, bytes32 comparisonBlockHash) public pure returns (RLPReader.RLPItem[] memory) {
        bytes32 blockHash = keccak256(rlpData);
        require(blockHash == comparisonBlockHash, "Hash of RLP data diverges from comparison block hash");
        RLPReader.RLPItem[] memory decoded = rlpData.toRlpItem().toList();
	return decoded;
    }

    function verifyBlockNumber(uint comparisonNumber, bytes memory rlpData, bytes32 comparisonBlockHash, uint256 chainID) external pure returns (bool) {
    /*
        if (chainID == CHAIN_ID_ARBITRUM_NITRO) {
            // 
        }
    */
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
}
