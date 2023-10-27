// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

struct OperatorStatus {
    uint256 amount;
    bytes blsPubKey;
    bool slashed;
    uint32 serveUntilBlock;
    uint32[] subscribedChains;
    uint256 unsubscribedBlockNumber;
    // ChainID => Block Number which can be unsubscribable
    mapping(uint32 => uint256) unsubscribedChains;
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

    function getSlashed(address operator) external returns (bool);

    function getCommittee(uint32 chainID, uint256 blockNumber) external returns (CommitteeData memory, uint256);

    function addOperator(address operator, bytes memory blsPubKey, uint32 serveUntilBlock) external;

    function freezeOperator(address operator) external;

    function isLocked(uint32 chainID) external returns (bool, uint256);

    function updateOperatorAmount(address operator) external;

    function subscribeChain(address operator, uint32 chainID) external;

    function unsubscribeChain(address operator, uint32 chainID) external;

    function isUnregisterable(address operator) external returns (bool, uint256);

    function update(uint32 chainID, uint256 epochNumber) external;
}
