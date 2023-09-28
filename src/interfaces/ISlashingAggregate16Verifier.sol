// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ISlashingAggregate16Verifier {
    function verifyProofWithInput(
        bytes calldata proof
    ) external view returns (bool,uint[6]);
}
