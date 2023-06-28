// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILagrangeCommittee {
    struct OperatorStatus {
        uint256 amount;
        bytes blsPubKey;
        uint32 serveUntilBlock;
        bool slashed;
    }

    /// Leaf in Lagrange State Committee Trie
    struct CommitteeLeaf {
        address addr;
        uint256 stake;
        bytes blsPubKey;
    }

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
    
    function setSlashed(address operator, uint256 chainID, bool slashed) external;
    function getSlashed(address operator) external returns (bool);
    
    function getCommittee(uint256 chainID, uint256 blockNumber) external returns (CommitteeData memory, uint256);

    function addOperator(address operator, uint256 chainID, bytes memory blsPubKey, uint256 stake, uint32 serveUntilBlock) external;

    function update(uint256 chainID) external;
}

