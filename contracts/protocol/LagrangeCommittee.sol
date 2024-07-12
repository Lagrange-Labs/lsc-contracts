// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../interfaces/ILagrangeCommittee.sol";
import "../interfaces/ILagrangeService.sol";
import "../interfaces/IVoteWeigher.sol";
import "../library/BLSKeyChecker.sol";

contract LagrangeCommittee is BLSKeyChecker, Initializable, OwnableUpgradeable, ILagrangeCommittee {
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

    // ChainID => Epoch => CommitteeData
    mapping(uint32 => mapping(uint256 => CommitteeData)) public committees;

    // ChainID => Operator address[]
    mapping(uint32 => address[]) public committeeAddrs;
    // Tree Depth => Node Value
    mapping(uint8 => bytes32) private zeroHashes;

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

    // Adds a new operator to the committee
    function addOperator(address operator, address signAddress, BLSKeyWithProof calldata blsKeyWithProof)
        external
        onlyService
    {
        _validateBlsPubKeys(blsKeyWithProof.blsG1PublicKeys);
        _registerOperator(operator, signAddress, blsKeyWithProof);
    }

    // Removes an operator from the committee
    function removeOperator(address operator) external onlyService {
        delete operatorsStatus[operator];
    }

    // Unsubscribe chain by admin
    function unsubscribeByAdmin(address[] calldata operators, uint32 chainID) external onlyService {
        uint256 _length = operators.length;
        for (uint256 i; i < _length; i++) {
            address _operator = operators[i];
            require(subscribedChains[chainID][_operator], "The dedicated chain is not subscribed");
            delete subscribedChains[chainID][_operator];
            _removeOperatorFromCommitteeAddrs(chainID, _operator);
            operatorsStatus[_operator].subscribedChainCount--;
        }
    }

    // Adds additional BLS public keys to an operator
    function addBlsPubKeys(address operator, BLSKeyWithProof calldata blsKeyWithProof) external onlyService {
        _validateBlsPubKeys(blsKeyWithProof.blsG1PublicKeys);
        _addBlsPubKeys(operator, blsKeyWithProof);
    }

    // Updates an operator's BLS public key for the given index
    function updateBlsPubKey(address operator, uint32 index, BLSKeyWithProof calldata blsKeyWithProof)
        external
        onlyService
    {
        _validateBLSKeyWithProof(operator, blsKeyWithProof);
        require(blsKeyWithProof.blsG1PublicKeys.length == 1, "Length should be 1 for update");
        uint256[2][] storage _blsPubKeys = operatorsStatus[operator].blsPubKeys;
        require(_blsPubKeys.length > index, "Invalid index");
        _checkBlsPubKeyDuplicate(_blsPubKeys, blsKeyWithProof.blsG1PublicKeys[0]);
        _blsPubKeys[index] = blsKeyWithProof.blsG1PublicKeys[0];
    }

    // Removes BLS public keys from an operator for the given indices
    function removeBlsPubKeys(address operator, uint32[] calldata indices) external onlyService {
        uint256[2][] memory _blsPubKeys = operatorsStatus[operator].blsPubKeys;
        uint256 _length = _blsPubKeys.length;
        // it ensures that keep at least one BLS public key
        require(_length > indices.length, "Invalid indices length, BLS keys cannot be empty.");
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
        uint256[2][] memory _newBlsPubKeys = new uint256[2][](count);
        for (uint256 i; i < count; i++) {
            _newBlsPubKeys[i] = _blsPubKeys[i];
        }
        operatorsStatus[operator].blsPubKeys = _newBlsPubKeys;
    }

    // Updates an operator's sign address
    function updateSignAddress(address operator, address newSignAddress) external onlyService {
        require(operatorsStatus[operator].blsPubKeys.length != 0, "Operator is not registered.");
        operatorsStatus[operator].signAddress = newSignAddress;
        emit SignAddressUpdated(operator, newSignAddress);
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
    ) external onlyOwner {
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
    ) external onlyOwner {
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
        (, uint256 _freezeBlock,) = getEpochInterval(chainID, epochNumber - 1);
        return block.number > _freezeBlock;
    }

    // Checks if a chain's committee is locked at a given block
    function isLocked(uint32 chainID) public view returns (bool, uint256) {
        uint256 _epochNumber = _getEpochNumber(chainID, block.number);
        (, uint256 _freezeBlock, uint256 _endBlock) = getEpochInterval(chainID, _epochNumber);
        return (block.number > _freezeBlock, _endBlock);
    }

    // If applicable, updates committee based on staking, unstaking, and slashing.
    function update(uint32 chainID, uint256 epochNumber) external virtual {
        _updateCommittee(chainID, epochNumber, block.number);
    }

    function revertEpoch(uint32 chainID, uint256 epochNumber) public onlyOwner {
        require(updatedEpoch[chainID] == epochNumber, "The epochNumber is not the latest.");
        delete committees[chainID][epochNumber];
        updatedEpoch[chainID] = epochNumber - 1;
    }

    // Computes epoch number for a chain's committee at a given block
    function getEpochNumber(uint32 chainID, uint256 blockNumber) public view virtual returns (uint256 epochNumber) {
        epochNumber = _getEpochNumber(chainID, blockNumber);
        // All the prior blocks belong to epoch 1
        if (epochNumber == 0 && blockNumber >= committeeParams[chainID].genesisBlock) epochNumber = 1;
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
        committeeParams[_chainID] = CommitteeDef(
            _startBlock, _l1Bias, _genesisBlock, _duration, _freezeDuration, _quorumNumber, _minWeight, _maxWeight
        );

        emit UpdateCommitteeParams(
            _chainID, _quorumNumber, _l1Bias, _genesisBlock, _duration, _freezeDuration, _minWeight, _maxWeight
        );
    }

    // Get epoch interval for a given chain
    function getEpochInterval(uint32 chainID, uint256 epochNumber)
        public
        view
        returns (uint256 startBlock, uint256 freezeBlock, uint256 endBlock)
    {
        CommitteeDef memory committeeParam = committeeParams[chainID];
        uint256 _lastEpoch = updatedEpoch[chainID];

        if (epochNumber == 0) {
            startBlock = committeeParam.startBlock;
            endBlock =
                _lastEpoch == 0 ? committeeParam.startBlock + committeeParam.duration : _getUpdatedBlock(chainID, 1);
            freezeBlock = endBlock - committeeParam.freezeDuration;
            return (startBlock, freezeBlock, endBlock);
        }

        if (epochNumber <= _lastEpoch) {
            startBlock = _getUpdatedBlock(chainID, epochNumber);
            endBlock = _lastEpoch == epochNumber
                ? startBlock + committeeParam.duration
                : _getUpdatedBlock(chainID, epochNumber + 1);
            freezeBlock = endBlock - committeeParam.freezeDuration;
        } else {
            uint256 _lastEpochBlock = _lastEpoch > 0 ? _getUpdatedBlock(chainID, _lastEpoch) : committeeParam.startBlock;
            startBlock = _lastEpochBlock + (epochNumber - _lastEpoch) * committeeParam.duration;
            endBlock = startBlock + committeeParam.duration;
            freezeBlock = endBlock - committeeParam.freezeDuration;
        }
    }

    function _getEpochNumber(uint32 _chainID, uint256 _blockNumber) internal view returns (uint256 _epochNumber) {
        CommitteeDef memory committeeParam = committeeParams[_chainID];
        if (_blockNumber < committeeParam.startBlock) {
            return 0;
        }

        uint256 _lastEpoch = updatedEpoch[_chainID];
        uint256 _lastEpochBlock = _lastEpoch > 0 ? _getUpdatedBlock(_chainID, _lastEpoch) : committeeParam.startBlock;

        if (_blockNumber >= _lastEpochBlock) {
            _epochNumber = _lastEpoch + (_blockNumber - _lastEpochBlock) / committeeParam.duration;
            // _epochNumber = _lastEpoch;
        } else if (_lastEpoch == 0) {
            return 0;
        } else {
            // binary search
            uint256 _low = 0;
            uint256 _high = _lastEpoch;
            while (_low < _high - 1) {
                uint256 _mid = (_low + _high + 1) >> 1;
                if (_blockNumber < _getUpdatedBlock(_chainID, _mid)) {
                    _high = _mid;
                } else {
                    _low = _mid + 1;
                }
            }
            _epochNumber = _high - 1;
        }
    }

    function _registerOperator(address _operator, address _signAddress, BLSKeyWithProof memory _blsKeyWithProof)
        internal
    {
        _validateBLSKeyWithProof(_operator, _blsKeyWithProof);

        delete operatorsStatus[_operator];
        OperatorStatus storage _opStatus = operatorsStatus[_operator];
        _opStatus.signAddress = _signAddress;
        uint256 _length = _blsKeyWithProof.blsG1PublicKeys.length;
        for (uint256 i; i < _length; i++) {
            _checkBlsPubKeyDuplicate(_opStatus.blsPubKeys, _blsKeyWithProof.blsG1PublicKeys[i]);
            _opStatus.blsPubKeys.push(_blsKeyWithProof.blsG1PublicKeys[i]);
        }
    }

    function _addBlsPubKeys(address _operator, BLSKeyWithProof memory _blsKeyWithProof) internal {
        _validateBLSKeyWithProof(_operator, _blsKeyWithProof);

        OperatorStatus storage _opStatus = operatorsStatus[_operator];
        require(_opStatus.blsPubKeys.length != 0, "Operator is not registered.");
        uint256 _length = _blsKeyWithProof.blsG1PublicKeys.length;
        for (uint256 i; i < _length; i++) {
            _checkBlsPubKeyDuplicate(_opStatus.blsPubKeys, _blsKeyWithProof.blsG1PublicKeys[i]);
            _opStatus.blsPubKeys.push(_blsKeyWithProof.blsG1PublicKeys[i]);
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

        _removeOperatorFromCommitteeAddrs(_chainID, _operator);
    }

    function _removeOperatorFromCommitteeAddrs(uint32 _chainID, address _operator) internal {
        uint256 _length = committeeAddrs[_chainID].length;
        for (uint256 i; i < _length; i++) {
            if (committeeAddrs[_chainID][i] == _operator) {
                committeeAddrs[_chainID][i] = committeeAddrs[_chainID][_length - 1];
                committeeAddrs[_chainID].pop();
                break;
            }
        }
        require(_length == committeeAddrs[_chainID].length + 1, "Operator doesn't exist in committeeAddrs.");
    }

    function _updateCommittee(uint32 _chainID, uint256 _epochNumber, uint256 _l1BlockNumber) internal {
        require(isUpdatable(_chainID, _epochNumber), "Block number is prior to committee freeze window.");

        require(updatedEpoch[_chainID] + 1 == _epochNumber, "The epochNumber is not sequential.");

        CommitteeDef memory _committeeParam = committeeParams[_chainID];
        uint8 _quorumNumber = _committeeParam.quorumNumber;
        uint96 _minWeight = _committeeParam.minWeight;
        uint96 _maxWeight = _committeeParam.maxWeight;

        address[] memory _operators = committeeAddrs[_chainID];
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

        // Update roots
        committees[_chainID][_epochNumber].leafCount = uint32(_leafCounter);
        committees[_chainID][_epochNumber].root = _root;
        _setUpdatedBlock(_chainID, _epochNumber, _l1BlockNumber);
        updatedEpoch[_chainID] = _epochNumber;
        emit UpdateCommittee(_chainID, _epochNumber, _root);
    }

    function _getUpdatedBlock(uint32 _chainID, uint256 _epochNumber) internal view virtual returns (uint256) {
        return committees[_chainID][_epochNumber].updatedBlock;
    }

    function _setUpdatedBlock(uint32 _chainID, uint256 _epochNumber, uint256 _l1BlockNumber) internal virtual {
        committees[_chainID][_epochNumber].updatedBlock = SafeCast.toUint224(_l1BlockNumber);
    }

    function _validateBlsPubKeys(uint256[2][] memory _blsPubKeys) internal pure {
        require(_blsPubKeys.length != 0, "Empty BLS Public Keys.");
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
