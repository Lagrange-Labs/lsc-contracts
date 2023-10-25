// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

struct OperatorStatus {
    uint256 amount;
    bool slashed;
    uint32 serveUntilBlock;
    // ChainID => BLSPubKey
    mapping(uint32 => bytes) registeredChains;
}

struct OperatorUpdate {
    address operator;
    uint8 updateType;
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

    function getServeUntilBlock(address operator, uint32 chainID) external returns (uint32);

    function setSlashed(address operator) external;

    function getSlashed(address operator) external returns (bool);

    function getCommittee(uint32 chainID, uint256 blockNumber) external returns (CommitteeData memory, uint256);

    function addOperator(address operator, bytes memory blsPubKey, uint32 chainID, uint32 serveUntilBlock) external;

    function isLocked(uint32 chainID) external returns (bool, uint256);

    function updateOperator(OperatorUpdate memory opUpdate) external;

    function update(uint32 chainID, uint256 epochNumber) external;
}
