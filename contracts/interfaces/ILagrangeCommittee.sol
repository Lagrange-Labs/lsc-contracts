// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILagrangeCommittee {
    struct UnsubscribedParam {
        uint32 chainID;
        uint256 blockNumber;
    }

    struct OperatorStatus {
        uint256[2][] blsPubKeys;
        uint8 subscribedChainCount; // assume that size of this array is not big
        UnsubscribedParam[] unsubscribedParams;
    }

    struct CommitteeDef {
        uint256 startBlock;
        uint256 duration;
        uint256 freezeDuration;
        uint8 quorumNumber;
        uint96 minWeight;
        uint96 maxWeight;
    }

    struct CommitteeData {
        bytes32 root;
        uint32 leafCount;
        uint224 totalVotingPower;
    }

    function getCommittee(
        uint32 chainID,
        uint256 blockNumber
    ) external view returns (CommitteeData memory, bytes32);

    // TODO: need to change order of the params for gas optimization
    function registerChain(
        uint32 chainID,
        uint256 epochPeriod,
        uint256 freezeDuration,
        uint8 quorumNumber,
        uint96 minWeight,
        uint96 maxWeight
    ) external;

    function updateChain(
        uint32 chainID,
        uint256 epochPeriod,
        uint256 freezeDuration,
        uint8 quorumNumber,
        uint96 minWeight,
        uint96 maxWeight
    ) external;

    function addOperator(
        address operator,
        uint256[2][] memory blsPubKeys
    ) external;

    function addBlsPubKeys(
        address operator,
        uint256[2][] memory additionalBlsPubKeys
    ) external;

    function isLocked(uint32 chainID) external view returns (bool, uint256);

    function subscribeChain(address operator, uint32 chainID) external;

    function unsubscribeChain(address operator, uint32 chainID) external;

    function isUnregisterable(
        address operator
    ) external view returns (bool, uint256);

    function update(uint32 chainID, uint256 epochNumber) external;

    function getBlsPubKeys(
        address operator
    ) external view returns (uint256[2][] memory);

    function getOperatorVotingPower(
        address opAddr,
        uint32 chainID
    ) external view returns (uint96);

    function getBlsPubKeyVotingPowers(
        address opAddr,
        uint32 chainID
    ) external view returns (uint96[] memory);


    // Event fired on initialization of a new committee
    event InitCommittee(
        uint256 chainID,
        uint256 duration,
        uint256 freezeDuration,
        uint8 quorumNumber,
        uint96 minWeight,
        uint96 maxWeight
    );
    // Event fired on updating a committee params
    event UpdateCommitteeParams(
        uint256 chainID,
        uint256 duration,
        uint256 freezeDuration,
        uint8 quorumNumber,
        uint96 minWeight,
        uint96 maxWeight
    );

    // Fired on successful rotation of committee
    event UpdateCommittee(uint256 chainID, bytes32 current);
}
