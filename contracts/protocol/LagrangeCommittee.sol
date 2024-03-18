// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../interfaces/ILagrangeCommittee.sol";
import "../interfaces/ILagrangeService.sol";
import "../interfaces/IVoteWeigher.sol";

contract LagrangeCommittee is Initializable, OwnableUpgradeable, ILagrangeCommittee {
    ILagrangeService public immutable service;
    IVoteWeigher public immutable voteWeigher;

    // Leaf Node Prefix
    bytes1 public constant LEAF_NODE_PREFIX = 0x01;
    // Inner Node Prefix
    bytes1 public constant INNER_NODE_PREFIX = 0x02;

    // Active Committee
    uint256 public constant COMMITTEE_CURRENT = 0;
    // Frozen Committee - Next "Current" Committee
    uint256 public constant COMMITTEE_NEXT_1 = 1;

    // Registered ChainIDs
    uint32[] public chainIDs;
    // ChainID => Committee
    mapping(uint32 => CommitteeDef) public committeeParams;
    // ChainID => Epoch => CommitteeData
    mapping(uint32 => mapping(uint256 => CommitteeData)) public committees;
    // ChainID => Total Voting Power
    mapping(uint32 => uint256) public totalVotingPower;

    /* Live Committee Data */
    // ChainID => Tree Depth => Leaf Index => Node Value
    // Note: Leaf Index is 0-indexed
    mapping(uint32 => mapping(uint8 => mapping(uint256 => bytes32))) public committeeNodes;
    // ChainID => Operator Address => CommitteeLeaf Index
    mapping(uint32 => mapping(address => uint32)) public committeeLeavesMap;
    // ChainID => Tree Height
    mapping(uint32 => uint8) public committeeHeights;
    // ChainID => Operator address[]
    mapping(uint32 => address[]) public committeeAddrs;
    // Tree Depth => Node Value
    mapping(uint8 => bytes32) zeroHashes;

    mapping(address => OperatorStatus) internal operators;

    // ChainID => Epoch check if committee tree has been updated
    mapping(uint32 => uint256) public updatedEpoch;

    // Event fired on initialization of a new committee
    event InitCommittee(uint256 chainID, uint256 duration, uint256 freezeDuration, uint8 quorumNumber);

    // Fired on successful rotation of committee
    event UpdateCommittee(uint256 chainID, bytes32 current);

    modifier onlyService() {
        require(msg.sender == address(service), "Only Lagrange service can call this function.");
        _;
    }

    constructor(ILagrangeService _service, IVoteWeigher _voteWeigher) {
        service = _service;
        voteWeigher = _voteWeigher;
        _disableInitializers();
    }

    // Initializer: sets owner
    function initialize(address initialOwner) external initializer {
        // Initialize zero hashes
        for (uint8 i = 1; i <= 20; i++) {
            zeroHashes[i] = _innerHash(zeroHashes[i - 1], zeroHashes[i - 1]);
        }

        _transferOwnership(initialOwner);
    }

    // Initialize new committee.
    function _initCommittee(uint32 chainID, uint256 _duration, uint256 _freezeDuration, uint8 _quorumNumber) internal {
        require(committeeParams[chainID].startBlock == 0, "Committee has already been initialized.");

        committeeParams[chainID] = CommitteeDef(block.number, _duration, _freezeDuration, _quorumNumber);
        committees[chainID][0] = CommitteeData(0, 0, 0);

        emit InitCommittee(chainID, _duration, _freezeDuration, _quorumNumber);
    }

    // Adds address stake data and flags it for committee addition
    function addOperator(address operator, uint256[2] memory blsPubKey) public onlyService {
        OperatorStatus storage opStatus = operators[operator];
        require(opStatus.blsPubKey[0] == 0, "Operator is already registered.");
        opStatus.blsPubKey = blsPubKey;
    }

    // Anonymously updates operator's voting power
    function updateOperatorAmount(address operator, uint32 chainID) external {
        (bool locked,) = isLocked(chainID);
        require(!locked, "The dedicated chain is locked.");

        OperatorStatus storage opStatus = operators[operator];
        require(opStatus.subscribedChains[chainID] > 0, "The dedicated chain is not subscribed");

        uint96 amount = voteWeigher.weightOfOperator(committeeParams[chainID].quorumNumber, operator);
        if (amount != opStatus.subscribedChains[chainID]) {
            totalVotingPower[chainID] -= opStatus.subscribedChains[chainID];
            totalVotingPower[chainID] += amount;
            opStatus.subscribedChains[chainID] = amount;
            _updateAmount(operator, chainID);
        }
    }

    function subscribeChain(address operator, uint32 chainID) external onlyService {
        (bool locked,) = isLocked(chainID);
        require(!locked, "The dedicated chain is locked.");

        uint96 votingPower = voteWeigher.weightOfOperator(committeeParams[chainID].quorumNumber, operator);
        require(votingPower > 0, "The operator has no voting power.");

        OperatorStatus storage opStatus = operators[operator];

        for (uint256 i = 0; i < opStatus.unsubscribedParams.length; i++) {
            UnsubscribedParam memory param = opStatus.unsubscribedParams[i];
            if (param.chainID == chainID) {
                if (param.blockNumber > 0 && param.blockNumber >= block.number) {
                    revert("The dedciated chain is while unsubscribing.");
                }
            }
        }

        require(opStatus.subscribedChains[chainID] == 0, "The dedicated chain is already subscribed.");
        opStatus.subscribedChains[chainID] = votingPower;
        opStatus.subscribedChainCount = opStatus.subscribedChainCount + 1;
        totalVotingPower[chainID] += opStatus.subscribedChains[chainID];

        _registerOperator(operator, chainID);
    }

    function unsubscribeChain(address operator, uint32 chainID) external onlyService {
        OperatorStatus storage opStatus = operators[operator];

        require(opStatus.subscribedChains[chainID] > 0, "The dedicated chain is not subscribed");

        (bool locked, uint256 blockNumber) = isLocked(chainID);
        require(!locked, "The dedicated chain is locked.");

        totalVotingPower[chainID] -= opStatus.subscribedChains[chainID];
        delete opStatus.subscribedChains[chainID];
        opStatus.unsubscribedParams.push(UnsubscribedParam(chainID, blockNumber));
        opStatus.subscribedChainCount = opStatus.subscribedChainCount - 1;

        _unregisterOperator(operator, chainID);
    }

    function unsubscribeChainByAdmin(address operator, uint32 chainID) external onlyOwner {
        OperatorStatus storage opStatus = operators[operator];

        opStatus.subscribedChainCount = opStatus.subscribedChainCount - 1;

        _unregisterOperator(operator, chainID);

        for (uint256 i = 0; i < committeeAddrs[chainID].length; i++) {
            if (committeeAddrs[chainID][i] == operator) {
                committeeLeavesMap[chainID][operator] = uint32(i);
                break;
            }
        }
    }

    function isUnregisterable(address operator) public view returns (bool, uint256) {
        OperatorStatus storage opStatus = operators[operator];

        if (opStatus.subscribedChainCount > 0) {
            return (false, 0);
        }

        uint256 unsubscribeBlockNumber = 0;
        for (uint256 i = 0; i < opStatus.unsubscribedParams.length; i++) {
            UnsubscribedParam memory param = opStatus.unsubscribedParams[i];
            if (param.blockNumber > unsubscribeBlockNumber) {
                unsubscribeBlockNumber = param.blockNumber;
            }
        }

        return (true, unsubscribeBlockNumber);
    }

    function getBlsPubKey(address operator) public view returns (uint256[2] memory) {
        return operators[operator].blsPubKey;
    }

    // Returns chain's committee current and next roots at a given block.
    function getCommittee(uint32 chainID, uint256 blockNumber)
        public
        view
        returns (CommitteeData memory currentCommittee, bytes32 nextRoot)
    {
        uint256 epochNumber = getEpochNumber(chainID, blockNumber);
        uint256 nextEpoch = getEpochNumber(chainID, blockNumber + 1);
        currentCommittee = committees[chainID][epochNumber];
        nextRoot = committees[chainID][nextEpoch].root;
        return (currentCommittee, nextRoot);
    }

    // Updates the tree from the given leaf index.
    function _updateTreeByIndex(uint32 chainID, uint256 leafIndex) internal {
        for (uint8 height = 0; height < committeeHeights[chainID] - 1; height++) {
            _updateParent(chainID, height, leafIndex);
            leafIndex /= 2;
        }
    }

    // Calculate the inner node hash from left and right children
    function _innerHash(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(INNER_NODE_PREFIX, left, right));
    }

    // Updates the parent node from the given height and index
    function _updateParent(uint32 chainID, uint8 height, uint256 leafIndex) internal {
        bytes32 left;
        bytes32 right;
        if (leafIndex & 1 == 1) {
            left = committeeNodes[chainID][height][leafIndex - 1];
            if (committeeNodes[chainID][height][leafIndex] == 0) {
                right = zeroHashes[height];
            } else {
                right = committeeNodes[chainID][height][leafIndex];
            }
        } else {
            left = committeeNodes[chainID][height][leafIndex];
            if (committeeNodes[chainID][height][leafIndex + 1] == 0) {
                right = zeroHashes[height];
            } else {
                right = committeeNodes[chainID][height][leafIndex + 1];
            }
        }
        committeeNodes[chainID][height + 1][leafIndex / 2] = _innerHash(left, right);
    }

    // Initializes a new committee, and optionally associates addresses with it.
    function registerChain(uint32 chainID, uint256 epochPeriod, uint256 freezeDuration, uint8 quorunNumber)
        public
        onlyOwner
    {
        _initCommittee(chainID, epochPeriod, freezeDuration, quorunNumber);
        _updateCommittee(chainID, 0);
        chainIDs.push(chainID);
    }

    // Checks if a chain's committee is updatable at a given block
    function isUpdatable(uint32 chainID, uint256 epochNumber) public view returns (bool) {
        uint256 epochEnd = epochNumber * committeeParams[chainID].duration + committeeParams[chainID].startBlock;
        uint256 freezeDuration = committeeParams[chainID].freezeDuration;
        return block.number > epochEnd - freezeDuration;
    }

    // Checks if a chain's committee is locked at a given block
    function isLocked(uint32 chainID) public view returns (bool, uint256) {
        if (committeeParams[chainID].duration == 0) {
            return (false, 0);
        }
        uint256 epochNumber = getEpochNumber(chainID, block.number);
        uint256 epochEnd = epochNumber * committeeParams[chainID].duration + committeeParams[chainID].startBlock;
        return (block.number > epochEnd - committeeParams[chainID].freezeDuration, epochEnd);
    }

    // If applicable, updates committee based on staking, unstaking, and slashing.
    function update(uint32 chainID, uint256 epochNumber) public {
        require(isUpdatable(chainID, epochNumber), "Block number is prior to committee freeze window.");

        require(updatedEpoch[chainID] < epochNumber, "Already updated.");

        _updateCommittee(chainID, epochNumber);
    }

    function _updateCommittee(uint32 chainID, uint256 epochNumber) internal {
        uint256 nextEpoch = epochNumber + COMMITTEE_NEXT_1;

        // Update roots
        committees[chainID][nextEpoch].leafCount = committeeAddrs[chainID].length;
        if (committeeHeights[chainID] > 0) {
            committees[chainID][nextEpoch].root = committeeNodes[chainID][committeeHeights[chainID] - 1][0];
        }
        committees[chainID][nextEpoch].totalVotingPower = totalVotingPower[chainID];

        updatedEpoch[chainID] = epochNumber;

        emit UpdateCommittee(chainID, bytes32(committees[chainID][nextEpoch].root));
    }

    function _registerOperator(address operator, uint32 chainID) internal {
        uint32 leafIndex = uint32(committeeAddrs[chainID].length);
        committeeAddrs[chainID].push(operator);
        committeeNodes[chainID][0][leafIndex] = _leafHash(operator, chainID);
        committeeLeavesMap[chainID][operator] = leafIndex;
        if (leafIndex == 0 || leafIndex == 1 << (committeeHeights[chainID] - 1)) {
            committeeHeights[chainID] = committeeHeights[chainID] + 1;
        }
        // Update tree
        _updateTreeByIndex(chainID, leafIndex);
    }

    function _updateAmount(address operator, uint32 chainID) internal {
        uint256 leafIndex = committeeLeavesMap[chainID][operator];
        committeeNodes[chainID][0][leafIndex] = _leafHash(operator, chainID);
        // Update tree
        _updateTreeByIndex(chainID, leafIndex);
    }

    function _unregisterOperator(address operator, uint32 chainID) internal {
        uint32 leafIndex = uint32(committeeLeavesMap[chainID][operator]);
        uint256 lastIndex = committeeAddrs[chainID].length - 1;
        address lastAddr = committeeAddrs[chainID][lastIndex];

        // Update trie for operator leaf and last leaf
        if (leafIndex < lastIndex) {
            committeeNodes[chainID][0][leafIndex] = committeeNodes[chainID][0][lastIndex];
            committeeAddrs[chainID][leafIndex] = lastAddr;
            committeeLeavesMap[chainID][lastAddr] = leafIndex;
            _updateTreeByIndex(chainID, leafIndex);
        }

        committeeAddrs[chainID].pop();

        bool isBreak;
        uint8 treeHeight = committeeHeights[chainID];
        committeeNodes[chainID][0][lastIndex] = 0;
        for (uint8 height = 1; height < treeHeight; height++) {
            if (isBreak || lastIndex & 1 == 1) {
                isBreak = true;
                _updateParent(chainID, height - 1, lastIndex);
            } else {
                committeeNodes[chainID][height][lastIndex / 2] = 0;
                if (height == treeHeight - 2) {
                    committeeNodes[chainID][treeHeight - 1][0] = 0;
                    committeeHeights[chainID] = treeHeight - 1;
                    break;
                }
            }
            lastIndex /= 2;
        }
    }

    // Computes epoch number for a chain's committee at a given block
    function getEpochNumber(uint32 chainID, uint256 blockNumber) public view returns (uint256) {
        uint256 startBlockNumber = committeeParams[chainID].startBlock;
        uint256 epochPeriod = committeeParams[chainID].duration;
        return (blockNumber - startBlockNumber) / epochPeriod + 1;
    }

    // Returns the leaf hash for a given operator
    function _leafHash(address opAddr, uint32 chainID) internal view returns (bytes32) {
        OperatorStatus storage opStatus = operators[opAddr];
        return keccak256(
            abi.encodePacked(
                LEAF_NODE_PREFIX,
                opStatus.blsPubKey[0],
                opStatus.blsPubKey[1],
                opAddr,
                opStatus.subscribedChains[chainID]
            )
        );
    }

    // Get the operator status except subscribed chains
    function getOperatorStatus(address opAddr) public view returns (uint8, UnsubscribedParam[] memory) {
        OperatorStatus storage opStatus = operators[opAddr];
        return (opStatus.subscribedChainCount, opStatus.unsubscribedParams);
    }

    // Get the operator's voting power for the given chainID
    function getOperatorVotingPower(address opAddr, uint32 chainID) public view returns (uint96) {
        OperatorStatus storage opStatus = operators[opAddr];
        return opStatus.subscribedChains[chainID];
    }

    function updateByAdmin(address operator, uint32 chainID) external onlyOwner {
        OperatorStatus storage opStatus = operators[operator];

        uint96 amount = voteWeigher.weightOfOperator(committeeParams[chainID].quorumNumber, operator);
        totalVotingPower[chainID] -= opStatus.subscribedChains[chainID];
        totalVotingPower[chainID] += amount;
        opStatus.subscribedChains[chainID] = amount;
        _updateAmount(operator, chainID);

        _updateCommittee(chainID, updatedEpoch[chainID]);
    }
}
