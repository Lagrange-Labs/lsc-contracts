// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Common} from "./Common.sol";
import "solidity-rlp/contracts/Helper.sol";
import "../mock/arbitrum/IOutbox.sol";
import {IRecursiveHeaderVerifier} from "../interfaces/IRecursiveHeaderVerifier.sol";

contract ArbitrumVerifier is Common {
    IOutbox ArbOutbox;

    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;
    using RLPReader for bytes;

    constructor(IOutbox _ArbOutbox) {
        ArbOutbox = _ArbOutbox;
    }

    function verifyArbBlock(
        bytes memory rlpData,
        uint256 comparisonNumber,
        bytes32 comparisonBlockHash,
        bytes memory headerProof,
        bytes calldata extraData,
        IRecursiveHeaderVerifier RHVerify
    ) external view returns (bool) {
        RLPReader.RLPItem[] memory decoded = checkAndDecodeRLP(
            rlpData,
            comparisonBlockHash
        );
        RLPReader.RLPItem memory extraDataItem = decoded[
            Common.BLOCK_HEADER_EXTRADATA_INDEX
        ];
        RLPReader.RLPItem memory blockNumberItem = decoded[
            Common.BLOCK_HEADER_NUMBER_INDEX
        ];
        uint number = blockNumberItem.toUint();

        bytes32 extraDataBytes32 = bytes32(extraDataItem.toUintStrict());
        bytes32 l2Hash = ArbOutbox.roots(extraDataBytes32);
        if (l2Hash == bytes32(0)) {
            // No such confirmed node...
            return false;
        }
        return RHVerify.verifyProof(rlpData, headerProof, l2Hash);
    }
}
