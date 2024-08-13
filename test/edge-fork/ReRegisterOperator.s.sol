// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {LagrangeCommittee} from "../../contracts/protocol/LagrangeCommittee.sol";
import {LagrangeService} from "../../contracts/protocol/LagrangeService.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ReRegisterOperator is Script {
    string public deployDataPath = string(bytes("script/output/deployed_main.json"));

    // Lagrange Contracts
    ProxyAdmin public proxyAdmin;
    LagrangeCommittee public lagrangeCommittee;
    LagrangeCommittee public lagrangeCommitteeImp;
    LagrangeService public lagrangeService;
    LagrangeService public lagrangeServiceImp;

    function run() public {
        string memory deployData = vm.readFile(deployDataPath);

        vm.startPrank(0xB9D7C1Ced67302967ce9553057589632bD99a998);
        // deploy proxy admin for ability to upgrade proxy contracts
        proxyAdmin = ProxyAdmin(stdJson.readAddress(deployData, ".addresses.proxyAdmin"));
        lagrangeService = LagrangeService(stdJson.readAddress(deployData, ".addresses.lagrangeService"));
        lagrangeCommittee = LagrangeCommittee(stdJson.readAddress(deployData, ".addresses.lagrangeCommittee"));
        // deploy implementation contracts
        lagrangeCommitteeImp = new LagrangeCommittee(lagrangeService, lagrangeCommittee.voteWeigher());
        lagrangeServiceImp =
        new LagrangeService(lagrangeCommittee, lagrangeService.stakeManager(), address(lagrangeService.avsDirectory()), lagrangeService.voteWeigher());

        // upgrade proxy contracts
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))), address(lagrangeCommitteeImp)
        );
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(address(lagrangeService))), address(lagrangeServiceImp));

        vm.stopPrank();

        address operator = 0x5ACCC90436492F24E6aF278569691e2c942A676d;
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0][0] = 1;
        blsPubKeys[0][1] = 2;

        vm.prank(address(lagrangeService));
        lagrangeCommittee.addOperator(operator, operator, blsPubKeys);
    }
}
