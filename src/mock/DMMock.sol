// SPDX-License-Identifier: BUSL-1.1

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.12;

import {IDelegationManager} from "eigenlayer-contracts/interfaces/IDelegationManager.sol";
import {IDelegationTerms} from "eigenlayer-contracts/interfaces/IDelegationTerms.sol";
import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategy.sol";

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

contract DelegationManager is IDelegationManager {
    mapping(address => uint256) private _operatorShares;
    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function registerAsOperator(IDelegationTerms dt) external onlyOwner {
        _operatorShares[address(dt)] = 100000000000000000;
    }

    function delegateTo(address /*operator*/) external {}

    function delegateToBySignature(address /*staker*/, address /*operator*/, uint256 expiry, bytes memory signature) external {}

    function undelegate(address /*staker*/) external {}

    function delegatedTo(address /*staker*/) external pure returns (address) {
        return address(0);
    }

    function delegationTerms(address /*operator*/) external pure returns (IDelegationTerms) {
        return IDelegationTerms(address(0));
    }

    function operatorShares(address operator, IStrategy /*strategy*/) external view returns (uint256) {
        return _operatorShares[operator];
    }

    function increaseDelegatedShares(address /*staker*/, IStrategy strategy, uint256 shares) external {}

    function decreaseDelegatedShares(address /*staker*/, IStrategy[] calldata strategies, uint256[] calldata shares)
        external
    {}

    function isDelegated(address /*staker*/) external pure returns (bool) {
        return false;
    }

    function isNotDelegated(address /*staker*/) external pure returns (bool) {
        return false;
    }

    function isOperator(address /*operator*/) external pure returns (bool) {
        return false;
    }
}
