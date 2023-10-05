pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategy.sol";
import {StrategyManager} from "eigenlayer-contracts/core/StrategyManager.sol";
import {DelegationManager} from "eigenlayer-contracts/core/DelegationManager.sol";

contract AddStrategy is Script, Test {
    string public deployDataPath = string(bytes("script/output/M1_deployment_data.json"));

    address WETHStractegyAddress;

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployData = vm.readFile(deployDataPath);

        WETHStractegyAddress = stdJson.readAddress(deployData, ".addresses.strategies.['Wrapped Ether']");
        StrategyManager strategyManager = StrategyManager(stdJson.readAddress(deployData, ".addresses.strategyManager"));

        IStrategy WETHStrategy = IStrategy(WETHStractegyAddress);

        // add strategy to strategy manager
        strategyManager.setStrategyWhitelister(msg.sender);

        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = WETHStrategy;
        strategyManager.addStrategiesToDepositWhitelist(strategies);

        vm.stopBroadcast();
    }
}
