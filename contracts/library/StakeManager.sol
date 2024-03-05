// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStakeManager} from "../interfaces/IStakeManager.sol";

contract StakeManager is Initializable, OwnableUpgradeable, IStakeManager {
    using SafeERC20 for IERC20;

    mapping(address => bool) public tokenWhitelist;
    mapping(address => mapping(address => uint256)) public operatorShares;
    mapping(address => uint256) public stakeLockedBlock;
    // future use
    mapping(address => bool) public freezeOperators;

    address public immutable service;

    event Deposit(address indexed operator, address indexed token, uint256 amount);
    event Withdraw(address indexed operator, address indexed token, uint256 amount);

    modifier onlyService() {
        require(msg.sender == service, "Only service manager can call this function.");
        _;
    }

    modifier onlyWhitelisted(address token) {
        require(tokenWhitelist[token], "Token is not whitelisted");
        _;
    }

    constructor(address _service) {
        service = _service;
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    /// Add the token to the whitelist.
    function addTokensToWhitelist(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenWhitelist[tokens[i]] = true;
        }
    }

    /// Remove the token from the whitelist.
    function removeTokensFromWhitelist(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            delete tokenWhitelist[tokens[i]];
        }
    }

    function deposit(IERC20 token, uint256 amount) external onlyWhitelisted(address(token)) {
        token.safeTransferFrom(msg.sender, address(this), amount);
        operatorShares[msg.sender][address(token)] += amount;

        emit Deposit(msg.sender, address(token), amount);
    }

    function withdraw(IERC20 token, uint256 amount) external {
        require(!freezeOperators[msg.sender], "Operator is frozen");
        require(stakeLockedBlock[msg.sender] < block.number, "Stake is locked");
        require(operatorShares[msg.sender][address(token)] >= amount, "Insufficient balance");
        operatorShares[msg.sender][address(token)] -= amount;
        token.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, address(token), amount);
    }

    function lockStakeUntil(address operator, uint256 serveUntilBlock) external onlyService {
        stakeLockedBlock[operator] = serveUntilBlock;
    }

    // future use for slashing
    function resetFrozenStatus(address[] calldata frozenAddresses) external onlyOwner {
        // for (uint256 i = 0; i < frozenAddresses.length; i++) {
        //     freezeOperators[frozenAddresses[i]] = false;
        // }
    }

    function freezeOperator(address operator) external onlyService {
        // freezeOperators[operator] = true;
    }
}
