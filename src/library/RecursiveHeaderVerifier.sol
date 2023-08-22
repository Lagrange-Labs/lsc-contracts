// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IRecursiveHeaderVerifier} from "../interfaces/IRecursiveHeaderVerifier.sol";

contract RecursiveHeaderVerifier is IRecursiveHeaderVerifier {
    function verifyProof(
        bytes memory rawBlockHeader,
        bytes calldata proof,
        bytes32 checkpointBlockHash
    ) external view returns (bool) {
        return true;
    }
}
