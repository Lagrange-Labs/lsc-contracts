// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../library/HermezHelpers.sol";
import "../library/EvidenceVerifier.sol";
import "../interfaces/ILagrangeCommittee.sol";
import "../interfaces/ILagrangeService.sol";
import "../interfaces/IVoteWeigher.sol";

contract LagrangeCommittee is
    Initializable,
    OwnableUpgradeable,
    HermezHelpers,
    ILagrangeCommittee
{
    uint8 public constant UPDATE_TYPE_REGISTER = 1;
    uint8 public constant UPDATE_TYPE_AMOUNT_CHANGE = 2;
    uint8 public constant UPDATE_TYPE_UNREGISTER = 3;

    ILagrangeService public immutable service;
    IVoteWeigher public immutable voteWeigher;

    // Active Committee
    uint256 public constant COMMITTEE_CURRENT = 0;
    // Frozen Committee - Next "Current" Committee
    uint256 public constant COMMITTEE_NEXT_1 = 1;

    // ChainID => OperatorUpdate[]
    mapping(uint32 => OperatorUpdate[]) public updatedOperators;

    // ChainID => Committee
    mapping(uint32 => CommitteeDef) public committeeParams;
    // ChainID => Epoch => CommitteeData
    mapping(uint32 => mapping(uint256 => CommitteeData)) public committees;

    /* Live Committee Data */
    // ChainID => Merkle Nodes
    mapping(uint32 => uint256[]) public committeeLeaves;
    // ChainID => Address => CommitteeLeaf Index
    mapping(uint32 => mapping(address => uint32)) public committeeLeavesMap;
    // ChainID => Address[]
    mapping(uint32 => address[]) public committeeAddrs;

    mapping(address => OperatorStatus) public operators;

    // ChainID => Epoch check if committee tree has been updated
    mapping(uint32 => uint256) public updatedEpoch;

    // Event fired on initialization of a new committee
    event InitCommittee(
        uint256 chainID,
        uint256 duration,
        uint256 freezeDuration
    );

    // Fired on successful rotation of committee
    event UpdateCommittee(uint256 chainID, bytes32 current);

    modifier onlyService() {
        require(
            msg.sender == address(service),
            "LagrangeCommittee: Only Lagrange service can call this function."
        );
        _;
    }

    modifier onlyServiceManager() {
        require(
            msg.sender == voteWeigher.serviceManager(),
            "LagrangeCommittee: Only Lagrange service manager can call this function."
        );
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
        _transferOwnership(initialOwner);
    }

    // Initialize new committee.
    function _initCommittee(
        uint32 chainID,
        uint256 _duration,
        uint256 freezeDuration
    ) internal {
        require(
            committeeParams[chainID].startBlock == 0,
            "Committee has already been initialized."
        );

        committeeParams[chainID] = CommitteeDef(
            block.number,
            _duration,
            freezeDuration
        );
        committees[chainID][0] = CommitteeData(0, 0, 0);
        committeeLeaves[chainID] = new uint256[](0);

        emit InitCommittee(chainID, _duration, freezeDuration);
    }

    function getServeUntilBlock(address operator) public view returns (uint32) {
        return operators[operator].serveUntilBlock;
    }

    function updateOperator(
        OperatorUpdate memory opUpdate
    ) external onlyServiceManager {
        if (opUpdate.updateType == UPDATE_TYPE_AMOUNT_CHANGE) {
            operators[opUpdate.operator].amount = voteWeigher.weightOfOperator(
                opUpdate.operator,
                1
            );
        }
        updatedOperators[operators[opUpdate.operator].chainID].push(opUpdate);
    }

    function setSlashed(address operator) external onlyService {
        operators[operator].slashed = true;
    }

    function getSlashed(address operator) public view returns (bool) {
        return operators[operator].slashed;
    }

    // Returns chain's committee current and next roots at a given block.
    function getCommittee(
        uint32 chainID,
        uint256 blockNumber
    )
        public
        view
        returns (CommitteeData memory currentCommittee, uint256 nextRoot)
    {
        uint256 epochNumber = getEpochNumber(chainID, blockNumber);
        uint256 nextEpoch = getEpochNumber(chainID, blockNumber + 1);
        currentCommittee = committees[chainID][epochNumber];
        nextRoot = committees[chainID][nextEpoch].root;
    }

    // Computes and returns "next" committee root.
    function getNext1CommitteeRoot(
        uint32 chainID
    ) public view returns (uint256) {
        if (committeeLeaves[chainID].length == 0) {
            return _hash2Elements([uint256(0), uint256(0)]);
        } else if (committeeLeaves[chainID].length == 1) {
            return committeeLeaves[chainID][0];
        }

        // Calculate limit
        uint256 _lim = 2;
        uint256 height = 1;
        uint256 dataLength = committeeLeaves[chainID].length;
        while (_lim < dataLength) {
            _lim *= 2;
            ++height;
        }

        uint256[] memory branches = new uint256[](height + 1);
        uint256 right;
        uint256 _h;
        uint256 i = 1;
        for (; i < dataLength; i += 2) {
            _h = 0;
            right = committeeLeaves[chainID][i];
            branches[0] = committeeLeaves[chainID][i - 1];
            while ((i >> _h) & 1 == 1) {
                right = _hash2Elements([branches[_h], right]);
                _h++;
            }
            branches[_h] = right;
        }

        if (i == dataLength) {
            branches[0] = committeeLeaves[chainID][i - 1];
            _h = 0;
            right = 0;
            while ((i >> _h) & 1 == 1) {
                right = _hash2Elements([branches[_h], right]);
                _h++;
            }
            branches[_h] = right;
            i += 2;
        }

        branches[0] = 0;
        for (; i < _lim; i += 2) {
            _h = 0;
            right = 0;
            while ((i >> _h) & 1 == 1) {
                right = _hash2Elements([branches[_h], right]);
                _h++;
            }
            branches[_h] = right;
        }

        return branches[height];
    }

    // Recalculates committee root (next_1)
    function _compCommitteeRoot(uint32 chainID, uint256 epochNumber) internal {
        uint256 nextRoot = getNext1CommitteeRoot(chainID);

        // Update roots
        uint256 nextEpoch = epochNumber + COMMITTEE_NEXT_1;
        committees[chainID][nextEpoch].height = committeeLeaves[chainID].length;
        committees[chainID][nextEpoch].root = nextRoot;
        committees[chainID][nextEpoch].totalVotingPower = _getTotalVotingPower(
            chainID
        );
    }

    // Initializes a new committee, and optionally associates addresses with it.
    function registerChain(
        uint32 chainID,
        uint256 epochPeriod,
        uint256 freezeDuration
    ) public onlyOwner {
        _initCommittee(chainID, epochPeriod, freezeDuration);
        _update(chainID, 0);
    }

    // Adds address stake data and flags it for committee addition
    function addOperator(
        address operator,
        bytes memory blsPubKey,
        uint32 chainID,
        uint32 serveUntilBlock
    ) public onlyService {
        uint96 stakeAmount = voteWeigher.weightOfOperator(operator, 1);
        operators[operator] = OperatorStatus(
            stakeAmount,
            blsPubKey,
            serveUntilBlock,
            chainID,
            false
        );
    }

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

    // If applicable, updates committee based on staking, unstaking, and slashing.
    function update(uint32 chainID, uint256 epochNumber) public {
        require(
            isUpdatable(chainID, epochNumber),
            "Block number is prior to committee freeze window."
        );

        require(updatedEpoch[chainID] < epochNumber, "Already updated.");

        _update(chainID, epochNumber);
    }

    function _update(uint32 chainID, uint256 epochNumber) internal {
        for (uint256 i = 0; i < updatedOperators[chainID].length; i++) {
            OperatorUpdate memory opUpdate = updatedOperators[chainID][i];
            if (opUpdate.updateType == UPDATE_TYPE_REGISTER) {
                _registerOperator(opUpdate.operator);
            } else if (opUpdate.updateType == UPDATE_TYPE_AMOUNT_CHANGE) {
                _updateAmount(opUpdate.operator);
            } else if (opUpdate.updateType == UPDATE_TYPE_UNREGISTER) {
                _unregisterOperator(opUpdate.operator);
            }
        }

        _compCommitteeRoot(chainID, epochNumber);

        updatedEpoch[chainID] = epochNumber;
        delete updatedOperators[chainID];

        emit UpdateCommittee(
            chainID,
            bytes32(committees[chainID][epochNumber + COMMITTEE_NEXT_1].root)
        );
    }

    function _registerOperator(address operator) internal {
        uint32 chainID = operators[operator].chainID;
        uint32 leafIndex = uint32(committeeLeaves[chainID].length);
        committeeLeaves[chainID].push(getLeafHash(operator));
        committeeLeavesMap[chainID][operator] = leafIndex;
        committeeAddrs[chainID].push(operator);
    }

    function _updateAmount(address operator) internal {
        uint32 chainID = operators[operator].chainID;
        uint256 leafIndex = committeeLeavesMap[chainID][operator];
        committeeLeaves[chainID][leafIndex] = getLeafHash(operator);
    }

    function _unregisterOperator(address operator) internal {
        uint32 chainID = operators[operator].chainID;
        uint32 leafIndex = uint32(committeeLeavesMap[chainID][operator]);
        uint256 lastIndex = committeeLeaves[chainID].length - 1;
        address lastAddr = committeeAddrs[chainID][lastIndex];

        committeeLeaves[chainID][leafIndex] = committeeLeaves[chainID][
            lastIndex
        ];
        committeeLeavesMap[chainID][lastAddr] = leafIndex;
        committeeLeaves[chainID].pop();
        committeeAddrs[chainID].pop();
    }

    // Computes epoch number for a chain's committee at a given block
    function getEpochNumber(
        uint32 chainID,
        uint256 blockNumber
    ) public view returns (uint256) {
        uint256 startBlockNumber = committeeParams[chainID].startBlock;
        uint256 epochPeriod = committeeParams[chainID].duration;
        return (blockNumber - startBlockNumber) / epochPeriod + 1;
    }

    // Returns cumulative strategy shares for opted in addresses
    function _getTotalVotingPower(
        uint32 chainID
    ) internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < committeeAddrs[chainID].length; i++) {
            total += operators[committeeAddrs[chainID][i]].amount;
        }
        return total;
    }

    function getLeafHash(address opAddr) public view returns (uint256) {
        uint96[11] memory slices;
        OperatorStatus memory opStatus = operators[opAddr];
        for (uint i = 0; i < 8; i++) {
            bytes memory addr = new bytes(12);
            for (uint j = 0; j < 12; j++) {
                addr[j] = opStatus.blsPubKey[(i * 12) + j];
            }
            bytes12 addrChunk = bytes12(addr);
            slices[i] = uint96(addrChunk);
        }
        bytes memory addrBytes = abi.encodePacked(
            opAddr,
            uint128(opStatus.amount)
        );
        for (uint i = 0; i < 3; i++) {
            bytes memory addr = new bytes(12);
            for (uint j = 0; j < 12; j++) {
                addr[j] = addrBytes[(i * 12) + j];
            }
            bytes12 addrChunk = bytes12(addr);
            slices[i + 8] = uint96(addrChunk);
        }

        return
            _hash2Elements(
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
                        [
                            uint256(slices[6]),
                            uint256(slices[7]),
                            uint256(slices[8]),
                            uint256(slices[9]),
                            uint256(slices[10])
                        ]
                    )
                ]
            );
    }
}
