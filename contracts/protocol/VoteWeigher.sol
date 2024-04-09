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

    uint8[] quorumNumbers; // list of all quorum numbers

    event QuorumAdded(uint8 indexed quorumNumber, TokenMultiplier[] multipliers);
    event QuorumRemoved(uint8 indexed quorumNumber);
    event QuorumUpdated(uint8 indexed quorumNumber, uint256 index, TokenMultiplier multiplier);

    constructor(IStakeManager _stakeManager)
    {
        _disableInitializers();
        stakeManager = _stakeManager;
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    function addQuorumMultiplier(uint8 quorumNumber, TokenMultiplier[] calldata multipliers) external onlyOwner {
        require(multipliers.length != 0, "Empty list of multipliers");
        require(quorumMultipliers[quorumNumber].length == 0, "Quorum already exists");
        for (uint256 i; i < multipliers.length; i++) {
            _checkMultiplierDuplicate(quorumMultipliers[quorumNumber], multipliers[i].token);
            quorumMultipliers[quorumNumber].push(multipliers[i]);
        }
        quorumNumbers.push(quorumNumber);
        emit QuorumAdded(quorumNumber, multipliers);
    }

    function removeQuorumMultiplier(uint8 quorumNumber) external onlyOwner {
        require(quorumMultipliers[quorumNumber].length != 0, "Quorum doesn't exist");
        uint256 _length = quorumNumbers.length;
        for (uint256 i; i < _length; i++) {
            if (quorumNumbers[i] == quorumNumber) {
                quorumNumbers[i] = quorumNumbers[_length - 1];
                quorumNumbers.pop();
                break;
            }
        }
        delete quorumMultipliers[quorumNumber];
        emit QuorumRemoved(quorumNumber);
    }

    function updateQuorumMultiplier(uint8 quorumNumber, uint256 index, TokenMultiplier calldata multiplier) external onlyOwner {
        require(quorumMultipliers[quorumNumber].length >= index, "Index out of bounds");
        if (quorumMultipliers[quorumNumber].length == index) {
            _checkMultiplierDuplicate(quorumMultipliers[quorumNumber], multiplier.token);
            quorumMultipliers[quorumNumber].push(multiplier);
        } else {
            uint256 _length = quorumMultipliers[quorumNumber].length;
            for (uint i; i < _length; i++) {
                if (i != index) {
                    require(quorumMultipliers[quorumNumber][i].token != multiplier.token, "Multiplier already exists");
                }
            }
            quorumMultipliers[quorumNumber][index] = multiplier;
        }
        emit QuorumUpdated(quorumNumber, index, multiplier);
    }

    function weightOfOperator(uint8 quorumNumber, address operator)
        external
        view
        returns (uint96)
    {
        uint256 totalWeight = 0;
        TokenMultiplier[] memory multipliers = quorumMultipliers[quorumNumber];
        for (uint256 i; i < multipliers.length; i++) {
            uint256 balance = stakeManager.operatorShares(operator, multipliers[i].token);
            totalWeight += balance * multipliers[i].multiplier;
        }
        return uint96(totalWeight / WEIGHTING_DIVISOR);
    }

    function getTokenList() external view returns (address[] memory) {
        return _getTokenListForQuorumNumbers(quorumNumbers);
    }

    function getTokenListForQuorumNumbers(uint8[] calldata quorumNumbers_) external view returns (address[] memory) {
        return _getTokenListForQuorumNumbers(quorumNumbers_);
    }

    function _getTokenListForQuorumNumbers(uint8[] memory _quorumNumbers) internal view returns (address[] memory) {
        uint256 _length = _quorumNumbers.length;
        uint256 _totalCount;
        for (uint256 i; i < _length; i++) {
            _totalCount += quorumMultipliers[_quorumNumbers[i]].length;
        }
        address[] memory _tokens = new address[](_totalCount);
        uint256 _index;
        for (uint256 i; i < _length; i++) {
            for (uint256 j; j < quorumMultipliers[_quorumNumbers[i]].length; j++) {
                bool _exist = false;
                for (uint256 k; k < _index; k++) {
                    if (_tokens[k] == quorumMultipliers[_quorumNumbers[i]][j].token) {
                        _exist = true;
                        break;
                    }
                }
                if (!_exist) {
                    _tokens[_index] = quorumMultipliers[_quorumNumbers[i]][j].token;
                    _index++;
                }
            }
        }
        address[] memory _tokenList = new address[](_index);
        for (uint256 i; i < _index; i++) {
            _tokenList[i] = _tokens[i];
        }
        return _tokenList;
    }

    function _checkMultiplierDuplicate(TokenMultiplier[] memory _multipliers, address _token) internal pure {
        uint256 _length = _multipliers.length;
        for (uint256 i; i < _length; i++) {
            require(_multipliers[i].token != _token, "Multiplier already exists");
        }
    }
}
