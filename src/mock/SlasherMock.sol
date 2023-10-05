// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";

contract Slasher is ISlasher {
    function optIntoSlashing(address contractAddress) external {}

    function freezeOperator(address toBeFrozen) external {}

    function resetFrozenStatus(address[] calldata frozenAddresses) external {}

    function recordFirstStakeUpdate(address operator, uint32 serveUntilBlock) external {}

    function recordStakeUpdate(address operator, uint32 updateBlock, uint32 serveUntilBlock, uint256 insertAfter)
        external
    {}

    function recordLastStakeUpdateAndRevokeSlashingAbility(address operator, uint32 serveUntilBlock) external {}

    function isFrozen(address staker) external view returns (bool) {
        return false;
    }

    function canSlash(address toBeSlashed, address slashingContract) external view returns (bool) {
        return true;
    }

    function contractCanSlashOperatorUntilBlock(address operator, address serviceContract)
        external
        view
        returns (uint32)
    {
        return type(uint32).max;
    }

    function latestUpdateBlock(address operator, address serviceContract) external view returns (uint32) {
        return 0;
    }

    function getCorrectValueForInsertAfter(address operator, uint32 updateBlock) external view returns (uint256) {
        return type(uint32).max;
    }

    function canWithdraw(address operator, uint32 withdrawalStartBlock, uint256 middlewareTimesIndex)
        external
        returns (bool)
    {}

    function operatorToMiddlewareTimes(address operator, uint256 arrayIndex)
        external
        view
        returns (MiddlewareTimes memory)
    {}

    function middlewareTimesLength(address operator) external view returns (uint256) {
        return 0;
    }

    function getMiddlewareTimesIndexBlock(address operator, uint32 index) external view returns (uint32) {
        return 0;
    }

    function getMiddlewareTimesIndexServeUntilBlock(address operator, uint32 index) external view returns (uint32) {
        return 0;
    }

    function operatorWhitelistedContractsLinkedListSize(address operator) external view returns (uint256) {
        return 0;
    }

    function operatorWhitelistedContractsLinkedListEntry(address operator, address node)
        external
        view
        returns (bool, uint256, uint256)
    {
        return (true, 0, 0);
    }
}
