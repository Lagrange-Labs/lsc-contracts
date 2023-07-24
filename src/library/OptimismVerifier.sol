// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Common} from "./Common.sol";

contract OptimismVerifier {
    uint256 public constant OUTPUT_PROOF_BLOCKHASH_INDEX = 3;

    struct OutputProposal {
        bytes32 outputRoot;
        uint128 timestamp;
        uint128 l2BlockNumber;
    }

    function verifyOptBlockNumber(
        address L2OutputOracle,
        uint256 comparisonNumber,
        bytes32 comparisonBlockHash,
        bytes32[4] calldata outputProof
    ) external returns (bool) {
        // 1. get next output root
        bytes memory _call = abi.encodeWithSignature(
            "getL2OutputAfter(uint256)",
            comparisonNumber
        );
        (bool success, bytes memory result) = L2OutputOracle.call(
            _call
        );
        require(success, "Call to Optimism L2OutputOracle contract failed.");
        
        OutputProposal memory outputProposal;
        
        (outputProposal.outputRoot, outputProposal.timestamp, outputProposal.l2BlockNumber) = abi.decode(result, (bytes32, uint128, uint128));
        
        // 2. Derive output root from result
        bytes32 outputRootProof;
        // 3. Verify independently generated proof against
        bytes32 comparisonProof = keccak256(
            abi.encode(
                outputProof[0],
                outputProof[1],
                outputProof[2],
                outputProof[3]
            )
        );
        require(
            outputRootProof == comparisonProof,
            "Output Root Proofs do not match"
        );
        // 4. May now proceed to verify comparison hash
        //...
        bool res = false;
        return res;
    }
}
