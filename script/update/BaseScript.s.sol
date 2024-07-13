pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {LagrangeCommittee} from "../../contracts/protocol/LagrangeCommittee.sol";
import {LagrangeService} from "../../contracts/protocol/LagrangeService.sol";
import {VoteWeigher} from "../../contracts/protocol/VoteWeigher.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

abstract contract BaseScript is Script, Test {
    // It reads from `deployed_main.json` as default. You can overset this path
    string internal deployDataPath;
    bool internal manualPath;

    ProxyAdmin internal proxyAdmin;
    LagrangeCommittee internal lagrangeCommittee;
    LagrangeService internal lagrangeService;
    VoteWeigher internal voteWeigher;

    function _readContracts() internal {
        if (!manualPath) {
            if (block.chainid == 1) {
                deployDataPath = string(bytes("script/output/deployed_main.json"));
            } else if (block.chainid == 11155111) {
                deployDataPath = string(bytes("script/output/deployed_sepolia.json"));
            } else if (block.chainid == 17000) {
                deployDataPath = string(bytes("script/output/deployed_holesky.json"));
            } else {
                deployDataPath = string(bytes("script/output/deployed_lgr.json"));
            }
        }
        string memory deployData = vm.readFile(deployDataPath);

        // deploy proxy admin for ability to upgrade proxy contracts
        proxyAdmin = ProxyAdmin(stdJson.readAddress(deployData, ".addresses.proxyAdmin"));
        lagrangeService = LagrangeService(stdJson.readAddress(deployData, ".addresses.lagrangeService"));
        lagrangeCommittee = LagrangeCommittee(stdJson.readAddress(deployData, ".addresses.lagrangeCommittee"));
        voteWeigher = VoteWeigher(stdJson.readAddress(deployData, ".addresses.voteWeigher"));
    }

    function _redeployService() internal {
        vm.startBroadcast(lagrangeService.owner());

        LagrangeService lagrangeServiceImp = new LagrangeService(
            lagrangeCommittee,
            lagrangeService.stakeManager(),
            address(lagrangeService.avsDirectory()),
            lagrangeService.voteWeigher()
        );
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(address(lagrangeService))), address(lagrangeServiceImp));

        vm.stopBroadcast();
    }

    function _redeployCommittee() internal {
        vm.startBroadcast(lagrangeCommittee.owner());

        LagrangeCommittee lagrangeCommitteeImp = new LagrangeCommittee(lagrangeService, lagrangeCommittee.voteWeigher());
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))), address(lagrangeCommitteeImp)
        );

        vm.stopBroadcast();
    }
}
