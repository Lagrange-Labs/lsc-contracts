pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IDelegationTerms} from "eigenlayer-contracts/interfaces/IDelegationTerms.sol";

import {DelegationManager} from "src/mock/DMMock.sol";
import {StrategyManager} from "src/mock/SMMock.sol";
import {Slasher} from "src/mock/SlasherMock.sol";
import {Strategy} from "src/mock/STMock.sol";

contract DeployMock is Script {
    struct InitialChain {
        bytes blsPubKey;
        uint256 chainId;
        address operator;
    }

    string public configPath = string(bytes("config/operators.json"));

    function run() public {
        string memory configData = vm.readFile(configPath);

        vm.startBroadcast(msg.sender);

        DelegationManager dm = new DelegationManager();
        StrategyManager sm = new StrategyManager(dm);
        Slasher slasher = new Slasher();
        Strategy st = new Strategy();

        // register initial operators
        InitialChain[] memory arbitrum = abi.decode(
            stdJson.parseRaw(configData, ".arbitrum"),
            (InitialChain[])
        );
        for (uint256 i = 0; i < arbitrum.length; i++) {
            dm.registerAsOperator(IDelegationTerms(arbitrum[i].operator));
        }
        InitialChain[] memory optimism = abi.decode(
            stdJson.parseRaw(configData, ".optimism"),
            (InitialChain[])
        );

        for (uint256 i = 0; i < optimism.length; i++) {
            dm.registerAsOperator(IDelegationTerms(optimism[i].operator));
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
