// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";

import {IStakeManager} from "../interfaces/IStakeManager.sol";
import {ILagrangeCommittee} from "../interfaces/ILagrangeCommittee.sol";
import {ILagrangeService} from "../interfaces/ILagrangeService.sol";
import {IVoteWeigher} from "../interfaces/IVoteWeigher.sol";

contract LagrangeService is Initializable, OwnableUpgradeable, ILagrangeService {
    mapping(address => bool) public operatorWhitelist;

    ILagrangeCommittee public immutable committee;
    IStakeManager public immutable stakeManager;
    IAVSDirectory public immutable avsDirectory;
    IVoteWeigher public immutable voteWeigher;

    event OperatorRegistered(address indexed operator, uint32 serveUntilBlock);
    event OperatorDeregistered(address indexed operator);
    event OperatorSubscribed(address indexed operator, uint32 indexed chainID);
    event OperatorUnsubscribed(address indexed operator, uint32 indexed chainID);
    event OperatorEjected(address indexed operator);

    modifier onlyWhitelisted() {
        require(operatorWhitelist[msg.sender], "Operator is not whitelisted");
        _;
    }

    modifier onlyTestnet() {
        require(block.chainid != 1, "Only testnet allowed");
        _;
    }

    constructor(
        ILagrangeCommittee _committee,
        IStakeManager _stakeManager,
        address _avsDirectoryAddress,
        IVoteWeigher _voteWeigher
    ) {
        committee = _committee;
        stakeManager = _stakeManager;
        avsDirectory = IAVSDirectory(_avsDirectoryAddress);
        voteWeigher = _voteWeigher;
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    /// Add the operator to the whitelist.
    function addOperatorsToWhitelist(address[] calldata operators) external onlyOwner {
        for (uint256 i; i < operators.length; i++) {
            operatorWhitelist[operators[i]] = true;
        }
    }

    /// Remove the operator from the whitelist.
    function removeOperatorsFromWhitelist(address[] calldata operators) external onlyOwner {
        for (uint256 i; i < operators.length; i++) {
            delete operatorWhitelist[operators[i]];
        }
    }

    /// Add the operator to the service.
    function register(
        address signAddress,
        uint256[2][] calldata blsPubKeys,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external onlyWhitelisted {
        address _operator = msg.sender;
        committee.addOperator(_operator, signAddress, blsPubKeys);
        uint32 serveUntilBlock = type(uint32).max;
        stakeManager.lockStakeUntil(_operator, serveUntilBlock);
        avsDirectory.registerOperatorToAVS(_operator, operatorSignature);
        emit OperatorRegistered(_operator, serveUntilBlock);
    }

    /// Add extra BlsPubKeys
    function addBlsPubKeys(uint256[2][] calldata additionalBlsPubKeys) external onlyWhitelisted {
        address _operator = msg.sender;
        committee.addBlsPubKeys(_operator, additionalBlsPubKeys);
        uint32 serveUntilBlock = type(uint32).max;
        stakeManager.lockStakeUntil(_operator, serveUntilBlock);
        emit OperatorRegistered(_operator, serveUntilBlock);
    }

    /// Update the BlsPubKey for the given index
    function updateBlsPubKey(uint32 index, uint256[2] calldata blsPubKey) external onlyWhitelisted {
        address _operator = msg.sender;
        committee.updateBlsPubKey(_operator, index, blsPubKey);
    }

    /// Remove the BlsPubKeys for the given indices
    function removeBlsPubKeys(uint32[] calldata indices) external onlyWhitelisted {
        address _operator = msg.sender;
        committee.removeBlsPubKeys(_operator, indices);
    }

    /// Update the sign address for the operator
    function updateSignAddress(address newSignAddress) external onlyWhitelisted {
        address _operator = msg.sender;
        committee.updateSignAddress(_operator, newSignAddress);
    }

    /// Subscribe the dedicated chain.
    function subscribe(uint32 chainID) external onlyWhitelisted {
        committee.subscribeChain(msg.sender, chainID);
        emit OperatorSubscribed(msg.sender, chainID);
    }

    /// Unsubscribe the dedicated chain.
    function unsubscribe(uint32 chainID) external onlyWhitelisted {
        committee.unsubscribeChain(msg.sender, chainID);
        emit OperatorUnsubscribed(msg.sender, chainID);
    }

    /// Deregister the operator from the service.
    function deregister() external onlyWhitelisted {
        address _operator = msg.sender;
        (bool possible, uint256 unsubscribeBlockNumber) = committee.isUnregisterable(_operator);
        require(possible, "The operator is not able to deregister");
        stakeManager.lockStakeUntil(_operator, unsubscribeBlockNumber);
        committee.removeOperator(_operator);
        avsDirectory.deregisterOperatorFromAVS(_operator);
        emit OperatorDeregistered(_operator);
    }

    /// Owner can eject the operator from the service.
    /// note This function is available only on testnet.
    function ejectOperator(address operator) external onlyOwner onlyTestnet {
        committee.ejectOperator(operator);
        emit OperatorEjected(operator);
    }

    function owner() public view override(OwnableUpgradeable, ILagrangeService) returns (address) {
        return OwnableUpgradeable.owner();
    }

    // Updates the metadata URI for the AVS
    function updateAVSMetadataURI(string calldata _metadataURI) public virtual onlyOwner {
        avsDirectory.updateAVSMetadataURI(_metadataURI);
    }

    // Returns the list of strategies that the operator has potentially restaked on the AVS
    function getOperatorRestakedStrategies(address operator) external view returns (address[] memory) {
        return committee.getTokenListForOperator(operator);
    }

    // Returns the list of strategies that the AVS supports for restaking
    function getRestakeableStrategies() external view returns (address[] memory) {
        return voteWeigher.getTokenList();
    }
}
