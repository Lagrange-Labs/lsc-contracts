// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Common} from "./Common.sol";
import {IL2OutputOracle} from "../mock/optimism/IL2OutputOracle.sol";
import {Types} from "../mock/optimism/Types.sol";
import {IRecursiveHeaderVerifier} from "../interfaces/IRecursiveHeaderVerifier.sol";
import {IOptimismVerifier} from "../interfaces/IOptimismVerifier.sol";

contract OptimismVerifier is Common, IOptimismVerifier {
    uint256 public constant OUTPUT_PROOF_BLOCKHASH_INDEX = 3;

    IL2OutputOracle L2OutputOracle;

    constructor(IL2OutputOracle _L2OutputOracle) {
        L2OutputOracle = _L2OutputOracle;
    }

    struct OutputProposal {
        bytes32 outputRoot;
        uint128 timestamp;
        uint128 l2BlockNumber;
    }

    function getOutputHash(
        bytes32[4] memory outputProof
    ) public view returns (bytes32) {
        bytes32 comparisonProof = keccak256(
            abi.encode(
                outputProof[0],
                outputProof[1],
                outputProof[2],
                outputProof[3]
            )
        );
        return comparisonProof;
    }

    function verifyOptBlock(
        bytes memory rlpData,
        uint256 comparisonNumber,
        bytes32 comparisonBlockHash,
        bytes memory headerProof,
        bytes calldata extraData,
        IRecursiveHeaderVerifier RHVerify
    ) public view returns (bool) {
        bool res = false;
        bytes32 checkpoint = bytes32(0);
        (res, checkpoint) = verifyOutputProof(
            comparisonNumber,
            comparisonBlockHash,
            extraData
        );
        if (!res) {
            return false;
        }
        return RHVerify.verifyProof(rlpData, headerProof, checkpoint);
    }

    function verifyOutputProof(
        uint256 comparisonNumber,
        bytes32 comparisonBlockHash,
        bytes calldata extraData
    ) public view returns (bool, bytes32) {
        bytes32[4] memory outputProofBytes32 = abi.decode(
            extraData,
            (bytes32[4])
        );
        Types.OutputRootProof memory outputProof = Types.OutputRootProof(
            outputProofBytes32[0],
            outputProofBytes32[1],
            outputProofBytes32[2],
            outputProofBytes32[3]
        );
        // 1. get next output root
        Types.OutputProposal memory outputProposal = L2OutputOracle
            .getL2OutputAfter(comparisonNumber);
        // 2. Derive output root from result
        bytes32 outputRoot = outputProposal.outputRoot;
        // 3. Verify independently generated proof
        bytes32 comparisonProof = getOutputHash(outputProofBytes32);
        bool res = outputRoot == comparisonProof;
        return (res, outputProof.latestBlockhash);
    }
}
