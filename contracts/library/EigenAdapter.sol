// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";

import {IStakeManager} from "../interfaces/IStakeManager.sol";

contract EigenAdapter is Initializable, OwnableUpgradeable, IStakeManager {
    // future use
    mapping(address => bool) public freezeOperators;

    address public immutable service;
    IDelegationManager public immutable delegationManager;

    modifier onlyService() {
        require(msg.sender == service, "Only service manager can call this function.");
        _;
    }

    constructor(address _service, IDelegationManager _delegationManager) {
        service = _service;
        delegationManager = _delegationManager;
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    function deposit(IERC20 token, uint256 amount) external pure {}

    function withdraw(IERC20 token, uint256 amount) external pure {}

    function lockStakeUntil(address operator, uint256 serveUntilBlock) external pure onlyService {}

    function operatorShares(address operator, address token) external view returns (uint256) {
        return delegationManager.operatorShares(operator, IStrategy(token));
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
