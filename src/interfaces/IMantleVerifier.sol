// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IRecursiveHeaderVerifier} from "../interfaces/IRecursiveHeaderVerifier.sol";

interface IMantleVerifier {
    function verifyMntBlock(
        bytes calldata rlpData,
        bytes32 attestHash,
        bytes calldata checkpointRLP,
        bytes calldata headerProof,
        bytes calldata extraData, //SCCPayload
        IRecursiveHeaderVerifier RHVerify
    ) external view returns (bool);
}
