// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Common} from "./Common.sol";

contract OptimismVerifier is Common {
    uint256 public constant OUTPUT_PROOF_BLOCKHASH_INDEX = 3;

    address L2OutputOracle;

    constructor(address _L2OutputOracle) {
        L2OutputOracle = _L2OutputOracle;
    }

    struct OutputProposal {
        bytes32 outputRoot;
        uint128 timestamp;
        uint128 l2BlockNumber;
    }
    
    function verifyOutputProof(
        uint256 comparisonNumber,
        bytes32 comparisonBlockHash,
        bytes32[4] calldata outputProof
//	bytes calldata headerProof,
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
        bool res = outputRootProof == comparisonProof;
        return res;
    }
}
