// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IStakeManager {
    function freezeOperator(address toBeFrozen) external;

    function resetFrozenStatus(address[] calldata frozenAddresses) external;

    function recordFirstStakeUpdate(address operator, uint32 serveUntilBlock) external;

    function recordStakeUpdate(address operator, uint32 updateBlock, uint32 serveUntilBlock, uint256 insertAfter)
        external;

    function recordLastStakeUpdateAndRevokeSlashingAbility(address operator, uint32 serveUntilBlock) external;

    function isFrozen(address staker) external view returns (bool);
}
