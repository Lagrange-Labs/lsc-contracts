// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILagrangeCommittee {
    struct UnsubscribedParam {
        uint32 chainID;
        uint256 blockNumber;
    }

    struct OperatorStatus {
        uint256[2] blsPubKey;
        uint8 subscribedChainCount;
        // ChainID => VotingPower
        mapping(uint32 => uint96) subscribedChains;
        UnsubscribedParam[] unsubscribedParams;
    }

    struct CommitteeDef {
        uint256 startBlock;
        uint256 duration;
        uint256 freezeDuration;
        uint8 quorumNumber;
    }

    struct CommitteeData {
        bytes32 root;
        uint256 leafCount;
        uint256 totalVotingPower;
    }

    function getCommittee(uint32 chainID, uint256 blockNumber) external returns (CommitteeData memory, bytes32);

    function addOperator(address operator, uint256[2] memory blsPubKey) external;

    function isLocked(uint32 chainID) external returns (bool, uint256);

    function updateOperatorAmount(address operator, uint32 chainID) external;

    function subscribeChain(address operator, uint32 chainID) external;

    function unsubscribeChain(address operator, uint32 chainID) external;

    function isUnregisterable(address operator) external returns (bool, uint256);

    function update(uint32 chainID, uint256 epochNumber) external;

    function getBlsPubKey(address operator) external returns (uint256[2] memory);
}
