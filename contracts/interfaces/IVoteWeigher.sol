// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IVoteWeigher {
    struct TokenMultiplier {
        address token;
        uint96 multiplier;
    }

    function addQuorumMultiplier(uint8 quorumNumber, TokenMultiplier[] memory multipliers) external;

    function removeQuorumMultiplier(uint8 quorumNumber) external;

    function updateQuorumMultiplier(uint8 quorumNumber, uint256 index, TokenMultiplier memory multiplier) external;

    function weightOfOperator(uint8 quorumNumber, address operator) external view returns (uint96);
}
