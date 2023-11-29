// SPDX-License-Identifier: BUSL-1.1

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.12;

import {ISlasher} from "eigenlayer-contracts/src/contracts/interfaces/ISlasher.sol";

contract Slasher is ISlasher {
    function optIntoSlashing(address /*contractAddress*/) external pure {}

    function freezeOperator(address /*toBeFrozen*/) external pure {}

    function resetFrozenStatus(address[] calldata frozenAddresses) external pure {}

    function recordFirstStakeUpdate(address /*operator*/, uint32 /*serveUntilBlock*/) external pure {}

    function recordStakeUpdate(address /*operator*/, uint32 updateBlock, uint32 /*serveUntilBlock*/, uint256 /*insertAfter*/)
        external pure
    {}

    function recordLastStakeUpdateAndRevokeSlashingAbility(address /*operator*/, uint32 /*serveUntilBlock*/) external pure {}

    function isFrozen(address /*staker*/) external pure returns (bool) {
        return false;
    }

    function canSlash(address /*toBeSlashed*/, address /*slashingContract*/) external pure returns (bool) {
        return true;
    }

    function contractCanSlashOperatorUntilBlock(address /*operator*/, address /*serviceContract*/)
        external
        pure
        returns (uint32)
    {
        return type(uint32).max;
    }

    function latestUpdateBlock(address /*operator*/, address /*serviceContract*/) external pure returns (uint32) {
        return 0;
    }

    function getCorrectValueForInsertAfter(address /*operator*/, uint32 /*updateBlock*/) external pure returns (uint256) {
        return type(uint32).max;
    }

    function canWithdraw(address /*operator*/, uint32 withdrawalStartBlock, uint256 middlewareTimesIndex)
        external
        returns (bool)
    {}

    function operatorToMiddlewareTimes(address /*operator*/, uint256 arrayIndex)
        external
        pure
        returns (MiddlewareTimes memory)
    {}

    function middlewareTimesLength(address /*operator*/) external pure returns (uint256) {
        return 0;
    }

    function getMiddlewareTimesIndexBlock(address /*operator*/, uint32 /*index*/) external pure returns (uint32) {
        return 0;
    }

    function getMiddlewareTimesIndexServeUntilBlock(address /*operator*/, uint32 /*index*/) external pure returns (uint32) {
        return 0;
    }

    function operatorWhitelistedContractsLinkedListSize(address /*operator*/) external pure returns (uint256) {
        return 0;
    }

    function operatorWhitelistedContractsLinkedListEntry(address /*operator*/, address /*node*/)
        external
        pure
        returns (bool, uint256, uint256)
    {
        return (true, 0, 0);
    }
}
