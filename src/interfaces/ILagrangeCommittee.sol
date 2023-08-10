// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

struct OperatorStatus {
    uint256 amount;
    bytes blsPubKey;
    uint32 serveUntilBlock;
    uint32 chainID;
    bool slashed;
}

interface ILagrangeCommittee {
    struct CommitteeDef {
        uint256 startBlock;
        uint256 duration;
        uint256 freezeDuration;
    }

    struct CommitteeData {
        uint256 root;
        uint256 height;
        uint256 totalVotingPower;
    }

    function getServeUntilBlock(address operator) external returns (uint32);

    function setSlashed(address operator) external;

    function getSlashed(address operator) external returns (bool);

    function getCommittee(
        uint256 chainID,
        uint256 blockNumber
    ) external returns (CommitteeData memory, uint256);

    function addOperator(
        address operator,
        bytes memory blsPubKey,
        uint32 chainID,
        uint32 serveUntilBlock
    ) external;

    function updateOperator(address operator, uint256 updateType) external;

    function update(uint32 chainID, uint256 epochNumber) external;
}
