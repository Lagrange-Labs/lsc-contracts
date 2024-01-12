// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IVoteWeigher {
    function serviceManager() external view returns (address);

    function weightOfOperator(uint8 quorumNumber, address operator) external returns (uint96);
}
