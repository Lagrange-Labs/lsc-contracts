// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Common} from "./Common.sol";
import {IL2OutputOracle} from "../mock/optimism/IL2OutputOracle.sol";
import {Types} from "../mock/optimism/Types.sol";

contract OptimismVerifier is Common {
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
        bytes32[4] calldata outputProof
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

    function verifyOutputProof(
        uint256 comparisonNumber,
        bytes32 comparisonBlockHash,
        bytes32[4] calldata outputProof
    )
        external
        view
        returns (
            //	bytes calldata headerProof,
            bool
        )
    {
        // 1. get next output root
        Types.OutputProposal memory outputProposal = L2OutputOracle
            .getL2OutputAfter(comparisonNumber);
        // 2. Derive output root from result
        bytes32 outputRoot = outputProposal.outputRoot;
        // 3. Verify independently generated proof against
        bytes32 comparisonProof = getOutputHash(outputProof);
        bool res = outputRoot == comparisonProof;
        return res;
    }
}
