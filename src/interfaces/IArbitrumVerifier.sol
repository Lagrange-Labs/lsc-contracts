// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IRecursiveHeaderVerifier} from "../interfaces/IRecursiveHeaderVerifier.sol";

interface IArbitrumVerifier {
    function verifyArbBlock(
        bytes memory rlpData,
        uint256 comparisonNumber,
        bytes32 comparisonBlockHash,
        bytes memory headerProof,
        bytes calldata extraData,
        IRecursiveHeaderVerifier RHVerify
    ) external view returns (bool);
}
