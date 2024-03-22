// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "forge-std/Test.sol";

import "../interfaces/ILagrangeCommittee.sol";
import "../interfaces/ILagrangeService.sol";
import "../interfaces/IVoteWeigher.sol";

contract LagrangeCommittee is
    Initializable,
    OwnableUpgradeable,
    ILagrangeCommittee
{
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
    mapping(uint32 => uint224) public totalVotingPower;

    // ChainID => Operator address[]
    mapping(uint32 => address[]) public committeeAddrs;
    // Tree Depth => Node Value
    mapping(uint8 => bytes32) zeroHashes;

    mapping(address => OperatorStatus) internal operators;

    // ChainID => Epoch check if committee tree has been updated
    mapping(uint32 => uint256) public updatedEpoch;

    mapping(uint32 => mapping(address => bool)) public subscribedChains;

    // Event fired on initialization of a new committee
    event InitCommittee(
        uint256 chainID,
        uint256 duration,
        uint256 freezeDuration,
        uint8 quorumNumber
    );

    // Fired on successful rotation of committee
    event UpdateCommittee(uint256 chainID, bytes32 current);

    modifier onlyService() {
        if (msg.sender != address(service)) {
            console.log(msg.sender, address(service));
        }
        require(
            msg.sender == address(service),
            "Only Lagrange service can call this function."
        );
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
    function _initCommittee(
        uint32 chainID,
        uint256 _duration,
        uint256 _freezeDuration,
        uint8 _quorumNumber,
        uint96 minWeight,
        uint96 maxWeight
    ) internal {
        require(
            committeeParams[chainID].startBlock == 0,
            "Committee has already been initialized."
        );

        _validateVotingPowerRange(minWeight, maxWeight);

        committeeParams[chainID] = CommitteeDef(
            block.number,
            _duration,
            _freezeDuration,
            _quorumNumber,
            minWeight,
            maxWeight
        );
        committees[chainID][0] = CommitteeData(0, 0, 0);

        emit InitCommittee(chainID, _duration, _freezeDuration, _quorumNumber);
    }

    // Adds address stake data and flags it for committee addition
    function addOperator(
        address operator,
        uint256[2][] memory blsPubKeys
    ) public onlyService {
        OperatorStatus storage opStatus = operators[operator];
        require(
            opStatus.blsPubKeys.length == 0,
            "Operator is already registered."
        );
        opStatus.blsPubKeys = blsPubKeys;
    }

    // Adds address stake data and flags it for committee addition
    function addBlsPubKeys(
        address operator,
        uint256[2][] memory additionalBlsPubKeys
    ) public onlyService {
        OperatorStatus storage opStatus = operators[operator];
        require(opStatus.blsPubKeys.length != 0, "Operator is not registered.");

        uint256 _length = additionalBlsPubKeys.length;
        for (uint256 i; i < _length; i++) {
            opStatus.blsPubKeys.push(additionalBlsPubKeys[i]);
        }
    }

    function subscribeChain(
        address operator,
        uint32 chainID
    ) external onlyService {
        // Check if the chainID is already registered
        require(
            committeeParams[chainID].startBlock > 0,
            "The dedicated chain is not registered."
        );

        (bool locked, ) = isLocked(chainID);
        require(!locked, "The dedicated chain is locked.");

        OperatorStatus storage opStatus = operators[operator];

        for (uint256 i; i < opStatus.unsubscribedParams.length; i++) {
            UnsubscribedParam memory param = opStatus.unsubscribedParams[i];
            if (param.chainID == chainID) {
                if (
                    param.blockNumber > 0 && param.blockNumber >= block.number
                ) {
                    revert("The dedciated chain is while unsubscribing.");
                }
            }
        }

        require(
            !subscribedChains[chainID][operator],
            "The dedicated chain is already subscribed."
        );

        subscribedChains[chainID][operator] = true;
        opStatus.subscribedChainCount++;

        committeeAddrs[chainID].push(operator);
    }

    function unsubscribeChain(
        address operator,
        uint32 chainID
    ) external onlyService {
        OperatorStatus storage opStatus = operators[operator];

        require(
            subscribedChains[chainID][operator],
            "The dedicated chain is not subscribed"
        );

        (bool locked, uint256 blockNumber) = isLocked(chainID);
        require(!locked, "The dedicated chain is locked.");

        subscribedChains[chainID][operator] = false;
        opStatus.unsubscribedParams.push(
            UnsubscribedParam(chainID, blockNumber)
        );
        opStatus.subscribedChainCount = opStatus.subscribedChainCount - 1;

        uint256 _length = committeeAddrs[chainID].length;
        for (uint256 i; i < _length; i++) {
            if (committeeAddrs[chainID][i] == operator) {
                committeeAddrs[chainID][i] = committeeAddrs[chainID][
                    _length - 1
                ];
            }
        }
        committeeAddrs[chainID].pop();
    }

    function isUnregisterable(
        address operator
    ) public view returns (bool, uint256) {
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

    function getBlsPubKeys(
        address operator
    ) public view returns (uint256[2][] memory) {
        return operators[operator].blsPubKeys;
    }

    // Returns chain"s committee current and next roots at a given block.
    function getCommittee(
        uint32 chainID,
        uint256 blockNumber
    )
        public
        view
        returns (CommitteeData memory currentCommittee, bytes32 nextRoot)
    {
        uint256 epochNumber = getEpochNumber(chainID, blockNumber);
        uint256 nextCommitteeEpoch = getEpochNumber(chainID, blockNumber + 1);
        currentCommittee = committees[chainID][epochNumber];
        nextRoot = committees[chainID][nextCommitteeEpoch].root;
        return (currentCommittee, nextRoot);
    }

    // Calculate the inner node hash from left and right children
    function _innerHash(
        bytes32 left,
        bytes32 right
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(INNER_NODE_PREFIX, left, right));
    }

    // Initializes a new committee, and optionally associates addresses with it.
    function registerChain(
        uint32 chainID,
        uint256 epochPeriod,
        uint256 freezeDuration,
        uint8 quorumNumber,
        uint96 minWeight,
        uint96 maxWeight
    ) public onlyOwner {
        _initCommittee(
            chainID,
            epochPeriod,
            freezeDuration,
            quorumNumber,
            minWeight,
            maxWeight
        );
        _updateCommittee(chainID, 0, 0);
        chainIDs.push(chainID);
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

        committeeParams[chainID] = CommitteeDef(
            _startBlock,
            epochPeriod,
            freezeDuration,
            quorumNumber,
            minWeight,
            maxWeight
        );
    }

    // Checks if a chain"s committee is updatable at a given block
    function isUpdatable(
        uint32 chainID,
        uint256 epochNumber
    ) public view returns (bool) {
        uint256 epochEnd = epochNumber *
            committeeParams[chainID].duration +
            committeeParams[chainID].startBlock;
        uint256 freezeDuration = committeeParams[chainID].freezeDuration;
        return block.number > epochEnd - freezeDuration;
    }

    // Checks if a chain"s committee is locked at a given block
    function isLocked(uint32 chainID) public view returns (bool, uint256) {
        if (committeeParams[chainID].duration == 0) {
            return (false, 0);
        }
        uint256 epochNumber = getEpochNumber(chainID, block.number);
        uint256 epochEnd = epochNumber *
            committeeParams[chainID].duration +
            committeeParams[chainID].startBlock;
        return (
            block.number > epochEnd - committeeParams[chainID].freezeDuration,
            epochEnd
        );
    }

    // If applicable, updates committee based on staking, unstaking, and slashing.
    function update(uint32 chainID, uint256 epochNumber) public {
        require(
            isUpdatable(chainID, epochNumber),
            "Block number is prior to committee freeze window."
        );

        require(updatedEpoch[chainID] < epochNumber, "Already updated.");

        CommitteeDef memory _committeeParam = committeeParams[chainID];
        uint8 _quorumNumber = _committeeParam.quorumNumber;
        uint96 _minWeight = _committeeParam.minWeight;
        uint96 _maxWeight = _committeeParam.maxWeight;

        address[] memory _operators = committeeAddrs[chainID];
        uint256 _operatorCount = _operators.length;

        uint256 _leafCounter;

        // pre-calculate array size (can be bigger than actual size)
        for (uint256 i; i < _operatorCount; ) {
            unchecked {
                _leafCounter += operators[_operators[i]].blsPubKeys.length;
                i++;
            }
        }

        bytes32[] memory _committeeLeaves = new bytes32[](_leafCounter);
        {
            _leafCounter = 0;
            uint224 _totalVotingPower;
            for (uint256 i; i < _operatorCount; ) {
                address _operator = _operators[i];

                OperatorStatus storage opStatus = operators[_operator];
                uint96 _votingPower = _checkVotingPower(
                    uint32(operators[_operator].blsPubKeys.length), // blsPubKeyCount
                    voteWeigher.weightOfOperator(_quorumNumber, _operator), // voteWeight
                    _minWeight,
                    _maxWeight
                );

                uint96 _remained = _votingPower;
                unchecked {
                    for (uint256 j; _remained > 0; ) {
                        uint96 _individualVotingPower;
                        if (_remained >= _maxWeight + _minWeight) {
                            _individualVotingPower = _maxWeight;
                        } else if (_remained > _maxWeight) {
                            _individualVotingPower = _minWeight;
                        } else {
                            _individualVotingPower = _remained;
                        }
                        _remained -= _individualVotingPower;
                        _committeeLeaves[_leafCounter] = _leafHash(
                            _operator,
                            opStatus.blsPubKeys[j],
                            _individualVotingPower
                        );
                        j++;
                        _leafCounter++;
                    }
                }
                unchecked {
                    _totalVotingPower += _votingPower; // This doesn't overflow, since _totalVotingPower is uint224
                    i++;
                }
            }
            totalVotingPower[chainID] = _totalVotingPower;
        }

        bytes32 _root;
        unchecked {
            // Nothing to overflow/underflow
            uint256 _childCount = _leafCounter;
            for (uint8 _h; _childCount > 1; _h++) {
                uint256 _parentCount = (_childCount + 1) >> 1;
                for (uint256 _i = 1; _i < _childCount; _i += 2) {
                    _committeeLeaves[_i >> 1] = _innerHash(
                        _committeeLeaves[_i - 1],
                        _committeeLeaves[_i]
                    );
                }
                if (_childCount & 1 == 1) {
                    _committeeLeaves[_parentCount - 1] = _innerHash(
                        _committeeLeaves[_childCount - 1],
                        zeroHashes[_h]
                    );
                }
                _childCount = _parentCount;
            }
            _root = _committeeLeaves[0];
        }

        _updateCommittee(chainID, epochNumber, _root);
    }

    function _updateCommittee(
        uint32 chainID,
        uint256 epochNumber,
        bytes32 root
    ) internal {
        uint256 nextEpoch = epochNumber + COMMITTEE_NEXT_1;
        // Update roots
        committees[chainID][nextEpoch].leafCount = uint32(
            committeeAddrs[chainID].length
        );
        committees[chainID][nextEpoch].root = root;
        committees[chainID][nextEpoch].totalVotingPower = totalVotingPower[
            chainID
        ];
        updatedEpoch[chainID] = epochNumber;
        emit UpdateCommittee(
            chainID,
            bytes32(committees[chainID][nextEpoch].root)
        );
    }

    // Computes epoch number for a chain"s committee at a given block
    function getEpochNumber(
        uint32 chainID,
        uint256 blockNumber
    ) public view returns (uint256) {
        uint256 startBlockNumber = committeeParams[chainID].startBlock;
        uint256 epochPeriod = committeeParams[chainID].duration;
        return (blockNumber - startBlockNumber) / epochPeriod + 1;
    }

    // Returns the leaf hash for a given operator
    function _leafHash(
        address opAddr,
        uint256[2] memory blsPubKey,
        uint256 _votingPower
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    LEAF_NODE_PREFIX,
                    blsPubKey[0],
                    blsPubKey[1],
                    opAddr,
                    _votingPower
                )
            );
    }

    // Get the operator status except subscribed chains
    function getOperatorStatus(
        address opAddr
    ) public view returns (uint8, UnsubscribedParam[] memory) {
        OperatorStatus storage opStatus = operators[opAddr];
        return (opStatus.subscribedChainCount, opStatus.unsubscribedParams);
    }

    // Get the operator"s voting power for the given chainID
    function getOperatorVotingPower(
        address opAddr,
        uint32 chainID
    ) public view returns (uint96) {
        OperatorStatus storage opStatus = operators[opAddr];
        CommitteeDef memory _committeeParam = committeeParams[chainID];
        uint96 _weight = voteWeigher.weightOfOperator(
            _committeeParam.quorumNumber,
            opAddr
        );
        return
            _checkVotingPower(
                uint32(opStatus.blsPubKeys.length),
                _weight,
                _committeeParam.minWeight,
                _committeeParam.maxWeight
            );
    }

    // Get array of voting powers of individual BlsPubKeys
    function getBlsPubKeyVotingPowers(
        address opAddr,
        uint32 chainID
    ) public view returns (uint96[] memory individualVotingPowers) {
        uint96 _votingPower = getOperatorVotingPower(opAddr, chainID);
        uint96 _minWeight = committeeParams[chainID].minWeight;
        uint96 _maxWeight = committeeParams[chainID].maxWeight;
        return _divideVotingPower(_votingPower, _minWeight, _maxWeight);
    }

    function _validateVotingPowerRange(
        uint96 minWeight,
        uint96 maxWeight
    ) internal pure {
        require(
            minWeight > 0 && maxWeight >= minWeight * 2,
            "Invalid min/max Weight"
        );
    }

    function _checkVotingPower(
        uint32 blsPubKeysCount,
        uint96 votingPower,
        uint96 minWeight,
        uint96 maxWeight
    ) internal pure returns (uint96) {
        if (votingPower < minWeight) {
            return 0;
        }
        unchecked {
            uint256 _amountLimit = uint256(maxWeight) *
                uint256(blsPubKeysCount); // This value can be bigger than type(uint96).max

            if (votingPower > _amountLimit) {
                votingPower = uint96(_amountLimit);
            }
        }
        return votingPower;
    }

    function _calcActiveBlsPubKeyCount(
        uint96 _votingPower,
        uint96 minWeight,
        uint96 maxWeight
    ) internal pure returns (uint32) {
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

    function _divideVotingPower(
        uint96 totalWeight,
        uint96 minWeight,
        uint96 maxWeight
    ) internal pure returns (uint96[] memory) {
        uint256 _count = _calcActiveBlsPubKeyCount(
            totalWeight,
            minWeight,
            maxWeight
        );
        uint96[] memory _individualVotingPowers = new uint96[](_count);
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

    function getVotingPowerByBlsPubKeyIndex(
        uint96 votingPower,
        uint96 minWeight,
        uint96 maxWeight,
        uint256 index
    ) public pure returns (uint96) {
        uint32 _activeBlsPubKeyCount = _calcActiveBlsPubKeyCount(
            votingPower,
            minWeight,
            maxWeight
        );
        if (index >= _activeBlsPubKeyCount) return 0;
        uint96 _lastRemained = ((votingPower - minWeight) % maxWeight) +
            minWeight;
        if (index < (votingPower - _lastRemained) / maxWeight) {
            return maxWeight;
        }
        if (_lastRemained > maxWeight) {
            return
                index == _activeBlsPubKeyCount - 1
                    ? minWeight
                    : _lastRemained - minWeight;
        } else {
            return _lastRemained;
        }
    }
}
