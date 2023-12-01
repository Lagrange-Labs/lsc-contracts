// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IVoteWeigher.sol";
import "../interfaces/IStakeManager.sol";

contract StakeManager is Initializable, OwnableUpgradeable, IStakeManager, IVoteWeigher {
    struct TokenMultiplier {
        address token;
        uint96 multiplier;
    }

    uint256 internal constant _WEIGHTING_DIVISOR = 1e18;

    mapping(address => mapping(address => uint256)) public operatorStakes;
    TokenMultiplier[] public tokenMultipliers;

    mapping(uint8 => uint8[]) public quorumIndexes;
    mapping(address => bool) public freezeOperators;
    mapping(address => uint32) public lastStakeUpdateBlock;

    address public immutable serviceManager;
    uint8 public immutable numberOfQuorums;

    modifier onlyServiceManager() {
        require(msg.sender == serviceManager, "Only service manager can call this function.");
        _;
    }

    constructor(address _serviceManager, uint8 _numberOfQuorums) {
        numberOfQuorums = _numberOfQuorums;
        serviceManager = _serviceManager;
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    function deposit(address token, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        operatorStakes[token][msg.sender] += amount;
    }

    function withdraw(address token, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(!freezeOperators[msg.sender], "Operator is frozen");
        require(lastStakeUpdateBlock[msg.sender] < block.number, "Stake is locked");
        require(operatorStakes[token][msg.sender] >= amount, "Insufficient balance");
        operatorStakes[token][msg.sender] -= amount;
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
    }

    function setTokenMultiplier(address token, uint96 multiplier) external onlyOwner {
        for (uint256 i = 0; i < tokenMultipliers.length; i++) {
            if (tokenMultipliers[i].token == token) {
                tokenMultipliers[i].multiplier = multiplier;
                return;
            }
        }
        tokenMultipliers.push(TokenMultiplier({token: token, multiplier: multiplier}));
    }

    function setQuorumIndexes(uint8 quorumNumber, uint8[] calldata indexes) external onlyOwner {
        require(quorumNumber < numberOfQuorums, "Invalid quorum number");
        quorumIndexes[quorumNumber] = indexes;
    }

    function weightOfOperator(uint8 quorumNumber, address operator) external view override returns (uint96) {
        require(quorumNumber < numberOfQuorums, "Invalid quorum number");
        uint256 weight = 0;
        for (uint256 i = 0; i < quorumIndexes[quorumNumber].length; i++) {
            uint8 index = quorumIndexes[quorumNumber][i];
            weight += (operatorStakes[tokenMultipliers[index].token][operator] * tokenMultipliers[index].multiplier)
                / _WEIGHTING_DIVISOR;
        }
        return uint96(weight);
    }

    function resetFrozenStatus(address[] calldata frozenAddresses) external override onlyOwner {
        for (uint256 i = 0; i < frozenAddresses.length; i++) {
            freezeOperators[frozenAddresses[i]] = false;
        }
    }

    function freezeOperator(address operator) external override onlyServiceManager {
        freezeOperators[operator] = true;
    }

    function recordFirstStakeUpdate(address operator, uint32 serveUntilBlock) external override onlyServiceManager {
        lastStakeUpdateBlock[operator] = serveUntilBlock;
    }

    function recordStakeUpdate(address operator, uint32 updateBlock, uint32 serveUntilBlock, uint256 prevElement)
        external
        override
    {}

    function recordLastStakeUpdateAndRevokeSlashingAbility(address operator, uint32 serveUntilBlock)
        external
        override
        onlyServiceManager
    {
        lastStakeUpdateBlock[operator] = serveUntilBlock;
    }

    function isFrozen(address operator) external view override returns (bool) {
        return freezeOperators[operator];
    }
}
