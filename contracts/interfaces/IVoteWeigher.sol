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

    function getTokenList() external view returns (address[] memory);

    function getTokenListForQuorumNumbers(uint8[] memory quorumNumbers_) external view returns (address[] memory);
}
