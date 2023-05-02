pragma solidity =0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {Slasher} from "eigenlayer-contracts/core/Slasher.sol";

import {LagrangeService} from "src/LagrangeService.sol";

// TODO: referecen the deploy script

contract RegisterOperator is Script, Test {
    string public deployDataPath = string(bytes("lib/eigenlayer-contracts/script/output/M1_deployment_data.json"));

    function run() public {
        string memory deployData = vm.readFile(deployDataPath);
        Slasher slasher = Slasher(stdJson.readAddress(deployData, ".addresses.slasher"));

        LagrangeService service = new LagrangeService(slasher);

        // call optIntoSlashing on slasher
        vm.prank(msg.sender);
        slasher.unpause(0);

        slasher.optIntoSlashing(address(service));
    }
}