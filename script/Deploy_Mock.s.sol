pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IDelegationTerms} from "eigenlayer-contracts/interfaces/IDelegationTerms.sol";

import {DelegationManager} from "src/mock/DMMock.sol";
import {StrategyManager} from "src/mock/SMMock.sol";
import {Slasher} from "src/mock/SlasherMock.sol";
import {Strategy} from "src/mock/STMock.sol";

contract DeployMock is Script {

    string public configPath = string(bytes("config/operators.json"));

    function run() public {
        string memory configData = vm.readFile(configPath);

        vm.startBroadcast(msg.sender);

        DelegationManager dm = new DelegationManager();
        StrategyManager sm = new StrategyManager(dm);
        Slasher slasher = new Slasher();
        Strategy st = new Strategy();

        // register initial operators
        bytes memory arbitrumRaw = stdJson.parseRaw(configData, ".[0].operators");
        address[] memory arbOperators = abi.decode(arbitrumRaw, (address[]));

        for (uint256 i = 0; i < arbOperators.length; i++) {
            dm.registerAsOperator(IDelegationTerms(arbOperators[i]));
        }

        bytes memory optimismRaw = stdJson.parseRaw(configData, ".[1].operators");
        address[] memory optOperators = abi.decode(optimismRaw, (address[]));

        for (uint256 i = 0; i < optOperators.length; i++) {
            dm.registerAsOperator(IDelegationTerms(optOperators[i]));
        }

        vm.stopBroadcast();

        // write deployment data to file
        string memory parent_object = "parent object";
        string memory deployed_addresses = "addresses";
        vm.serializeAddress(
            deployed_addresses,
            "delegationManager",
            address(dm)
        );
        vm.serializeAddress(deployed_addresses, "strategyManager", address(sm));
        vm.serializeAddress(deployed_addresses, "slasher", address(slasher));
        string memory deployed_out = vm.serializeAddress(
            deployed_addresses,
            "strategy",
            address(st)
        );
        string memory final_json = vm.serializeString(
            parent_object,
            deployed_addresses,
            deployed_out
        );
        vm.writeFile("script/output/deployed_mock.json", final_json);
    }
}
