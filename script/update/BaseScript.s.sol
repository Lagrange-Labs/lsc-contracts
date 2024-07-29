pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {LagrangeCommittee} from "../../contracts/protocol/LagrangeCommittee.sol";
import {LagrangeService} from "../../contracts/protocol/LagrangeService.sol";
import {LagrangeCommitteeTestnet} from "../../contracts/protocol/testnet/LagrangeCommitteeTestnet.sol";
import {LagrangeServiceTestnet} from "../../contracts/protocol/testnet/LagrangeServiceTestnet.sol";
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

        address _lagrangeServiceImp;
        if (block.chainid == 17000 || block.chainid == 11155111) {
            LagrangeServiceTestnet lagrangeServiceImp = new LagrangeServiceTestnet(
                lagrangeCommittee,
                lagrangeService.stakeManager(),
                address(lagrangeService.avsDirectory()),
                lagrangeService.voteWeigher()
            );
            _lagrangeServiceImp = address(lagrangeServiceImp);
        } else {
            LagrangeService lagrangeServiceImp = new LagrangeService(
                lagrangeCommittee,
                lagrangeService.stakeManager(),
                address(lagrangeService.avsDirectory()),
                lagrangeService.voteWeigher()
            );
            _lagrangeServiceImp = address(lagrangeServiceImp);
        }
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(address(lagrangeService))), _lagrangeServiceImp);

        vm.stopBroadcast();
    }

    function _redeployCommittee() internal {
        vm.startBroadcast(lagrangeCommittee.owner());

        address _lagrangeCommitteeImp;
        if (block.chainid == 17000) {
            LagrangeCommitteeTestnet lagrangeCommitteeImp =
                new LagrangeCommitteeTestnet(lagrangeService, lagrangeCommittee.voteWeigher());
            _lagrangeCommitteeImp = address(lagrangeCommitteeImp);
        } else {
            LagrangeCommittee lagrangeCommitteeImp =
                new LagrangeCommittee(lagrangeService, lagrangeCommittee.voteWeigher());
            _lagrangeCommitteeImp = address(lagrangeCommitteeImp);
        }
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(address(lagrangeCommittee))), _lagrangeCommitteeImp);

        vm.stopBroadcast();
    }
}
