// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IVoteWeigher {
    function serviceManager() external view returns (address);

    function weightOfOperator(
        address operator,
        uint256 quorumNumber
    ) external returns (uint96);
}
