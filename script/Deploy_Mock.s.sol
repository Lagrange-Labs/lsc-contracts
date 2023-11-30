pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";

import {DelegationManager} from "../contracts/mock/DMMock.sol";
import {StrategyManager} from "../contracts/mock/SMMock.sol";
import {Slasher} from "../contracts/mock/SlasherMock.sol";
import {Strategy} from "../contracts/mock/STMock.sol";
import {BatchStorageMock} from "../contracts/mock/mantle/BatchStorageMock.sol";

contract DeployMock is Script {
    string public operatorsPath = string(bytes("config/operators.json"));
    string public configPath = string(bytes("config/LagrangeService.json"));

    function run() public {
        string memory configData = vm.readFile(configPath);

        bool isMock = stdJson.readBool(configData, ".isMock");

        if (isMock) {
            vm.startBroadcast(msg.sender);

            BatchStorageMock batchStorage = new BatchStorageMock();

            vm.stopBroadcast();

            // write deployment data to file
            string memory parent_object = "parent object";
            string memory deployed_addresses = "addresses";
            string memory deployed_out = vm.serializeAddress(deployed_addresses, "batchStorage", address(batchStorage));
            string memory final_json = vm.serializeString(parent_object, deployed_addresses, deployed_out);
            vm.writeFile("script/output/deployed_mock.json", final_json);
        } else {
            vm.startBroadcast(msg.sender);

            DelegationManager dm = new DelegationManager();
            StrategyManager sm = new StrategyManager(dm);
            Slasher slasher = new Slasher();
            Strategy st = new Strategy();

            string memory operatorsData = vm.readFile(operatorsPath);
            // register initial operators
            bytes memory arbitrumRaw = stdJson.parseRaw(operatorsData, ".[0].operators");
            address[] memory arbOperators = abi.decode(arbitrumRaw, (address[]));

            for (uint256 i = 0; i < arbOperators.length; i++) {
                IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
                    earningsReceiver: arbOperators[i],
                    delegationApprover: address(0),
                    stakerOptOutWindowBlocks: 0
                });
                dm.registerAsOperator(operatorDetails, "");
            }

            bytes memory optimismRaw = stdJson.parseRaw(operatorsData, ".[1].operators");
            address[] memory optOperators = abi.decode(optimismRaw, (address[]));

            for (uint256 i = 0; i < optOperators.length; i++) {
                IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
                    earningsReceiver: optOperators[i],
                    delegationApprover: address(0),
                    stakerOptOutWindowBlocks: 0
                });
                dm.registerAsOperator(operatorDetails, "");
            }

            vm.stopBroadcast();

            // write deployment data to file
            string memory parent_object = "parent object";
            string memory deployed_addresses = "addresses";
            vm.serializeAddress(deployed_addresses, "delegationManager", address(dm));
            vm.serializeAddress(deployed_addresses, "strategyManager", address(sm));
            vm.serializeAddress(deployed_addresses, "slasher", address(slasher));
            string memory deployed_out = vm.serializeAddress(deployed_addresses, "strategy", address(st));
            string memory final_json = vm.serializeString(parent_object, deployed_addresses, deployed_out);
            vm.writeFile("script/output/deployed_mock.json", final_json);
        }
    }
}
