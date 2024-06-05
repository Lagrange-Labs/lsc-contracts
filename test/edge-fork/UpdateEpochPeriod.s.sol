// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {LagrangeCommittee} from "../../contracts/protocol/LagrangeCommittee.sol";
import {LagrangeService} from "../../contracts/protocol/LagrangeService.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpdateEpochPeriod is Script {
    string public deployDataPath = string(bytes("script/output/deployed_main.json"));

    // Lagrange Contracts
    ProxyAdmin public proxyAdmin;
    LagrangeCommittee public lagrangeCommittee;
    LagrangeCommittee public lagrangeCommitteeImp;
    LagrangeService public lagrangeService;
    LagrangeService public lagrangeServiceImp;

    struct TestCase {
        uint32 chainID;
        uint256 blockNumber;
        uint256 epochPeriod;
    }

    function run() public {
        string memory deployData = vm.readFile(deployDataPath);
        proxyAdmin = ProxyAdmin(stdJson.readAddress(deployData, ".addresses.proxyAdmin"));
        lagrangeService = LagrangeService(stdJson.readAddress(deployData, ".addresses.lagrangeService"));
        lagrangeCommittee = LagrangeCommittee(stdJson.readAddress(deployData, ".addresses.lagrangeCommittee"));

        uint32 CHAIN_ID_BASE = lagrangeCommittee.chainIDs(0);
        uint32 CHAIN_ID_OP = lagrangeCommittee.chainIDs(1);

        address owner = lagrangeService.owner();
        uint256 _blockNumber = block.number;

        // Make test cases
        TestCase[] memory testCases = new TestCase[](10);
        {
            (uint256 startBlock,,,,,,,) = lagrangeCommittee.committeeParams(CHAIN_ID_BASE);
            testCases[0].chainID = CHAIN_ID_BASE;
            testCases[0].blockNumber = startBlock;
            testCases[1].chainID = CHAIN_ID_BASE;
            testCases[1].blockNumber = startBlock + 10000;
            testCases[2].chainID = CHAIN_ID_BASE;
            testCases[2].blockNumber = _blockNumber - 10000;
            testCases[3].chainID = CHAIN_ID_BASE;
            testCases[3].blockNumber = _blockNumber + 10000;
            testCases[4].chainID = CHAIN_ID_BASE;
            testCases[4].blockNumber = _blockNumber + 20000;
            testCases[5].chainID = CHAIN_ID_OP;
            testCases[5].blockNumber = startBlock;
            testCases[6].chainID = CHAIN_ID_OP;
            testCases[6].blockNumber = startBlock + 10000;
            testCases[7].chainID = CHAIN_ID_OP;
            testCases[7].blockNumber = _blockNumber - 10000;
            testCases[8].chainID = CHAIN_ID_OP;
            testCases[8].blockNumber = _blockNumber + 10000;
            testCases[9].chainID = CHAIN_ID_OP;
            testCases[9].blockNumber = _blockNumber + 20000;
            for (uint256 i; i < testCases.length; i++) {
                testCases[i].epochPeriod = lagrangeCommittee.getEpochNumber(testCases[i].chainID, testCases[i].blockNumber);
            }
        }

        vm.startPrank(owner);
        {
            // deploy implementation contracts
            lagrangeCommitteeImp = new LagrangeCommittee(lagrangeService, lagrangeCommittee.voteWeigher());
            // upgrade proxy contracts
            proxyAdmin.upgrade(
                TransparentUpgradeableProxy(payable(address(lagrangeCommittee))), address(lagrangeCommitteeImp)
            );
        }

        // set first epoch period for CHAIN_ID_BASE
        {
            (uint256 startBlock,,, uint256 duration,,,,) = lagrangeCommittee.committeeParams(CHAIN_ID_BASE);
            (uint256[] memory _flagBlocks, uint256[] memory _flagEpoches, uint256[] memory _durations) =
                _getAllEpochPeriods(CHAIN_ID_BASE);

            require(_flagBlocks.length == 0, "Expected zero length originally");
            lagrangeCommittee.setFirstEpochPeriod(CHAIN_ID_BASE);
            (_flagBlocks, _flagEpoches, _durations) = _getAllEpochPeriods(CHAIN_ID_BASE);
            require(_flagBlocks.length == 1, "First epoch period is not written.");
            require(_flagBlocks[0] == startBlock, "First epoch period / flagBlock is incorrect.");
            require(_flagEpoches[0] == 0, "First epoch period / flagEpoch is incorrect.");
            require(_durations[0] == duration, "First epoch period / epochPeriod is incorrect.");
        }

        // set first epoch period for CHAIN_ID_OP
        {
            (uint256 startBlock,,, uint256 duration,,,,) = lagrangeCommittee.committeeParams(CHAIN_ID_OP);
            (uint256[] memory _flagBlocks, uint256[] memory _flagEpoches, uint256[] memory _durations) =
                _getAllEpochPeriods(CHAIN_ID_OP);

            require(_flagBlocks.length == 0, "Expected zero length originally");
            lagrangeCommittee.setFirstEpochPeriod(CHAIN_ID_OP);
            (_flagBlocks, _flagEpoches, _durations) = _getAllEpochPeriods(CHAIN_ID_OP);
            require(_flagBlocks.length == 1, "First epoch period is not written.");
            require(_flagBlocks[0] == startBlock, "First epoch period / flagBlock is incorrect.");
            require(_flagEpoches[0] == 0, "First epoch period / flagEpoch is incorrect.");
            require(_durations[0] == duration, "First epoch period / epochPeriod is incorrect.");
        }
        vm.stopPrank();

        // check getEpochNumber through testcases
        {
            for (uint256 i; i < testCases.length; i++) {
                require(testCases[i].epochPeriod == lagrangeCommittee.getEpochNumber(testCases[i].chainID, testCases[i].blockNumber), "Failed in test case");
            }
        }

        uint256 _newBlockNumber = _blockNumber + 5000;

        vm.roll(_newBlockNumber);
        // update epoch period for CHAIN_ID_BASE
        {
            _updateEpochPeriod(CHAIN_ID_BASE, 3000);
            (uint256[] memory _flagBlocks, uint256[] memory _flagEpoches, uint256[] memory _durations) 
                = _getAllEpochPeriods(CHAIN_ID_BASE);
            uint256 epochNumber = lagrangeCommittee.getEpochNumber(CHAIN_ID_BASE, _newBlockNumber - 1) + 1;
            require(_flagBlocks.length == 2, "Second epoch period is not written.");
            require(_flagBlocks[1] >= _newBlockNumber, "Second epoch period / flagBlock is incorrect.");
            require(_flagEpoches[1] == epochNumber, "Second epoch period / flagEpoch is incorrect.");
            require(_durations[1] == 3000, "Second epoch period / epochPeriod is incorrect.");
        }

        // update epoch period for CHAIN_ID_OP
        {
            _updateEpochPeriod(CHAIN_ID_OP, 3000);
            (uint256[] memory _flagBlocks, uint256[] memory _flagEpoches, uint256[] memory _durations) 
                = _getAllEpochPeriods(CHAIN_ID_BASE);
            uint256 epochNumber = lagrangeCommittee.getEpochNumber(CHAIN_ID_BASE, _newBlockNumber - 1) + 1;
            require(_flagBlocks.length == 2, "Second epoch period is not written.");
            require(_flagBlocks[1] >= _newBlockNumber, "Second epoch period / flagBlock is incorrect.");
            require(_flagEpoches[1] == epochNumber, "Second epoch period / flagEpoch is incorrect.");
            require(_durations[1] == 3000, "Second epoch period / epochPeriod is incorrect.");
        }
    }

    function _getAllEpochPeriods(uint32 chainID)
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
