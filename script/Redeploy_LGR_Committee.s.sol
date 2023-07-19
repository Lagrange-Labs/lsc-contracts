pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {LagrangeCommittee} from "src/protocol/LagrangeCommittee.sol";
import {LagrangeService} from "src/protocol/LagrangeService.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

contract Deploy is Script, Test {
    string public deployDataPath =
        string(bytes("script/output/deployed_goerli.json"));

    // Lagrange Contracts
    ProxyAdmin public proxyAdmin;
    LagrangeCommittee public lagrangeCommittee;
    LagrangeCommittee public lagrangeCommitteeImp;
    LagrangeService public lagrangeService;

    function run() public {
        string memory deployData = vm.readFile(deployDataPath);

        vm.startBroadcast(msg.sender);

        // deploy proxy admin for ability to upgrade proxy contracts
        proxyAdmin = ProxyAdmin(stdJson.readAddress(deployData, ".lagrange.addresses.proxyAdmin"));
        lagrangeService = LagrangeService(stdJson.readAddress(deployData, ".lagrange.addresses.lagrangeService"));
        lagrangeCommittee = LagrangeCommittee(stdJson.readAddress(deployData, ".lagrange.addresses.lagrangeCommittee"));

        // deploy implementation contracts
        lagrangeCommitteeImp = new LagrangeCommittee(lagrangeService);

        // upgrade proxy contracts
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))),
            address(lagrangeCommitteeImp)
        );

        vm.stopBroadcast();
    }
}
