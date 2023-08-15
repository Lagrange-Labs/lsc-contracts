// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "solidity-rlp/contracts/Helper.sol";

contract Common {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;
    using RLPReader for bytes;

    uint public constant BLOCK_HEADER_NUMBER_INDEX = 8;
    uint public constant BLOCK_HEADER_EXTRADATA_INDEX = 12;

    function checkAndDecodeRLP(bytes memory rlpData, bytes32 comparisonBlockHash) public pure returns (RLPReader.RLPItem[] memory) {
        bytes32 blockHash = keccak256(rlpData);
        require(blockHash == comparisonBlockHash, "Hash of RLP data diverges from comparison block hash");
        RLPReader.RLPItem[] memory decoded = rlpData.toRlpItem().toList();
	return decoded;
    }

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

    function _verifyBlockNumber(
        uint comparisonNumber,
        bytes memory rlpData,
        bytes32 comparisonBlockHash,
        uint256 chainID
    ) public view returns (bool) {
        // Verify Block Number
        RLPReader.RLPItem[] memory decoded = checkAndDecodeRLP(
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
}
