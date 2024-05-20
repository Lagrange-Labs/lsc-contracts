// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {LagrangeCommittee} from "../../contracts/protocol/LagrangeCommittee.sol";
import {LagrangeService} from "../../contracts/protocol/LagrangeService.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// note: this is only for sepolia testnet
contract RotateAndRevert is Script, Test {
    string public deployDataPath = string(bytes("script/output/deployed_main.json"));

    // Lagrange Contracts
    ProxyAdmin public proxyAdmin;
    LagrangeCommittee public lagrangeCommittee;
    LagrangeService public lagrangeService;

    function run() public {
        string memory deployData = vm.readFile(deployDataPath);

        lagrangeService = LagrangeService(stdJson.readAddress(deployData, ".addresses.lagrangeService"));
        lagrangeCommittee = LagrangeCommittee(stdJson.readAddress(deployData, ".addresses.lagrangeCommittee"));

        address[] memory operators = new address[](5);
        {
            uint32 _chainID = lagrangeCommittee.chainIDs(0);
            for (uint256 i; i < 5; i++) {
                operators[i] = lagrangeCommittee.committeeAddrs(_chainID, i);
                console.log(operators[i]);
            }
        }

        uint256 _blockNumber = block.number;

        console.log("block.number", _blockNumber);

        address owner = lagrangeService.owner();

        // 1. register chain
        uint32 chainID = 1234;
        uint256 epochPeriod = 1000;
        uint256 newEpochPeriod = 400;
        {
            vm.prank(owner);
            lagrangeCommittee.registerChain(
                chainID,
                1234000, // genesisBlock, 
                epochPeriod,
                100, // freezeDuration, 
                0, // quorumNumber, 
                5, // minWeight, 
                50 // maxWeight
            );
        }

        // 2. subscribe
        {
            for (uint256 i; i < 5; i++) {
                assertEq(lagrangeCommittee.subscribedChains(chainID, operators[i]), false);
                
                vm.prank(operators[i]);
                lagrangeService.subscribe(chainID);

                assertEq(lagrangeCommittee.subscribedChains(chainID, operators[i]), true);
            }
        }

        // 3. update
        {
            vm.roll(_blockNumber + epochPeriod - 100);
            vm.prank(owner);
            vm.expectRevert("Block number is prior to committee freeze window.");
            lagrangeCommittee.update(chainID, 1);
            
            vm.roll(_blockNumber + epochPeriod - 1);
            vm.prank(owner);
            lagrangeCommittee.update(chainID, 1);
        }

        // 4. Update Epoch Period
        {
            vm.prank(owner);
            lagrangeCommittee.updateChain(
                chainID,
                0, // l1Bias,
                1234000, // genesisBlock, 
                newEpochPeriod,
                100, // freezeDuration, 
                0, // quorumNumber, 
                5, // minWeight, 
                50 // maxWeight
            );
        }

        // 5. update
        {
            vm.roll(_blockNumber + epochPeriod + newEpochPeriod - 100);
            vm.prank(owner);
            vm.expectRevert("Block number is prior to committee freeze window.");
            lagrangeCommittee.update(chainID, 2);
            
            vm.roll(_blockNumber + epochPeriod + newEpochPeriod - 1);
            vm.prank(owner);
            lagrangeCommittee.update(chainID, 2);
        }

        // 6. 1 operator unsubscribe
        {
            vm.prank(operators[0]);
            vm.expectRevert("The dedicated chain is locked.");
            lagrangeService.unsubscribe(chainID);

            vm.roll(_blockNumber + epochPeriod + newEpochPeriod);
            vm.prank(operators[0]);
            lagrangeService.unsubscribe(chainID);
            
            assertEq(lagrangeCommittee.subscribedChains(chainID, operators[0]), false);
        }

        // 7. 1 operator is unsubscribed by admin
        {
            address[] memory _operatorsToUnsubscribe = new address[](1);
            _operatorsToUnsubscribe[0] = operators[1];
            vm.prank(owner);
            lagrangeService.unsubscribeByAdmin(_operatorsToUnsubscribe, chainID);

            assertEq(lagrangeCommittee.subscribedChains(chainID, operators[1]), false);
        }

        // 8. revert epoch
        {
            uint32 leafCount;
            (,,leafCount) = lagrangeCommittee.committees(chainID, 1);
            assertEq(leafCount, 5);
            (,,leafCount) = lagrangeCommittee.committees(chainID, 2);
            assertEq(leafCount, 5);

            vm.startPrank(owner);
            lagrangeCommittee.revertEpoch(chainID, 2);
            lagrangeCommittee.revertEpoch(chainID, 1);
            vm.stopPrank();

            (,,leafCount) = lagrangeCommittee.committees(chainID, 1);
            assertEq(leafCount, 0);
            (,,leafCount) = lagrangeCommittee.committees(chainID, 2);
            assertEq(leafCount, 0);
        }

        // 9. check epoch number
        {
            console.log("block number | epoch number");
            uint256 st = _blockNumber - epochPeriod - newEpochPeriod;
            uint256 en = _blockNumber + epochPeriod * 2 + newEpochPeriod * 2;
            uint256 m = 37;
            for (uint256 le = 0; le <= m; le++) {
                uint256 ri = m - le;
                uint256 _checkPoint = (st * ri + en * le) / m;
                vm.roll(_checkPoint);
                uint256 _epochNumber = lagrangeCommittee.getEpochNumber(chainID, _checkPoint);
                console.log(_checkPoint, " | ", _epochNumber);
            }
        }
    }
}
