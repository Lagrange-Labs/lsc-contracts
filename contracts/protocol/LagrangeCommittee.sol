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

    // ChainID => Operator address[]
    mapping(uint32 => address[]) public committeeAddrs;
    // Tree Depth => Node Value
    mapping(uint8 => bytes32) zeroHashes;

    mapping(address => OperatorStatus) public operatorsStatus;

    // ChainID => Epoch check if committee tree has been updated
    mapping(uint32 => uint256) public updatedEpoch;

    mapping(uint32 => mapping(address => bool)) public subscribedChains;

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

    // Adds address stake data and flags it for committee addition
    function addOperator(address operator, uint256[2][] memory blsPubKeys) public onlyService {
        _validateBlsPubKeys(blsPubKeys);
        _registerOperator(operator, blsPubKeys);
    }

    // Adds address stake data and flags it for committee addition
    function addBlsPubKeys(address operator, uint256[2][] memory additionalBlsPubKeys) public onlyService {
        _validateBlsPubKeys(additionalBlsPubKeys);
        _addBlsPubKeys(operator, additionalBlsPubKeys);
    }

    function subscribeChain(address operator, uint32 chainID) external onlyService {
        // Check if the chainID is already registered
        require(committeeParams[chainID].startBlock > 0, "The dedicated chain is not registered.");

        (bool locked,) = isLocked(chainID);
        require(!locked, "The dedicated chain is locked.");

        UnsubscribedParam[] memory unsubscribedParams = operatorsStatus[operator].unsubscribedParams;

        uint256 _length = unsubscribedParams.length;
        for (uint256 i; i < _length; i++) {
            UnsubscribedParam memory param = unsubscribedParams[i];
            if (param.chainID == chainID) {
                if (param.blockNumber >= block.number) {
                    revert("The dedciated chain is while unsubscribing.");
                }
            }
        }
        require(!subscribedChains[chainID][operator], "The dedicated chain is already subscribed.");

        CommitteeDef memory _committeeParam = committeeParams[chainID];
        uint96 _voteWeight = voteWeigher.weightOfOperator(_committeeParam.quorumNumber, operator); // voteWeight
        require(_voteWeight >= _committeeParam.minWeight, "Insufficient Vote Weight");

        _subscribeChain(operator, chainID);
    }

    function unsubscribeChain(address operator, uint32 chainID) external onlyService {
        require(subscribedChains[chainID][operator], "The dedicated chain is not subscribed");

        (bool locked, uint256 blockNumber) = isLocked(chainID);
        require(!locked, "The dedicated chain is locked.");

        _unsubscribeChain(operator, chainID, blockNumber);
    }

    // Initializes a new committee, and optionally associates addresses with it.
    function registerChain(
        uint32 chainID,
        uint256 genesisBlock,
        uint256 epochPeriod,
        uint256 freezeDuration,
        uint8 quorumNumber,
        uint96 minWeight,
        uint96 maxWeight
    ) public onlyOwner {
        require(committeeParams[chainID].startBlock == 0, "Committee has already been initialized.");
        _validateVotingPowerRange(minWeight, maxWeight);

        _initCommittee(chainID, genesisBlock, epochPeriod, freezeDuration, quorumNumber, minWeight, maxWeight);
    }

    function updateChain(
        uint32 chainID,
        uint256 epochPeriod,
        uint256 freezeDuration,
        uint8 quorumNumber,
        uint96 minWeight,
        uint96 maxWeight
    ) public onlyOwner {
        uint256 _startBlock = committeeParams[chainID].startBlock;
        require(_startBlock != 0, "Chain not initialized");

        _validateVotingPowerRange(minWeight, maxWeight);

        _updateCommitteeParams(
            chainID,
            _startBlock,
            committeeParams[chainID].genesisBlock,
            epochPeriod,
            freezeDuration,
            quorumNumber,
            minWeight,
            maxWeight
        );
    }

    function isUnregisterable(address operator) public view returns (bool, uint256) {
        OperatorStatus memory _opStatus = operatorsStatus[operator];

        if (_opStatus.subscribedChainCount > 0) {
            return (false, 0);
        }

        uint256 _unsubscribeBlockNumber;
        uint256 _length = _opStatus.unsubscribedParams.length;
        for (uint256 i; i < _length; i++) {
            UnsubscribedParam memory param = _opStatus.unsubscribedParams[i];
            if (param.blockNumber > _unsubscribeBlockNumber) {
                _unsubscribeBlockNumber = param.blockNumber;
            }
        }

        return (true, _unsubscribeBlockNumber);
    }

    function getBlsPubKeys(address operator) public view returns (uint256[2][] memory) {
        return operatorsStatus[operator].blsPubKeys;
    }

    // Returns chain's committee current and next roots at a given block.
    function getCommittee(uint32 chainID, uint256 blockNumber)
        public
        view
        returns (CommitteeData memory currentCommittee)
    {
        uint256 epochNumber = getEpochNumber(chainID, blockNumber);
        currentCommittee = committees[chainID][epochNumber];
        return currentCommittee;
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

        CommitteeDef memory _committeeParam = committeeParams[chainID];
        uint8 _quorumNumber = _committeeParam.quorumNumber;
        uint96 _minWeight = _committeeParam.minWeight;
        uint96 _maxWeight = _committeeParam.maxWeight;

        address[] memory _operators = committeeAddrs[chainID];
        uint256 _operatorCount = _operators.length;

        uint256 _leafCounter;

        // pre-calculate array size (can be bigger than actual size)
        for (uint256 i; i < _operatorCount;) {
            unchecked {
                _leafCounter += operatorsStatus[_operators[i]].blsPubKeys.length;
                i++;
            }
        }

        bytes32[] memory _committeeLeaves = new bytes32[](_leafCounter);
        {
            _leafCounter = 0;
            for (uint256 i; i < _operatorCount;) {
                address _operator = _operators[i];

                OperatorStatus storage _opStatus = operatorsStatus[_operator];
                uint96 _votingPower = _checkVotingPower(
                    uint32(_opStatus.blsPubKeys.length), // blsPubKeyCount
                    voteWeigher.weightOfOperator(_quorumNumber, _operator), // voteWeight
                    _minWeight,
                    _maxWeight
                );

                uint96 _remained = _votingPower;
                unchecked {
                    for (uint256 j; _remained > 0;) {
                        uint96 _individualVotingPower;
                        if (_remained >= _maxWeight + _minWeight) {
                            _individualVotingPower = _maxWeight;
                        } else if (_remained > _maxWeight) {
                            _individualVotingPower = _minWeight;
                        } else {
                            _individualVotingPower = _remained;
                        }
                        _remained -= _individualVotingPower;
                        _committeeLeaves[_leafCounter] =
                            _leafHash(_operator, _opStatus.blsPubKeys[j], _individualVotingPower);
                        j++;
                        _leafCounter++;
                    }
                }
                unchecked {
                    i++;
                }
            }
        }

        bytes32 _root;
        unchecked {
            // Nothing to overflow/underflow
            uint256 _childCount = _leafCounter;
            for (uint8 _h; _childCount > 1; _h++) {
                uint256 _parentCount = (_childCount + 1) >> 1;
                for (uint256 _i = 1; _i < _childCount; _i += 2) {
                    _committeeLeaves[_i >> 1] = _innerHash(_committeeLeaves[_i - 1], _committeeLeaves[_i]);
                }
                if (_childCount & 1 == 1) {
                    _committeeLeaves[_parentCount - 1] = _innerHash(_committeeLeaves[_childCount - 1], zeroHashes[_h]);
                }
                _childCount = _parentCount;
            }
            if (_leafCounter > 0) _root = _committeeLeaves[0];
        }

        _updateCommittee(chainID, epochNumber, _root, uint32(_leafCounter));
    }

    // Computes epoch number for a chain's committee at a given block
    function getEpochNumber(uint32 chainID, uint256 blockNumber) public view returns (uint256) {
        if (blockNumber < committeeParams[chainID].genesisBlock) {
            return 0;
        }
        uint256 startBlockNumber = committeeParams[chainID].startBlock;
        if (blockNumber < startBlockNumber) {
            return 1;
        }
        uint256 epochPeriod = committeeParams[chainID].duration;
        return (blockNumber - startBlockNumber) / epochPeriod + 1;
    }

    // Get the operator's voting power for the given chainID
    function getOperatorVotingPower(address opAddr, uint32 chainID) public view returns (uint96) {
        CommitteeDef memory _committeeParam = committeeParams[chainID];
        uint96 _weight = voteWeigher.weightOfOperator(_committeeParam.quorumNumber, opAddr);
        return _checkVotingPower(
            uint32(operatorsStatus[opAddr].blsPubKeys.length),
            _weight,
            _committeeParam.minWeight,
            _committeeParam.maxWeight
        );
    }

    // Get array of voting powers of individual BlsPubKeys
    function getBlsPubKeyVotingPowers(address opAddr, uint32 chainID)
        public
        view
        returns (uint96[] memory individualVotingPowers)
    {
        uint96 _votingPower = getOperatorVotingPower(opAddr, chainID);
        uint96 _minWeight = committeeParams[chainID].minWeight;
        uint96 _maxWeight = committeeParams[chainID].maxWeight;
        return _divideVotingPower(_votingPower, _minWeight, _maxWeight);
    }

    function getTokenListForOperator(address operator) external view returns (address[] memory) {
        uint256 _length = chainIDs.length;
        uint32[] memory _subscribedChainIDs = new uint32[](_length);
        uint256 _count;
        for (uint256 i; i < _length; i++) {
            uint32 _chainID = chainIDs[i];
            if (subscribedChains[_chainID][operator]) {
                _subscribedChainIDs[_count++] = _chainID;
            }
        }
        uint8[] memory _quorumNumbers = new uint8[](_count);
        for (uint256 i; i < _count; i++) {
            _quorumNumbers[i] = committeeParams[_subscribedChainIDs[i]].quorumNumber;
        }
        return voteWeigher.getTokenListForQuorumNumbers(_quorumNumbers);
    }

    // Initialize new committee.
    function _initCommittee(
        uint32 _chainID,
        uint256 _genesisBlock,
        uint256 _duration,
        uint256 _freezeDuration,
        uint8 _quorumNumber,
        uint96 _minWeight,
        uint96 _maxWeight
    ) internal {
        committeeParams[_chainID] =
            CommitteeDef(block.number, _genesisBlock, _duration, _freezeDuration, _quorumNumber, _minWeight, _maxWeight);
        committees[_chainID][0] = CommitteeData(0, 0, 0);

        chainIDs.push(_chainID);

        emit InitCommittee(_chainID, _genesisBlock, _duration, _freezeDuration, _quorumNumber, _minWeight, _maxWeight);
    }

    // Update committee.
    function _updateCommitteeParams(
        uint32 _chainID,
        uint256 _startBlock,
        uint256 _genesisBlock,
        uint256 _duration,
        uint256 _freezeDuration,
        uint8 _quorumNumber,
        uint96 _minWeight,
        uint96 _maxWeight
    ) internal {
        committeeParams[_chainID] =
            CommitteeDef(_startBlock, _genesisBlock, _duration, _freezeDuration, _quorumNumber, _minWeight, _maxWeight);
        emit UpdateCommitteeParams(_chainID, _duration, _freezeDuration, _quorumNumber, _minWeight, _maxWeight);
    }

    function _registerOperator(address _operator, uint256[2][] memory _blsPubKeys) internal {
        OperatorStatus storage _opStatus = operatorsStatus[_operator];
        require(_opStatus.blsPubKeys.length == 0, "Operator is already registered.");
        _opStatus.blsPubKeys = _blsPubKeys;
    }

    function _addBlsPubKeys(address _operator, uint256[2][] memory _additionalBlsPubKeys) internal {
        OperatorStatus storage _opStatus = operatorsStatus[_operator];
        require(_opStatus.blsPubKeys.length != 0, "Operator is not registered.");
        uint256 _length = _additionalBlsPubKeys.length;
        for (uint256 i; i < _length; i++) {
            _opStatus.blsPubKeys.push(_additionalBlsPubKeys[i]);
        }
    }

    function _subscribeChain(address _operator, uint32 _chainID) internal {
        subscribedChains[_chainID][_operator] = true;
        operatorsStatus[_operator].subscribedChainCount++;

        committeeAddrs[_chainID].push(_operator);
    }

    function _unsubscribeChain(address _operator, uint32 _chainID, uint256 _blockNumber) internal {
        delete subscribedChains[_chainID][_operator];
        OperatorStatus storage _opStatus = operatorsStatus[_operator];
        _opStatus.unsubscribedParams.push(UnsubscribedParam(_chainID, _blockNumber));
        _opStatus.subscribedChainCount = _opStatus.subscribedChainCount - 1;

        uint256 _length = committeeAddrs[_chainID].length;
        for (uint256 i; i < _length; i++) {
            if (committeeAddrs[_chainID][i] == _operator) {
                committeeAddrs[_chainID][i] = committeeAddrs[_chainID][_length - 1];
            }
        }
        committeeAddrs[_chainID].pop();
    }

    function _updateCommittee(uint32 _chainID, uint256 _epochNumber, bytes32 _root, uint32 _leafCount) internal {
        uint256 nextEpoch = _epochNumber + COMMITTEE_NEXT_1;
        // Update roots
        committees[_chainID][nextEpoch].leafCount = _leafCount;
        committees[_chainID][nextEpoch].root = _root;
        committees[_chainID][nextEpoch].updatedBlock = uint224(block.number);
        updatedEpoch[_chainID] = _epochNumber;
        emit UpdateCommittee(_chainID, bytes32(committees[_chainID][nextEpoch].root));
    }

    function _validateBlsPubKeys(uint256[2][] memory _blsPubKeys) internal pure {
        // TODO: need to add validation for blsPubKeys with signatures
        uint256 _length = _blsPubKeys.length;
        for (uint256 i; i < _length; i++) {
            require(_blsPubKeys[i][0] != 0 && _blsPubKeys[i][1] != 0, "Invalid BLS Public Key.");
        }
    }

    // Returns the leaf hash for a given operator
    function _leafHash(address opAddr, uint256[2] memory blsPubKey, uint96 _votingPower)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(LEAF_NODE_PREFIX, blsPubKey[0], blsPubKey[1], opAddr, _votingPower));
    }

    // Calculate the inner node hash from left and right children
    function _innerHash(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(INNER_NODE_PREFIX, left, right));
    }

    function _validateVotingPowerRange(uint96 _minWeight, uint96 _maxWeight) internal pure {
        require(_minWeight > 0 && _maxWeight >= _minWeight * 2, "Invalid min/max Weight");
    }

    function _checkVotingPower(uint32 blsPubKeysCount, uint96 votingPower, uint96 minWeight, uint96 maxWeight)
        internal
        pure
        returns (uint96)
    {
        if (votingPower < minWeight) {
            return 0;
        }
        unchecked {
            uint256 _amountLimit = uint256(maxWeight) * uint256(blsPubKeysCount); // This value can be bigger than type(uint96).max

            if (votingPower > _amountLimit) {
                votingPower = uint96(_amountLimit);
            }
        }
        return votingPower;
    }

    function _calcActiveBlsPubKeyCount(uint96 _votingPower, uint96 minWeight, uint96 maxWeight)
        internal
        pure
        returns (uint32)
    {
        if (_votingPower < minWeight) {
            return 0;
        } else {
            unchecked {
                uint96 _count = ((_votingPower - 1) / maxWeight) + 1;
                require(_count <= type(uint32).max, "OverFlow");
                return uint32(_count);
            }
        }
    }

    function _divideVotingPower(uint96 totalWeight, uint96 minWeight, uint96 maxWeight)
        internal
        pure
        returns (uint96[] memory)
    {
        uint256 _count = _calcActiveBlsPubKeyCount(totalWeight, minWeight, maxWeight);
        uint96[] memory _individualVotingPowers = new uint96[](_count);
        if (_count == 0) return _individualVotingPowers;
        uint256 _index;
        uint96 _remained = totalWeight;
        unchecked {
            while (_remained >= maxWeight + minWeight) {
                _individualVotingPowers[_index++] = maxWeight;
                _remained -= maxWeight;
            }
            if (_remained > maxWeight) {
                _individualVotingPowers[_index++] = minWeight;
                _individualVotingPowers[_index++] = _remained - minWeight;
            } else {
                _individualVotingPowers[_index++] = _remained;
            }
        }
        return _individualVotingPowers;
    }
}
