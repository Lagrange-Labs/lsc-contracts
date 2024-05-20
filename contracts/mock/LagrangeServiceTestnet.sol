// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "../protocol/LagrangeService.sol";

contract LagrangeServiceTestnet is LagrangeService {
    constructor(
        ILagrangeCommittee _committee,
        IStakeManager _stakeManager,
        address _avsDirectoryAddress,
        IVoteWeigher _voteWeigher
    ) LagrangeService(_committee, _stakeManager, _avsDirectoryAddress, _voteWeigher) {}

    // In testnet mode, owner can eject operator
    function unsubscribeByAdmin(address[] calldata operators, uint32 chainID) external override onlyOwner {
        committee.unsubscribeByAdmin(operators, chainID);
        uint256 _length = operators.length;
        for (uint256 i; i < _length; i++) {
            emit UnsubscribedByAdmin(operators[i], chainID);
        }
    }
}
