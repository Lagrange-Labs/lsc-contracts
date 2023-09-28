// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ISlashingSimpleVerifier {
    function verifyProofWithInput(
        bytes calldata proof
    ) external view returns (bool,uint[75]);
}
