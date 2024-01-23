// SPDX-License-Identifier: MIT

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import {IStakeManager} from "../interfaces/IStakeManager.sol";
import {IVoteWeigher} from "../interfaces/IVoteWeigher.sol";

contract VoteWeigher is Initializable, OwnableUpgradeable, IVoteWeigher {

    uint256 public constant WEIGHTING_DIVISOR = 1e18;

    mapping(uint8 => TokenMultiplier[]) public quorumMultipliers;

    IStakeManager public immutable stakeManager;

    constructor(IStakeManager _stakeManager)
    {
        _disableInitializers();
        stakeManager = _stakeManager;
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    function addQuorumMultiplier(uint8 quorumNumber, TokenMultiplier[] memory multipliers) external onlyOwner {
        require(quorumMultipliers[quorumNumber].length == 0, "Quorum already exists");
        for (uint256 i = 0; i < multipliers.length; i++) {
            quorumMultipliers[quorumNumber].push(multipliers[i]);
        }
    }

    function removeQuorumMultiplier(uint8 quorumNumber) external onlyOwner {
        delete quorumMultipliers[quorumNumber];
    }

    function updateQuorumMultiplier(uint8 quorumNumber, uint256 index, TokenMultiplier memory multiplier) external onlyOwner {
        require(quorumMultipliers[quorumNumber].length > index, "Index out of bounds");
        if (quorumMultipliers[quorumNumber].length == index) {
            quorumMultipliers[quorumNumber].push(multiplier);
        } else {
            quorumMultipliers[quorumNumber][index] = multiplier;
        }
    }

    function weightOfOperator(uint8 quorumNumber, address operator)
        external
        view
        returns (uint96)
    {
        uint256 totalWeight = 0;
        TokenMultiplier[] memory multipliers = quorumMultipliers[quorumNumber];
        for (uint256 i = 0; i < multipliers.length; i++) {
            uint256 balance = stakeManager.operatorShares(operator, multipliers[i].token);
            totalWeight += balance * multipliers[i].multiplier;
        }
        return uint96(totalWeight / WEIGHTING_DIVISOR);
    }
}
