// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "./LagrangeDeployer.t.sol";

contract UpdateChainTest is LagrangeDeployer {
    function testGetAllEpochHistory() public {
        (uint256 startBlock,,, uint256 duration,,,,) = lagrangeCommittee.committeeParams(CHAIN_ID);

        (uint256[] memory flagBlocks, uint256[] memory flagEpoches, uint256[] memory durations) =
            _getAllEpochHistory(CHAIN_ID);

        assertEq(flagBlocks.length, 1);
        assertEq(flagEpoches.length, 1);
        assertEq(durations.length, 1);

        assertEq(flagBlocks[0], startBlock);
        assertEq(flagEpoches[0], 0);
        assertEq(durations[0], duration);
    }

    function testEpochPeriodUpdate_skipWithSameValue() public {
        (,,, uint256 duration,,,,) = lagrangeCommittee.committeeParams(CHAIN_ID);

        vm.roll(START_EPOCH + duration * 10);
        _updateEpochPeriod(CHAIN_ID, duration);

        uint32 epochHistoryCount = lagrangeCommittee.getEpochPeriodCount(CHAIN_ID);
        // epochHistoryCount should be still 1
        assertEq(epochHistoryCount, 1);
    }

    function testEpochPeriodUpdate_failWithSmallValue() public {
        (
            , // startBlock
            int256 l1Bias,
            uint256 genesisBlock,
            uint256 duration,
            uint256 freezeDuration,
            uint8 quorumNumber,
            uint96 minWeight,
            uint96 maxWeight
        ) = lagrangeCommittee.committeeParams(CHAIN_ID);

        uint256 newEpochPeriod = freezeDuration - 1; // set with smaller value than freezeDuration

        vm.roll(START_EPOCH + duration * 10);
        vm.prank(lagrangeCommittee.owner());
        vm.expectRevert("Invalid freeze duration");
        lagrangeCommittee.updateChain(
            CHAIN_ID, l1Bias, genesisBlock, newEpochPeriod, freezeDuration, quorumNumber, minWeight, maxWeight
        );
    }

    function testEpochPeriodUpdate_single() public {
        (uint256 startBlock,,, uint256 duration,,,,) = lagrangeCommittee.committeeParams(CHAIN_ID);

        uint256 newEpochPeriod = 30;

        vm.roll(startBlock + duration * 10 + 1);
        _updateEpochPeriod(CHAIN_ID, newEpochPeriod);

        (uint256[] memory flagBlocks, uint256[] memory flagEpoches, uint256[] memory durations) =
            _getAllEpochHistory(CHAIN_ID);

        // 1. check epoch hisotry
        {
            uint256 expectedFlagEpoch = lagrangeCommittee.getEpochNumber(CHAIN_ID, block.number - 1) + 1;
            uint256 expectedFlagBlock = startBlock + duration * expectedFlagEpoch;
            assertEq(durations.length, 2);

            assertEq(flagBlocks[0], startBlock);
            assertEq(flagEpoches[0], 0);
            assertEq(durations[0], duration);

            assertEq(flagBlocks[1], expectedFlagBlock);
            assertEq(flagEpoches[1], expectedFlagEpoch);
            assertEq(durations[1], newEpochPeriod);
        }

        // 2. check getEpochNumber with several cases
        {
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[0] - 1), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[0]), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[0] + durations[0]), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[0] + durations[0] * 2 - 1), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[0] + durations[0] * 2), 2);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[1] - durations[0]), flagEpoches[1] - 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[1] - 1), flagEpoches[1] - 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[1]), flagEpoches[1]);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[1] + 1), flagEpoches[1]);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[1] + durations[1]), flagEpoches[1] + 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[1] + durations[1] * 2), flagEpoches[1] + 2);
            assertEq(
                lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[1] + durations[1] * 100 - 1), flagEpoches[1] + 99
            );
            assertEq(
                lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[1] + durations[1] * 100), flagEpoches[1] + 100
            );
        }

        // 3. check isLocked with several cases
        {
            bool locked;
            uint256 blockNumber;

            vm.roll(flagBlocks[0]);
            (locked, blockNumber) = lagrangeCommittee.isLocked(CHAIN_ID);
            assertEq(locked, false);

            vm.roll(flagBlocks[1] - 1);
            (locked, blockNumber) = lagrangeCommittee.isLocked(CHAIN_ID);
            assertEq(locked, true);
            assertEq(blockNumber, flagBlocks[1]);

            vm.roll(flagBlocks[1] + 1);
            (locked, blockNumber) = lagrangeCommittee.isLocked(CHAIN_ID);
            assertEq(locked, false);

            vm.roll(flagBlocks[1] + durations[1] - FREEZE_DURATION + 1);
            (locked, blockNumber) = lagrangeCommittee.isLocked(CHAIN_ID);
            assertEq(locked, true);
            assertEq(blockNumber, flagBlocks[1] + durations[1]);
        }

        // 4. check isUpdatable with several cases
        {
            vm.roll(flagBlocks[1] - FREEZE_DURATION);
            assertEq(lagrangeCommittee.isUpdatable(CHAIN_ID, flagEpoches[1]), false);

            vm.roll(flagBlocks[1] - FREEZE_DURATION + 1);
            assertEq(lagrangeCommittee.isUpdatable(CHAIN_ID, flagEpoches[1]), true);

            vm.roll(flagBlocks[1] + durations[1] * 100 - FREEZE_DURATION);
            assertEq(lagrangeCommittee.isUpdatable(CHAIN_ID, flagEpoches[1] + 100), false);

            vm.roll(flagBlocks[1] + durations[1] * 100 - FREEZE_DURATION + 1);
            assertEq(lagrangeCommittee.isUpdatable(CHAIN_ID, flagEpoches[1] + 100), true);
        }
    }

    function testEpochPeriodUpdate_multiple() public {
        (uint256 startBlock,,, uint256 duration,,,,) = lagrangeCommittee.committeeParams(CHAIN_ID);

        vm.roll(startBlock + duration * 10 + 1);
        _updateEpochPeriod(CHAIN_ID, duration * 2);

        vm.roll(startBlock + duration * 100);
        _updateEpochPeriod(CHAIN_ID, duration * 5 / 2);

        vm.roll(startBlock + duration * 200);
        _updateEpochPeriod(CHAIN_ID, duration);

        (uint256[] memory flagBlocks, uint256[] memory flagEpoches, uint256[] memory durations) =
            _getAllEpochHistory(CHAIN_ID);

        assertEq(flagBlocks.length, 4);
        {
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[1] - 1), flagEpoches[1] - 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[1]), flagEpoches[1]);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[2] - 1), flagEpoches[2] - 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[2]), flagEpoches[2]);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[3] - 1), flagEpoches[3] - 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, flagBlocks[3]), flagEpoches[3]);
        }
    }

    function _getAllEpochHistory(uint32 chainID)
        internal
        returns (uint256[] memory _flagBlocks, uint256[] memory _flagEpoches, uint256[] memory _durations)
    {
        uint32 _epochHistoryCount = lagrangeCommittee.getEpochPeriodCount(chainID);
        _flagBlocks = new uint256[](_epochHistoryCount);
        _flagEpoches = new uint256[](_epochHistoryCount);
        _durations = new uint256[](_epochHistoryCount);
        for (uint32 i = 0; i < _epochHistoryCount; i++) {
            (_flagBlocks[i], _flagEpoches[i], _durations[i]) = lagrangeCommittee.getEpochPeriodByIndex(chainID, i + 1);
        }
    }

    function _updateEpochPeriod(uint32 chainID, uint256 newEpochPeriod) internal {
        (
            , // startBlock
            int256 l1Bias,
            uint256 genesisBlock,
            uint256 duration,
            uint256 freezeDuration,
            uint8 quorumNumber,
            uint96 minWeight,
            uint96 maxWeight
        ) = lagrangeCommittee.committeeParams(chainID);
        vm.prank(lagrangeCommittee.owner());
        lagrangeCommittee.updateChain(
            chainID, l1Bias, genesisBlock, newEpochPeriod, freezeDuration, quorumNumber, minWeight, maxWeight
        );
    }
}
