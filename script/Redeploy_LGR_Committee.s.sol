pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IStrategyManager} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";

import {LagrangeCommittee} from "src/protocol/LagrangeCommittee.sol";
import {LagrangeService} from "src/protocol/LagrangeService.sol";
import {LagrangeServiceManager} from "src/protocol/LagrangeServiceManager.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

contract Deploy is Script, Test {
    string public deployDataPath =
        string(bytes("script/output/deployed_goerli.json"));
    string public mockDataPath =
        string(bytes("script/output/deployed_mock.json"));

    // Lagrange Contracts
    ProxyAdmin public proxyAdmin;
    LagrangeCommittee public lagrangeCommittee;
    LagrangeCommittee public lagrangeCommitteeImp;
    LagrangeService public lagrangeService;
    LagrangeServiceManager public lagrangeServiceManager;

    function run() public {
        string memory deployData = vm.readFile(deployDataPath);
        string memory mockData = vm.readFile(mockDataPath);

        address strategyManagerAddress = stdJson.readAddress(
            mockData,
            ".addresses.strategyManager"
        );

        vm.startBroadcast(msg.sender);

        // deploy proxy admin for ability to upgrade proxy contracts
        proxyAdmin = ProxyAdmin(
            stdJson.readAddress(deployData, ".lagrange.addresses.proxyAdmin")
        );
        lagrangeService = LagrangeService(
            stdJson.readAddress(
                deployData,
                ".lagrange.addresses.lagrangeService"
            )
        );
        lagrangeCommittee = LagrangeCommittee(
            stdJson.readAddress(
                deployData,
                ".lagrange.addresses.lagrangeCommittee"
            )
        );
        lagrangeServiceManager = LagrangeServiceManager(
            stdJson.readAddress(
                deployData,
                ".lagrange.addresses.lagrangeServiceManager"
            )
        );
        // deploy implementation contracts
        lagrangeCommitteeImp = new LagrangeCommittee(
            lagrangeService,
            lagrangeServiceManager,
            IStrategyManager(strategyManagerAddress)
        );

        // upgrade proxy contracts
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))),
            address(lagrangeCommitteeImp)
        );

        vm.stopBroadcast();
    }
}
