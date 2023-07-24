// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "solidity-rlp/contracts/Helper.sol";

library Common {
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
}
