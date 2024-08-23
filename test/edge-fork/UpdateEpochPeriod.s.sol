// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

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
        uint256 epochNumber;
    }

    function run() public {
        string memory deployData = vm.readFile(deployDataPath);
        proxyAdmin = ProxyAdmin(stdJson.readAddress(deployData, ".addresses.proxyAdmin"));
        lagrangeService = LagrangeService(stdJson.readAddress(deployData, ".addresses.lagrangeService"));
        lagrangeCommittee = LagrangeCommittee(stdJson.readAddress(deployData, ".addresses.lagrangeCommittee"));

        uint32 CHAIN_ID_BASE = lagrangeCommittee.chainIDs(0);
        uint32 CHAIN_ID_OP = lagrangeCommittee.chainIDs(1);
        uint32 CHAIN_ID_ARB = lagrangeCommittee.chainIDs(2);

        address owner = lagrangeService.owner();
        uint256 _blockNumber = block.number;

        // Make test cases
        TestCase[] memory testCases = new TestCase[](15);
        {
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
            }
            {
                (uint256 startBlock,,,,,,,) = lagrangeCommittee.committeeParams(CHAIN_ID_OP);
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
            }
            {
                (uint256 startBlock,,,,,,,) = lagrangeCommittee.committeeParams(CHAIN_ID_ARB);
                testCases[10].chainID = CHAIN_ID_ARB;
                testCases[10].blockNumber = startBlock;
                testCases[11].chainID = CHAIN_ID_ARB;
                testCases[11].blockNumber = startBlock + 10000;
                testCases[12].chainID = CHAIN_ID_ARB;
                testCases[12].blockNumber = _blockNumber - 10000;
                testCases[13].chainID = CHAIN_ID_ARB;
                testCases[13].blockNumber = _blockNumber + 10000;
                testCases[14].chainID = CHAIN_ID_ARB;
                testCases[14].blockNumber = _blockNumber + 20000;
            }
            for (uint256 i; i < testCases.length; i++) {
                testCases[i].epochNumber =
                    lagrangeCommittee.getEpochNumber(testCases[i].chainID, testCases[i].blockNumber);
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
        vm.stopPrank();

        // check getEpochNumber through testcases
        {
            for (uint256 i; i < testCases.length; i++) {
                uint256 epochNumber = lagrangeCommittee.getEpochNumber(testCases[i].chainID, testCases[i].blockNumber);
                if (testCases[i].epochNumber != epochNumber) {
                    (uint256 startBlock,,, uint256 duration,,,,) =
                        lagrangeCommittee.committeeParams(testCases[i].chainID);
                    uint256 latestEpoch = lagrangeCommittee.updatedEpoch(testCases[i].chainID);
                    (bytes32 root, uint224 updatedBlock, uint32 leafCount) =
                        lagrangeCommittee.committees(testCases[i].chainID, latestEpoch);
                    if (updatedBlock <= testCases[i].blockNumber) {
                        uint256 expectedBlockNumber = (testCases[i].blockNumber - updatedBlock) / duration + latestEpoch;
                        require(epochNumber == expectedBlockNumber);
                    }
                }
            }
        }

        uint256 _newBlockNumber = _blockNumber + 5000;

        vm.roll(_newBlockNumber);
        // update epoch period
        {
            _updateEpochPeriod(CHAIN_ID_BASE, 3000);
            _updateEpochPeriod(CHAIN_ID_OP, 3000);
            _updateEpochPeriod(CHAIN_ID_ARB, 3000);
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
