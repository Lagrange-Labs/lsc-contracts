// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

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

    // Registered ChainIDs
    uint32[] public chainIDs;
    // ChainID => Committee
    mapping(uint32 => CommitteeDef) public committeeParams;

    // committees is also used for external storage for epoch period modification
    //   committees[chainID][uint256.max].leafCount = current index of epoch period
    //   committees[chainID][uint256.max - 1] : 1-index
    //          updatedBlock:  (flagBlock << 112) | flagEpoch
    //          leafCount:  epochPeriod
    //   committees[chainID][uint256.max - 2] : 2-index
    //   committees[chainID][uint256.max - 3] : 3-index
    //      ...   ...   ...
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

    // Initializes epoch period
    // @dev This function can be called for the chainID registered in the previous version
    function setFirstEpochPeriod(uint32 chainID) public onlyOwner {
        uint32 _count = getEpochPeriodCount(chainID);
        if (_count > 0) return; // already initialized
        CommitteeDef memory _committeeParam = committeeParams[chainID];

        _writeEpochPeriod(chainID, _committeeParam.startBlock, 0, _committeeParam.duration);
    }

    // Adds a new operator to the committee
    function addOperator(address operator, address signAddress, uint256[2][] calldata blsPubKeys)
        external
        onlyService
    {
        _validateBlsPubKeys(blsPubKeys);
        _registerOperator(operator, signAddress, blsPubKeys);
    }

    // Removes an operator from the committee
    function removeOperator(address operator) external onlyService {
        delete operatorsStatus[operator];
    }

    // Adds additional BLS public keys to an operator
    function addBlsPubKeys(address operator, uint256[2][] calldata additionalBlsPubKeys) external onlyService {
        _validateBlsPubKeys(additionalBlsPubKeys);
        _addBlsPubKeys(operator, additionalBlsPubKeys);
    }

    // Updates an operator's BLS public key for the given index
    function updateBlsPubKey(address operator, uint32 index, uint256[2] calldata blsPubKey) external onlyService {
        require(blsPubKey[0] != 0 && blsPubKey[1] != 0, "Invalid BLS Public Key.");
        uint256[2][] storage _blsPubKeys = operatorsStatus[operator].blsPubKeys;
        require(_blsPubKeys.length > index, "Invalid index");
        _checkBlsPubKeyDuplicate(_blsPubKeys, blsPubKey);
        _blsPubKeys[index] = blsPubKey;
    }

    // Removes BLS public keys from an operator for the given indices
    function removeBlsPubKeys(address operator, uint32[] calldata indices) external onlyService {
        uint256[2][] memory _blsPubKeys = operatorsStatus[operator].blsPubKeys;
        uint256 _length = _blsPubKeys.length;
        for (uint256 i; i < indices.length; i++) {
            require(_length > indices[i], "Invalid index");
            _blsPubKeys[indices[i]][0] = 0;
            _blsPubKeys[indices[i]][1] = 0;
        }
        uint32 count;
        for (uint256 i; i < _length; i++) {
            if (_blsPubKeys[i][0] != 0 || _blsPubKeys[i][1] != 0) {
                _blsPubKeys[count] = _blsPubKeys[i];
                count++;
            }
        }
        operatorsStatus[operator].blsPubKeys = _blsPubKeys;
        for (uint256 i = count; i < _length; i++) {
            operatorsStatus[operator].blsPubKeys.pop();
        }
    }

    // Updates an operator's sign address
    function updateSignAddress(address operator, address newSignAddress) external onlyService {
        operatorsStatus[operator].signAddress = newSignAddress;
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
        _validateFreezeDuration(epochPeriod, freezeDuration);

        _initCommittee(chainID, genesisBlock, epochPeriod, freezeDuration, quorumNumber, minWeight, maxWeight);
    }

    function updateChain(
        uint32 chainID,
        int256 l1Bias,
        uint256 genesisBlock,
        uint256 epochPeriod,
        uint256 freezeDuration,
        uint8 quorumNumber,
        uint96 minWeight,
        uint96 maxWeight
    ) public onlyOwner {
        uint256 _startBlock = committeeParams[chainID].startBlock;
        require(_startBlock != 0, "Chain not initialized");

        _validateVotingPowerRange(minWeight, maxWeight);
        _validateFreezeDuration(epochPeriod, freezeDuration);

        _updateCommitteeParams(
            chainID, l1Bias, _startBlock, genesisBlock, epochPeriod, freezeDuration, quorumNumber, minWeight, maxWeight
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
        (, uint256 _freezeBlock,) = _getEpochInterval(chainID, epochNumber - 1);
        return block.number > _freezeBlock;
    }

    // Checks if a chain's committee is locked at a given block
    function isLocked(uint32 chainID) public view returns (bool, uint256) {
        uint256 _epochNumber = _getEpochNumber(chainID, block.number);
        (, uint256 _freezeBlock, uint256 _endBlock) = _getEpochInterval(chainID, _epochNumber);
        return (block.number > _freezeBlock, _endBlock);
    }

    // If applicable, updates committee based on staking, unstaking, and slashing.
    function update(uint32 chainID, uint256 epochNumber) public {
        require(isUpdatable(chainID, epochNumber), "Block number is prior to committee freeze window.");

        require(updatedEpoch[chainID] + 1 == epochNumber, "The epochNumber is not sequential.");

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

    function revertEpoch(uint32 chainID, uint256 epochNumber) public onlyOwner {
        require(updatedEpoch[chainID] == epochNumber, "The epochNumber is not the latest.");
        delete committees[chainID][epochNumber];
        updatedEpoch[chainID] = epochNumber - 1;
    }

    // Computes epoch number for a chain's committee at a given block
    function getEpochNumber(uint32 chainID, uint256 blockNumber) public view returns (uint256 epochNumber) {
        // we don't need to care about safeCast here, only getting API
        blockNumber = uint256(int256(blockNumber) + committeeParams[chainID].l1Bias);

        epochNumber = _getEpochNumber(chainID, blockNumber);
        // All the prior blocks belong to epoch 1
        if (epochNumber == 0) epochNumber = 1;
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
        uint8[] memory _quorumNumbers = new uint8[](operatorsStatus[operator].subscribedChainCount);
        uint256 _count;
        for (uint256 i; i < _length; i++) {
            uint32 _chainID = chainIDs[i];
            if (subscribedChains[_chainID][operator]) {
                _quorumNumbers[_count++] = committeeParams[_chainID].quorumNumber;
            }
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
        committeeParams[_chainID] = CommitteeDef(
            block.number, 0, _genesisBlock, _duration, _freezeDuration, _quorumNumber, _minWeight, _maxWeight
        );
        committees[_chainID][0] = CommitteeData(0, 0, 0);

        chainIDs.push(_chainID);

        setFirstEpochPeriod(_chainID);

        emit InitCommittee(_chainID, _quorumNumber, _genesisBlock, _duration, _freezeDuration, _minWeight, _maxWeight);
    }

    // Update committee.
    function _updateCommitteeParams(
        uint32 _chainID,
        int256 _l1Bias,
        uint256 _startBlock,
        uint256 _genesisBlock,
        uint256 _duration,
        uint256 _freezeDuration,
        uint8 _quorumNumber,
        uint96 _minWeight,
        uint96 _maxWeight
    ) internal {
        if (committeeParams[_chainID].duration != _duration) {
            uint256 _flagEpoch = _getEpochNumber(_chainID, block.number - 1) + 1;
            (,, uint256 _endBlockPrv) = _getEpochInterval(_chainID, _flagEpoch - 1);
            _writeEpochPeriod(_chainID, _endBlockPrv, _flagEpoch, _duration);
        }

        committeeParams[_chainID] = CommitteeDef(
            _startBlock, _l1Bias, _genesisBlock, _duration, _freezeDuration, _quorumNumber, _minWeight, _maxWeight
        );

        emit UpdateCommitteeParams(
            _chainID, _quorumNumber, _l1Bias, _genesisBlock, _duration, _freezeDuration, _minWeight, _maxWeight
        );
    }

    // ----------------- Functions for Epoch Number ----------------- //
    function getEpochPeriodCount(uint32 chainID) public view returns (uint32) {
        return committees[chainID][type(uint256).max].leafCount;
    }

    function getEpochPeriod(uint32 chainID, uint32 index)
        public
        view
        returns (uint256 flagBlock, uint256 flagEpoch, uint256 duration)
    {
        CommitteeData memory _epochPeriodContext = committees[chainID][type(uint256).max - index];
        return (
            _epochPeriodContext.updatedBlock >> 112,
            (_epochPeriodContext.updatedBlock << 112) >> 112,
            _epochPeriodContext.leafCount
        );
    }

    function _writeEpochPeriod(uint32 _chainID, uint256 _flagBlock, uint256 _flagEpoch, uint256 _duration) internal {
        uint32 _index = committees[_chainID][type(uint256).max].leafCount + 1;
        committees[_chainID][type(uint256).max - _index] = CommitteeData(
            0,
            (uint224(SafeCast.toUint112(_flagBlock)) << 112) + uint224(SafeCast.toUint112(_flagEpoch)),
            SafeCast.toUint32(_duration)
        );
        committees[_chainID][type(uint256).max].leafCount = _index;
        emit EpochPeriodUpdated(_chainID, _index, _flagBlock, _flagEpoch, _duration);
    }

    function _getEpochNumber(uint32 _chainID, uint256 _blockNumber) internal view returns (uint256 _epochNumber) {
        if (_blockNumber < committeeParams[_chainID].genesisBlock) {
            return 0;
        }
        // epoch period would be updated rarely
        uint32 _index = getEpochPeriodCount(_chainID);
        while (_index > 0) {
            (uint256 _flagBlock, uint256 _flagEpoch, uint256 _duration) = getEpochPeriod(_chainID, _index);
            if (_blockNumber >= _flagBlock) {
                _epochNumber = _flagEpoch + (_blockNumber - _flagBlock) / _duration;
                break;
            }
            unchecked {
                _index--;
            }
        }
    }

    function _getEpochInterval(uint32 _chainID, uint256 _epochNumber)
        internal
        view
        returns (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock)
    {
        // epoch period would be updated rarely
        uint32 _index = getEpochPeriodCount(_chainID);
        while (_index > 0) {
            (uint256 _flagBlock, uint256 _flagEpoch, uint256 _duration) = getEpochPeriod(_chainID, _index);
            if (_epochNumber >= _flagEpoch) {
                _startBlock = (_epochNumber - _flagEpoch) * _duration + _flagBlock;
                _endBlock = _startBlock + _duration;
                _freezeBlock = _endBlock - committeeParams[_chainID].freezeDuration;
                break;
            }
            unchecked {
                _index--;
            }
        }
    }
    // ------------------------------------------------------------- //

    function _registerOperator(address _operator, address _signAddress, uint256[2][] memory _blsPubKeys) internal {
        delete operatorsStatus[_operator];
        OperatorStatus storage _opStatus = operatorsStatus[_operator];
        _opStatus.signAddress = _signAddress;
        uint256 _length = _blsPubKeys.length;
        for (uint256 i; i < _length; i++) {
            _checkBlsPubKeyDuplicate(_opStatus.blsPubKeys, _blsPubKeys[i]);
            _opStatus.blsPubKeys.push(_blsPubKeys[i]);
        }
    }

    function _addBlsPubKeys(address _operator, uint256[2][] memory _additionalBlsPubKeys) internal {
        OperatorStatus storage _opStatus = operatorsStatus[_operator];
        require(_opStatus.blsPubKeys.length != 0, "Operator is not registered.");
        uint256 _length = _additionalBlsPubKeys.length;
        for (uint256 i; i < _length; i++) {
            _checkBlsPubKeyDuplicate(_opStatus.blsPubKeys, _additionalBlsPubKeys[i]);
            _opStatus.blsPubKeys.push(_additionalBlsPubKeys[i]);
        }
    }

    function _checkBlsPubKeyDuplicate(uint256[2][] memory _blsPubKeys, uint256[2] memory _blsPubKey) internal pure {
        uint256 _length = _blsPubKeys.length;
        for (uint256 i; i < _length; i++) {
            require(_blsPubKeys[i][0] != _blsPubKey[0] || _blsPubKeys[i][1] != _blsPubKey[1], "Duplicated BlsPubKey");
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
        _opStatus.subscribedChainCount--;

        uint256 _length = committeeAddrs[_chainID].length;
        for (uint256 i; i < _length; i++) {
            if (committeeAddrs[_chainID][i] == _operator) {
                committeeAddrs[_chainID][i] = committeeAddrs[_chainID][_length - 1];
            }
        }
        committeeAddrs[_chainID].pop();
    }

    function _updateCommittee(uint32 _chainID, uint256 _epochNumber, bytes32 _root, uint32 _leafCount) internal {
        // Update roots
        committees[_chainID][_epochNumber].leafCount = _leafCount;
        committees[_chainID][_epochNumber].root = _root;
        committees[_chainID][_epochNumber].updatedBlock = uint224(block.number);
        updatedEpoch[_chainID] = _epochNumber;
        emit UpdateCommittee(_chainID, _epochNumber, _root);
    }

    function _validateBlsPubKeys(uint256[2][] memory _blsPubKeys) internal pure {
        require(_blsPubKeys.length != 0, "Empty BLS Public Keys.");
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

    function _validateFreezeDuration(uint256 _epochPeriod, uint256 _freezeDuration) internal pure {
        require(_epochPeriod > _freezeDuration, "Invalid freeze duration");
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
