// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {ISlashingAggregate16Verifier} from "../interfaces/ISlashingAggregate16Verifier.sol";

contract SlashingAggregate16Verifier is ISlashingAggregate16Verifier
{
    Verifier verifier;
    
    constructor(address _verifier) {
        verifier = _verifier;
    }
    
    struct proofParams {
        uint[2] memory a;
        uint[2][2] memory b;
        uint[2] memory c;
        uint[6] memory input;
    }

    function verifyProofWithInput(
        bytes calldata proof
    ) external view returns (bool,uint[6]) {
        proofParams params = abi.decode(proof,(proofParams));
        bool result = circomVerifier.verifyProof(params.a, params.b, params.c, input);
        return (result,input);
    }
}
