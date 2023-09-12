// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IRecursiveHeaderVerifier} from "../interfaces/IRecursiveHeaderVerifier.sol";

interface IOptimismVerifier {
    function verifyOptBlock(
        bytes memory rlpData,
        uint256 comparisonNumber,
        bytes32 comparisonBlockHash,
        bytes memory headerProof,
        bytes calldata extraData,
        IRecursiveHeaderVerifier RHVerify
    ) external view returns (bool);

    function verifyOutputProof(
        uint256 comparisonNumber,
        bytes32 comparisonBlockHash,
        bytes calldata extraData
    ) external view returns (bool, bytes32);
}
