pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {LagrangeCommittee} from "../../contracts/protocol/LagrangeCommittee.sol";
import {LagrangeService} from "../../contracts/protocol/LagrangeService.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

contract RegisterChain is Script, Test {
    string public deployDataPath = string(bytes("script/output/deployed_main.json"));

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
        
        address owner = lagrangeCommittee.owner();

        vm.startBroadcast(owner);

        // need to put values manually here
        uint32 chainId = 42161;
        uint256 epochPeriod = 1500;
        uint256 freezeDuration = 150;
        uint256 genesisBlock = 19920587;
        uint96 maxWeight = 10000000000000;
        uint96 minWeight = 1000000000;
        uint8 quorumNumber = 0;

        // Check if it is not registered yet
        {
            (,,,,,,, uint96 _oldMaxWeight) = lagrangeCommittee.committeeParams(chainId);
            assertEq(_oldMaxWeight, 0);
        }

        // Register chain
        lagrangeCommittee.registerChain(
            chainId,
            genesisBlock,
            epochPeriod,
            freezeDuration,
            quorumNumber,
            minWeight,
            maxWeight
        );


        // Check if it is registered correctly
        {
            (,,,,,,, uint96 _newMaxWeight) = lagrangeCommittee.committeeParams(chainId);
            assertEq(_newMaxWeight, maxWeight);
        }

        vm.stopBroadcast();
    }
}
