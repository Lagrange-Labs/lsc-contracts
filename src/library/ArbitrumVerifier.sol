// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Common} from "./Common.sol";
import "solidity-rlp/contracts/Helper.sol";
import "../mock/arbitrum/IOutbox.sol";

contract ArbitrumVerifier {

    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;
    using RLPReader for bytes;

    function verifyArbBlock(
        IOutbox ArbOutbox,
	bytes memory rlpData,
	bytes32 comparisonBlockHash,
	bytes calldata headerProof
    ) external view returns (bool,bytes32) {
        RLPReader.RLPItem[] memory decoded = Common.checkAndDecodeRLP(rlpData, comparisonBlockHash);
        RLPReader.RLPItem memory extraDataItem = decoded[Common.BLOCK_HEADER_EXTRADATA_INDEX];
        RLPReader.RLPItem memory blockNumberItem = decoded[Common.BLOCK_HEADER_NUMBER_INDEX];
        uint number = blockNumberItem.toUint();
        
        bytes32 extraData = bytes32(extraDataItem.toUintStrict()); //TODO Maybe toUint() - please test this specifically with several cases.
        bytes32 l2Hash = ArbOutbox.roots(extraData);
        if (l2Hash == bytes32(0)) {
            // No such confirmed node... TODO determine how these should be handled
            return (false,bytes32(0));
        }
        
        //bool hashCheck = l2hash == comparisonBlockHash;
        //bool numberCheck = number == comparisonNumber;
        //bool res = hashCheck && numberCheck;
	bool res = true;
        return (res,l2Hash);
    }
    
}
