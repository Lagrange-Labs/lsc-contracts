pragma solidity =0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategy.sol";
import {StrategyManager} from "eigenlayer-contracts/core/StrategyManager.sol";
import {IDelegationTerms} from "eigenlayer-contracts/interfaces/IDelegationTerms.sol";
import {DelegationManager} from "eigenlayer-contracts/core/DelegationManager.sol";

import {Slasher} from "eigenlayer-contracts/core/Slasher.sol";
import {LagrangeService} from "src/protocol/LagrangeService/LagrangeService.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Deploy is Script, Test {
    string public deployDataPath =
        string(
            bytes(
                "lib/eigenlayer-contracts/script/output/M1_deployment_data.json"
            )
        );
    address WETHStractegyAddress;

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployData = vm.readFile(deployDataPath);
        
        // Deploy LagrangeService
        Slasher slasher = Slasher(
            stdJson.readAddress(deployData, ".addresses.slasher")
        );
        LagrangeService service = new LagrangeService(slasher);
        console.log("LagrangeService deployed at: ", address(service));

        // call optIntoSlashing on slasher
        slasher.unpause(0);
        slasher.optIntoSlashing(address(service));

        // register the service
        service.register(type(uint32).max);

        vm.stopBroadcast();
    }
}
