// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./LagrangeDeployer.t.sol";
import "../../contracts/protocol/testnet/LagrangeCommitteeTestnet.sol";

contract UpdateChainTest is LagrangeDeployer {
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

    function testEpochPeriodUpdate() public {
        (uint256 startBlock,, uint256 genesisBlock, uint256 duration, uint256 freezeDuration,,,) =
            lagrangeCommittee.committeeParams(CHAIN_ID);

        // Originally
        {
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, genesisBlock - 1), 0);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, genesisBlock), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, startBlock), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, startBlock + duration), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, startBlock + duration * 2 - 1), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, startBlock + duration * 2), 2);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, startBlock + duration * 3 - 1), 2);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, startBlock + duration * 3), 3);

            (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                lagrangeCommittee.getEpochInterval(CHAIN_ID, 10);
            assertEq(_startBlock, startBlock + duration * 10);
            assertEq(_freezeBlock, startBlock + duration * 11 - freezeDuration);
            assertEq(_endBlock, startBlock + duration * 11);
        }

        // Update failed before lock period
        vm.roll(startBlock + duration - freezeDuration);
        vm.expectRevert("Block number is prior to committee freeze window.");
        lagrangeCommittee.update(CHAIN_ID, 1);

        // Update in some block
        uint256 updatedBlock1 = startBlock + duration - freezeDuration + 4;
        vm.roll(updatedBlock1);
        lagrangeCommittee.update(CHAIN_ID, 1);

        uint256 updatedBlock2 = updatedBlock1 + duration;
        vm.roll(updatedBlock2);
        lagrangeCommittee.update(CHAIN_ID, 2);

        uint256 updatedBlock3 = updatedBlock1 + duration * 100;
        vm.roll(updatedBlock3);
        lagrangeCommittee.update(CHAIN_ID, 3);

        // Test getEpochInterval
        {
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, genesisBlock - 1), 0);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, genesisBlock), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, startBlock), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, updatedBlock1), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, updatedBlock2 - 1), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, updatedBlock2), 2);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, updatedBlock3 - 1), 2);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, updatedBlock3), 3);

            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 1);
                assertEq(_startBlock, updatedBlock1);
                assertEq(_freezeBlock, updatedBlock2 - freezeDuration);
                assertEq(_endBlock, updatedBlock2);
            }
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 2);
                assertEq(_startBlock, updatedBlock2);
                assertEq(_freezeBlock, updatedBlock3 - freezeDuration);
                assertEq(_endBlock, updatedBlock3);
            }
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 3);
                assertEq(_startBlock, updatedBlock3);
                assertEq(_freezeBlock, updatedBlock3 + duration - freezeDuration);
                assertEq(_endBlock, updatedBlock3 + duration);
            }
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 10);
                assertEq(_startBlock, updatedBlock3 + duration * 7);
                assertEq(_freezeBlock, updatedBlock3 + duration * 8 - freezeDuration);
                assertEq(_endBlock, updatedBlock3 + duration * 8);
            }
        }

        uint256 newEpochPeriod = 30;

        _updateEpochPeriod(CHAIN_ID, newEpochPeriod);

        // Test getEpochInterval
        {
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 2);
                assertEq(_startBlock, updatedBlock2);
                assertEq(_freezeBlock, updatedBlock3 - freezeDuration);
                assertEq(_endBlock, updatedBlock3);
            }
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 3);
                assertEq(_startBlock, updatedBlock3);
                assertEq(_freezeBlock, updatedBlock3 + newEpochPeriod - freezeDuration);
                assertEq(_endBlock, updatedBlock3 + newEpochPeriod);
            }
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 10);
                assertEq(_startBlock, updatedBlock3 + newEpochPeriod * 7);
                assertEq(_freezeBlock, updatedBlock3 + newEpochPeriod * 8 - freezeDuration);
                assertEq(_endBlock, updatedBlock3 + newEpochPeriod * 8);
            }
        }
    }

    function test_CommitteeTestnet() public {
        address owner = lagrangeCommittee.owner();
        vm.startPrank(owner);
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))),
            address(new LagrangeCommitteeTestnet(lagrangeService, IVoteWeigher(voteWeigher)))
        );
        vm.stopPrank();

        int256 l1Bias = -100;

        _updateL1Bias(CHAIN_ID, l1Bias);

        (uint256 startBlock,, uint256 genesisBlock, uint256 duration, uint256 freezeDuration,,,) =
            lagrangeCommittee.committeeParams(CHAIN_ID);

        // Originally
        {
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, uint256(int256(genesisBlock - 1) - l1Bias)), 0);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, uint256(int256(genesisBlock) - l1Bias)), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, uint256(int256(startBlock) - l1Bias)), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, uint256(int256(startBlock + duration) - l1Bias)), 1);
            assertEq(
                lagrangeCommittee.getEpochNumber(CHAIN_ID, uint256(int256(startBlock + duration * 2 - 1) - l1Bias)), 1
            );
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, uint256(int256(startBlock + duration * 2) - l1Bias)), 2);
            assertEq(
                lagrangeCommittee.getEpochNumber(CHAIN_ID, uint256(int256(startBlock + duration * 3 - 1) - l1Bias)), 2
            );
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, uint256(int256(startBlock + duration * 3) - l1Bias)), 3);

            (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                lagrangeCommittee.getEpochInterval(CHAIN_ID, 10);
            assertEq(_startBlock, startBlock + duration * 10);
            assertEq(_freezeBlock, startBlock + duration * 11 - freezeDuration);
            assertEq(_endBlock, startBlock + duration * 11);
        }

        // Update failed before lock period
        vm.roll(startBlock + duration - freezeDuration);

        vm.expectRevert("In testnet mode, you should use updateWithL1BlockNumber.");
        lagrangeCommittee.update(CHAIN_ID, 1);

        vm.expectRevert("Block number is prior to committee freeze window.");
        LagrangeCommitteeTestnet(address(lagrangeCommittee)).updateWithL1BlockNumber(CHAIN_ID, 1, block.number + 99);

        // Update in some block
        uint256 updatedBlock1 = startBlock + duration - freezeDuration + 4;
        uint256 updatedL1Block1 = updatedBlock1 + 99;
        vm.roll(updatedBlock1);
        console.log("updatedL1Block1", updatedL1Block1);
        LagrangeCommitteeTestnet(address(lagrangeCommittee)).updateWithL1BlockNumber(CHAIN_ID, 1, updatedL1Block1);

        uint256 updatedBlock2 = updatedBlock1 + duration;
        uint256 updatedL1Block2 = updatedBlock2 + 97;
        vm.roll(updatedBlock2);
        LagrangeCommitteeTestnet(address(lagrangeCommittee)).updateWithL1BlockNumber(CHAIN_ID, 2, updatedL1Block2);

        uint256 updatedBlock3 = updatedBlock1 + duration * 100;
        uint256 updatedL1Block3 = updatedBlock3 + 90;
        vm.roll(updatedBlock3);
        LagrangeCommitteeTestnet(address(lagrangeCommittee)).updateWithL1BlockNumber(CHAIN_ID, 3, updatedL1Block3);

        // Test getEpochInterval
        {
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, uint256(int256(genesisBlock - 1) - l1Bias)), 0);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, uint256(int256(genesisBlock) - l1Bias)), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, uint256(int256(startBlock) - l1Bias)), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, updatedL1Block1), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, updatedL1Block2 - 1), 1);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, updatedL1Block2), 2);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, updatedL1Block3 - 1), 2);
            assertEq(lagrangeCommittee.getEpochNumber(CHAIN_ID, updatedL1Block3), 3);

            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 1);
                assertEq(_startBlock, updatedBlock1);
                assertEq(_freezeBlock, updatedBlock2 - freezeDuration);
                assertEq(_endBlock, updatedBlock2);
            }
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 2);
                assertEq(_startBlock, updatedBlock2);
                assertEq(_freezeBlock, updatedBlock3 - freezeDuration);
                assertEq(_endBlock, updatedBlock3);
            }
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 3);
                assertEq(_startBlock, updatedBlock3);
                assertEq(_freezeBlock, updatedBlock3 + duration - freezeDuration);
                assertEq(_endBlock, updatedBlock3 + duration);
            }
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 10);
                assertEq(_startBlock, updatedBlock3 + duration * 7);
                assertEq(_freezeBlock, updatedBlock3 + duration * 8 - freezeDuration);
                assertEq(_endBlock, updatedBlock3 + duration * 8);
            }
        }

        uint256 newEpochPeriod = 30;

        _updateEpochPeriod(CHAIN_ID, newEpochPeriod);

        // Test getEpochInterval
        {
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 2);
                assertEq(_startBlock, updatedBlock2);
                assertEq(_freezeBlock, updatedBlock3 - freezeDuration);
                assertEq(_endBlock, updatedBlock3);
            }
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 3);
                assertEq(_startBlock, updatedBlock3);
                assertEq(_freezeBlock, updatedBlock3 + newEpochPeriod - freezeDuration);
                assertEq(_endBlock, updatedBlock3 + newEpochPeriod);
            }
            {
                (uint256 _startBlock, uint256 _freezeBlock, uint256 _endBlock) =
                    lagrangeCommittee.getEpochInterval(CHAIN_ID, 10);
                assertEq(_startBlock, updatedBlock3 + newEpochPeriod * 7);
                assertEq(_freezeBlock, updatedBlock3 + newEpochPeriod * 8 - freezeDuration);
                assertEq(_endBlock, updatedBlock3 + newEpochPeriod * 8);
            }
        }
    }

    function _updateEpochPeriod(uint32 chainID, uint256 newEpochPeriod) internal {
        (
            , // startBlock
            int256 l1Bias,
            uint256 genesisBlock,
            ,
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

    function _updateL1Bias(uint32 chainID, int256 newL1Bias) internal {
        (
            , // startBlock
            ,
            uint256 genesisBlock,
            uint256 newEpochPeriod,
            uint256 freezeDuration,
            uint8 quorumNumber,
            uint96 minWeight,
            uint96 maxWeight
        ) = lagrangeCommittee.committeeParams(chainID);
        vm.prank(lagrangeCommittee.owner());
        lagrangeCommittee.updateChain(
            chainID, newL1Bias, genesisBlock, newEpochPeriod, freezeDuration, quorumNumber, minWeight, maxWeight
        );
    }
}
