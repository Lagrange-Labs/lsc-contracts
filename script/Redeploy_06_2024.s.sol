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

        // dead code, only keeping for trach purpose
        // uint32 CHAIN_ID_BASE = lagrangeCommittee.chainIDs(0); // 8453
        // uint32 CHAIN_ID_OP = lagrangeCommittee.chainIDs(1); // 10
        // uint32 CHAIN_ID_ARB = lagrangeCommittee.chainIDs(2); // 42161

        // // set first epoch period
        // {
        //     // set first epoch period for CHAIN_ID_BASE
        //     lagrangeCommittee.setFirstEpochPeriod(CHAIN_ID_BASE);

        //     // set first epoch period for CHAIN_ID_OP
        //     lagrangeCommittee.setFirstEpochPeriod(CHAIN_ID_OP);

        //     // set first epoch period for CHAIN_ID_ARB
        //     lagrangeCommittee.setFirstEpochPeriod(CHAIN_ID_ARB);
        // }

        vm.stopBroadcast();
    }
}
