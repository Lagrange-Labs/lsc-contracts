// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../library/HermezHelpers.sol";
import "../library/EvidenceVerifier.sol";
import "../interfaces/ILagrangeCommittee.sol";
import "../interfaces/ILagrangeService.sol";
import "../interfaces/IVoteWeigher.sol";

contract LagrangeCommittee is Initializable, OwnableUpgradeable, HermezHelpers, ILagrangeCommittee {
    ILagrangeService public immutable service;
    IVoteWeigher public immutable voteWeigher;

    // Active Committee
    uint256 public constant COMMITTEE_CURRENT = 0;
    // Frozen Committee - Next "Current" Committee
    uint256 public constant COMMITTEE_NEXT_1 = 1;

    // ChainID => Committee
    mapping(uint32 => CommitteeDef) public committeeParams;
    // ChainID => Epoch => CommitteeData
    mapping(uint32 => mapping(uint256 => CommitteeData)) public committees;
    // ChainID => Total Voting Power
    mapping(uint32 => uint256) public totalVotingPower;

    /* Live Committee Data */
    // ChainID => Tree Depth => Leaf Index => Node Value
    // Note: Leaf Index is 0-indexed
    mapping(uint32 => mapping(uint8 => mapping(uint256 => uint256))) public committeeNodes;
    // ChainID => Address => CommitteeLeaf Index
    mapping(uint32 => mapping(address => uint32)) public committeeLeavesMap;
    // ChainID => Tree Height
    mapping(uint32 => uint8) public committeeHeights;
    // ChainID => address[]
    mapping(uint32 => address[]) public committeeAddrs;
    // Tree Depth => Node Value
    mapping(uint8 => uint256) zeroHashes;

    mapping(address => OperatorStatus) public operators;

    // ChainID => Epoch check if committee tree has been updated
    mapping(uint32 => uint256) public updatedEpoch;

    // Event fired on initialization of a new committee
    event InitCommittee(uint256 chainID, uint256 duration, uint256 freezeDuration);

    // Fired on successful rotation of committee
    event UpdateCommittee(uint256 chainID, bytes32 current);

    modifier onlyService() {
        require(msg.sender == address(service), "Only Lagrange service can call this function.");
        _;
    }

    modifier onlyServiceManager() {
        require(msg.sender == voteWeigher.serviceManager(), "Only Lagrange service manager can call this function.");
        _;
    }

    constructor(ILagrangeService _service, IVoteWeigher _voteWeigher) {
        service = _service;
        voteWeigher = _voteWeigher;
        _disableInitializers();
    }

    // Initializer: Accepts poseidon contracts for 2, 3, and 4 elements
    function initialize(
        address initialOwner,
        address _poseidon1Elements,
        address _poseidon2Elements,
        address _poseidon3Elements,
        address _poseidon4Elements,
        address _poseidon5Elements,
        address _poseidon6Elements
    ) external initializer {
        _initializeHelpers(
            _poseidon1Elements,
            _poseidon2Elements,
            _poseidon3Elements,
            _poseidon4Elements,
            _poseidon5Elements,
            _poseidon6Elements
        );

        // Initialize zero hashes
        for (uint8 i = 1; i <= 20; i++) {
            zeroHashes[i] = _hash2Elements([zeroHashes[i - 1], zeroHashes[i - 1]]);
        }

        _transferOwnership(initialOwner);
    }

    // Initialize new committee.
    function _initCommittee(uint32 chainID, uint256 _duration, uint256 freezeDuration) internal {
        require(committeeParams[chainID].startBlock == 0, "Committee has already been initialized.");

        committeeParams[chainID] = CommitteeDef(block.number, _duration, freezeDuration);
        committees[chainID][0] = CommitteeData(0, 0, 0);

        emit InitCommittee(chainID, _duration, freezeDuration);
    }

    function getServeUntilBlock(address operator) public view returns (uint32) {
        return operators[operator].serveUntilBlock;
    }

    // Adds address stake data and flags it for committee addition
    function addOperator(address operator, bytes memory blsPubKey, uint32 serveUntilBlock) public onlyService {
        uint96 stakeAmount = voteWeigher.weightOfOperator(operator, 1);
        OperatorStatus storage opStatus = operators[operator];
        require(opStatus.amount == 0, "Operator is already registered.");
        opStatus.amount = stakeAmount;
        opStatus.serveUntilBlock = serveUntilBlock;
        opStatus.blsPubKey = blsPubKey;
    }

    function freezeOperator(address operator) external onlyServiceManager {
        OperatorStatus storage opStatus = operators[operator];
        opStatus.slashed = true;

        for (uint256 i = 0; i < opStatus.subscribedChains.length; i++) {
            _unregisterOperator(operator, opStatus.subscribedChains[i]);
        }
    }

    function updateOperatorAmount(address operator) external onlyServiceManager {
        if (getSlashed(operator)) {
            return;
        }
        for (uint256 i = 0; i < operators[operator].subscribedChains.length; i++) {
            _updateAmount(operator, voteWeigher.weightOfOperator(operator, 1), operators[operator].subscribedChains[i]);
        }
    }

    function subscribeChain(address operator, uint32 chainID) external onlyService {
        (bool locked,) = isLocked(chainID);
        require(!locked, "The dedicated chain is locked.");

        OperatorStatus storage opStatus = operators[operator];
        require(!opStatus.slashed, "Operator is slashed.");
        uint256 blockNumber = opStatus.unsubscribedChains[chainID];

        if (blockNumber > 0 && blockNumber >= block.number) {
            revert("The dedciated chain is while unsubscribing.");
        }

        for (uint256 i = 0; i < opStatus.subscribedChains.length; i++) {
            if (opStatus.subscribedChains[i] == chainID) {
                revert("The dedicated chain is already subscribed.");
            }
        }

        opStatus.subscribedChains.push(chainID);
        _registerOperator(operator, chainID);
    }

    function unsubscribeChain(address operator, uint32 chainID) external onlyService {
        OperatorStatus storage opStatus = operators[operator];
        require(!opStatus.slashed, "Operator is slashed.");

        uint256 index;
        uint256 subChainLength = opStatus.subscribedChains.length;
        for (; index < subChainLength; index++) {
            if (opStatus.subscribedChains[index] == chainID) {
                break;
            }
        }
        require(index < subChainLength, "The dedicated chain is not subscribed");

        (bool locked, uint256 blockNumber) = isLocked(chainID);
        require(!locked, "The dedicated chain is locked.");

        opStatus.subscribedChains[index] = opStatus.subscribedChains[subChainLength - 1];
        opStatus.subscribedChains.pop();

        opStatus.unsubscribedChains[chainID] = blockNumber;
        if (blockNumber > opStatus.unsubscribedBlockNumber) {
            opStatus.unsubscribedBlockNumber = blockNumber;
        }

        _unregisterOperator(operator, chainID);
    }

    function isUnregisterable(address operator) public view returns (bool, uint256) {
        OperatorStatus storage opStatus = operators[operator];
        require(!opStatus.slashed, "Operator is slashed.");

        if (opStatus.subscribedChains.length > 0) {
            return (false, 0);
        }

        return (true, opStatus.unsubscribedBlockNumber);
    }

    function getSlashed(address operator) public view returns (bool) {
        return operators[operator].slashed;
    }

    function getBlsPubKey(address operator) public view returns (bytes memory) {
        return operators[operator].blsPubKey;
    }

    // Returns chain's committee current and next roots at a given block.
    function getCommittee(uint32 chainID, uint256 blockNumber)
        public
        view
        returns (CommitteeData memory currentCommittee, uint256 nextRoot)
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

    // Updates the parent node from the given height and index
    function _updateParent(uint32 chainID, uint8 height, uint256 leafIndex) internal {
        uint256 left;
        uint256 right;
        if (leafIndex & 1 == 1) {
            left = committeeNodes[chainID][height][leafIndex - 1];
            right = committeeNodes[chainID][height][leafIndex];
        } else {
            left = committeeNodes[chainID][height][leafIndex];
            if (committeeNodes[chainID][height][leafIndex + 1] == 0) {
                right = zeroHashes[height];
            } else {
                right = committeeNodes[chainID][height][leafIndex + 1];
            }
        }
        committeeNodes[chainID][height + 1][leafIndex / 2] = _hash2Elements([left, right]);
    }

    // Initializes a new committee, and optionally associates addresses with it.
    function registerChain(uint32 chainID, uint256 epochPeriod, uint256 freezeDuration) public onlyOwner {
        _initCommittee(chainID, epochPeriod, freezeDuration);
        _updateCommittee(chainID, 0);
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
        committees[chainID][nextEpoch].height = committeeAddrs[chainID].length;
        if (committeeHeights[chainID] > 0) {
            committees[chainID][nextEpoch].root = committeeNodes[chainID][committeeHeights[chainID] - 1][0];
        }
        committees[chainID][nextEpoch].totalVotingPower = totalVotingPower[chainID];

        updatedEpoch[chainID] = epochNumber;

        emit UpdateCommittee(chainID, bytes32(committees[chainID][nextEpoch].root));
    }

    function _registerOperator(address operator, uint32 chainID) internal {
        totalVotingPower[chainID] += operators[operator].amount;
        uint32 leafIndex = uint32(committeeAddrs[chainID].length);
        committeeAddrs[chainID].push(operator);
        committeeNodes[chainID][0][leafIndex] = getLeafHash(operator);
        committeeLeavesMap[chainID][operator] = leafIndex;
        if (leafIndex == 0 || leafIndex == 1 << (committeeHeights[chainID] - 1)) {
            committeeHeights[chainID] = committeeHeights[chainID] + 1;
        }
        // Update tree
        _updateTreeByIndex(chainID, leafIndex);
    }

    function _updateAmount(address operator, uint256 updatedAmount, uint32 chainID) internal {
        uint256 leafIndex = committeeLeavesMap[chainID][operator];
        committeeNodes[chainID][0][leafIndex] = getLeafHash(operator);
        totalVotingPower[chainID] -= operators[operator].amount;
        totalVotingPower[chainID] += updatedAmount;
        operators[operator].amount = updatedAmount;

        // Update tree
        _updateTreeByIndex(chainID, leafIndex);
    }

    function _unregisterOperator(address operator, uint32 chainID) internal {
        totalVotingPower[chainID] -= operators[operator].amount;
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

    function getLeafHash(address opAddr) public view returns (uint256) {
        uint96[11] memory slices;
        OperatorStatus storage opStatus = operators[opAddr];
        for (uint256 i = 0; i < 8; i++) {
            bytes memory addr = new bytes(12);
            for (uint256 j = 0; j < 12; j++) {
                addr[j] = opStatus.blsPubKey[(i * 12) + j];
            }
            bytes12 addrChunk = bytes12(addr);
            slices[i] = uint96(addrChunk);
        }
        bytes memory addrBytes = abi.encodePacked(opAddr, uint128(opStatus.amount));
        for (uint256 i = 0; i < 3; i++) {
            bytes memory addr = new bytes(12);
            for (uint256 j = 0; j < 12; j++) {
                addr[j] = addrBytes[(i * 12) + j];
            }
            bytes12 addrChunk = bytes12(addr);
            slices[i + 8] = uint96(addrChunk);
        }

        return _hash2Elements(
            [
                _hash6Elements(
                    [
                        uint256(slices[0]),
                        uint256(slices[1]),
                        uint256(slices[2]),
                        uint256(slices[3]),
                        uint256(slices[4]),
                        uint256(slices[5])
                    ]
                ),
                _hash5Elements(
                    [uint256(slices[6]), uint256(slices[7]), uint256(slices[8]), uint256(slices[9]), uint256(slices[10])]
                )
            ]
        );
    }
}
