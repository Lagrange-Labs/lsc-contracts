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
    LagrangeCommittee public lagrangeCommittee;

    function run() public {
        string memory deployData = vm.readFile(deployDataPath);

        // deploy proxy admin for ability to upgrade proxy contracts
        lagrangeCommittee = LagrangeCommittee(stdJson.readAddress(deployData, ".addresses.lagrangeCommittee"));

        vm.startBroadcast(lagrangeCommittee.owner());

        uint32 CHAIN_ID_BASE = lagrangeCommittee.chainIDs(0); // 8453
        uint32 CHAIN_ID_OP = lagrangeCommittee.chainIDs(1); // 10
        uint32 CHAIN_ID_ARB = lagrangeCommittee.chainIDs(2); // 42161

        // update the epoch period for each chain
        {
            // set first epoch period for CHAIN_ID_BASE
            lagrangeCommittee.updateChain(CHAIN_ID_OP, 0, 19620610, 50000, 7000, 0, 1000000000, 10000000000000);
            // set first epoch period for CHAIN_ID_OP
            lagrangeCommittee.updateChain(CHAIN_ID_BASE, 0, 19620619, 50000, 7000, 0, 1000000000, 10000000000000);
            // set first epoch period for CHAIN_ID_ARB
            lagrangeCommittee.updateChain(CHAIN_ID_ARB, 0, 19920587, 50000, 7000, 0, 1000000000, 10000000000000);
        }

        vm.stopBroadcast();
    }
}
