pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {LagrangeCommittee} from "../contracts/protocol/LagrangeCommittee.sol";
import {LagrangeService} from "../contracts/protocol/LagrangeService.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

contract Deploy is Script, Test {
    string public deployDataPath = string(bytes("script/output/deployed_lgr.json"));

    // Lagrange Contracts
    ProxyAdmin public proxyAdmin;
    LagrangeCommittee public lagrangeCommittee;
    LagrangeCommittee public lagrangeCommitteeImp;
    LagrangeService public lagrangeService;
    LagrangeService public lagrangeServiceImp;

    function run() public {
        string memory deployData = vm.readFile(deployDataPath);

        // deploy proxy admin for ability to upgrade proxy contracts
        proxyAdmin = ProxyAdmin(stdJson.readAddress(deployData, ".addresses.proxyAdmin"));
        lagrangeService = LagrangeService(stdJson.readAddress(deployData, ".addresses.lagrangeService"));
        lagrangeCommittee = LagrangeCommittee(stdJson.readAddress(deployData, ".addresses.lagrangeCommittee"));

        vm.startBroadcast(lagrangeService.owner());

        // deploy implementation contracts
        lagrangeCommitteeImp = new LagrangeCommittee(lagrangeService, lagrangeCommittee.voteWeigher());
        lagrangeServiceImp = new LagrangeService(
            lagrangeCommittee,
            lagrangeService.stakeManager(),
            address(lagrangeService.avsDirectory()),
            lagrangeService.voteWeigher()
        );

        // upgrade proxy contracts
        {
            proxyAdmin.upgrade(
                TransparentUpgradeableProxy(payable(address(lagrangeCommittee))), address(lagrangeCommitteeImp)
            );
            proxyAdmin.upgrade(
                TransparentUpgradeableProxy(payable(address(lagrangeService))), address(lagrangeServiceImp)
            );
        }

        uint32 CHAIN_ID_BASE = lagrangeCommittee.chainIDs(0); // 8453
        uint32 CHAIN_ID_OP = lagrangeCommittee.chainIDs(1); // 10
        uint32 CHAIN_ID_ARB = lagrangeCommittee.chainIDs(2); // 42161

        // set first epoch period
        {
            // set first epoch period for CHAIN_ID_BASE
            lagrangeCommittee.setFirstEpochPeriod(CHAIN_ID_BASE);

            // set first epoch period for CHAIN_ID_OP
            lagrangeCommittee.setFirstEpochPeriod(CHAIN_ID_OP);

            // set first epoch period for CHAIN_ID_ARB
            lagrangeCommittee.setFirstEpochPeriod(CHAIN_ID_ARB);
        }

        vm.stopBroadcast();

        // update epoch period
        {
            // Current epoch period is 1500 blocks = about 5 hours
            // New epcoh period is 50000 blocks = about 1 week
            uint256 newEpochPeriod = 50000;
            _updateEpochPeriod(CHAIN_ID_BASE, newEpochPeriod);
            _updateEpochPeriod(CHAIN_ID_OP, newEpochPeriod);
            _updateEpochPeriod(CHAIN_ID_ARB, newEpochPeriod);
        }
    }

    function _updateEpochPeriod(uint32 chainId, uint256 newEpochPeriod) private {
        (
            , // uint256 startBlock,
            int256 l1Bias,
            uint256 genesisBlock,
            , //uint256 epochPeriod,
            uint256 freezeDuration,
            uint8 quorumNumber,
            uint96 minWeight,
            uint96 maxWeight
        ) = lagrangeCommittee.committeeParams(chainId);

        vm.startBroadcast(lagrangeService.owner());

        lagrangeCommittee.updateChain(
            chainId, l1Bias, genesisBlock, newEpochPeriod, freezeDuration, quorumNumber, minWeight, maxWeight
        );

        vm.stopBroadcast();

        {
            (,,, uint256 _newEpochPeriod,,,,) = lagrangeCommittee.committeeParams(chainId);

            require(_newEpochPeriod == newEpochPeriod, "epochPeriod is incorrect");
        }
    }
}
