// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../LagrangeCommittee.sol";

contract LagrangeCommitteeTestnet is LagrangeCommittee {
    constructor(ILagrangeService _service, IVoteWeigher _voteWeigher) LagrangeCommittee(_service, _voteWeigher) {}

    function update(uint32, uint256) external pure override {
        revert("In testnet mode, you should use updateWithL1BlockNumber.");
    }

    function updateWithL1BlockNumber(uint32 chainID, uint256 epochNumber, uint256 l1BlockNumber) external {
        _updateCommittee(chainID, epochNumber, l1BlockNumber);
    }

    function getEpochNumber(uint32 chainID, uint256 l1BlockNumber) public view override returns (uint256 epochNumber) {
        epochNumber = _getEpochNumberByL1(chainID, l1BlockNumber);
        // All the prior blocks belong to epoch 1
        if (
            epochNumber == 0
                && uint256(int256(l1BlockNumber) + committeeParams[chainID].l1Bias) >= committeeParams[chainID].genesisBlock
        ) epochNumber = 1;
    }

    function _getUpdatedBlock(uint32 _chainID, uint256 _epochNumber) internal view override returns (uint256) {
        return (committees[_chainID][_epochNumber].updatedBlock << 112) >> 112;
    }

    function _getUpdatedL1Block(uint32 _chainID, uint256 _epochNumber) internal view returns (uint256) {
        uint256 _stored = committees[_chainID][_epochNumber].updatedBlock;
        return (_stored >> 112) != 0 ? (_stored >> 112) : uint256(int256(_stored) - committeeParams[_chainID].l1Bias);
    }

    function _setUpdatedBlock(uint32 _chainID, uint256 _epochNumber, uint256 _l1BlockNumber) internal override {
        require(_epochNumber <= type(uint112).max, "Epoch number is too big");
        require(_l1BlockNumber <= type(uint112).max, "L1 block number is too big");
        require(_l1BlockNumber != 0, "L1 block number is zero");
        committees[_chainID][_epochNumber].updatedBlock = SafeCast.toUint224((_l1BlockNumber << 112) | block.number);
    }

    function _getEpochNumberByL1(uint32 _chainID, uint256 _l1BlockNumber)
        internal
        view
        returns (uint256 _epochNumber)
    {
        CommitteeDef memory _committeeParam = committeeParams[_chainID];

        uint256 _l1StartBlock = uint256(int256(_committeeParam.startBlock) - committeeParams[_chainID].l1Bias);
        if (_l1BlockNumber < _l1StartBlock) {
            return 0;
        }

        uint256 _lastEpoch = updatedEpoch[_chainID];
        uint256 _lastEpochBlock = _lastEpoch > 0 ? _getUpdatedL1Block(_chainID, _lastEpoch) : _l1StartBlock;

        if (_l1BlockNumber >= _lastEpochBlock) {
            _epochNumber = _lastEpoch + (_l1BlockNumber - _lastEpochBlock) / _committeeParam.duration;
        } else if (_lastEpoch == 0) {
            return 0;
        } else {
            // binary search
            uint256 _low = 0;
            uint256 _high = _lastEpoch;
            while (_low < _high - 1) {
                uint256 _mid = (_low + _high + 1) >> 1;
                if (_l1BlockNumber < _getUpdatedL1Block(_chainID, _mid)) {
                    _high = _mid;
                } else {
                    _low = _mid + 1;
                }
            }
            _epochNumber = _high - 1;
        }
    }
}
