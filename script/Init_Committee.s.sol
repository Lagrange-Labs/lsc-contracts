pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";
import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategy.sol";
import {VoteWeigherBaseStorage} from "eigenlayer-contracts/middleware/VoteWeigherBaseStorage.sol";

import {LagrangeService} from "src/protocol/LagrangeService.sol";
import {LagrangeServiceManager} from "src/protocol/LagrangeServiceManager.sol";
import {LagrangeCommittee} from "src/protocol/LagrangeCommittee.sol";

contract InitCommittee is Script, Test {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));
    string public deployedEIGPath = string(bytes("script/output/M1_deployment_data.json"));
    string public configPath = string(bytes("config/LagrangeService.json"));

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployLGRData = vm.readFile(deployedLGRPath);
        string memory deployEIGData = vm.readFile(deployedEIGPath);
        string memory configData = vm.readFile(configPath);

        LagrangeCommittee lagrangeCommittee = LagrangeCommittee(
            stdJson.readAddress(deployLGRData, ".addresses.lagrangeCommittee")
        );
        LagrangeService lagrangeService = LagrangeService(
            stdJson.readAddress(deployLGRData, ".addresses.lagrangeService")
        );
        LagrangeServiceManager lagrangeServiceManager = LagrangeServiceManager(
            stdJson.readAddress(deployLGRData, ".addresses.lagrangeServiceManager")
        );

        // TODO - determine strategy addresses
        address wethStrategy = stdJson.readAddress(deployEIGData, ".addresses.strategies.['Wrapped Ether']");
        VoteWeigherBaseStorage.StrategyAndWeightingMultiplier[] memory newStrategiesConsideredAndMultipliers = new VoteWeigherBaseStorage.StrategyAndWeightingMultiplier[](1);
        newStrategiesConsideredAndMultipliers[0] = VoteWeigherBaseStorage.StrategyAndWeightingMultiplier({
            strategy: IStrategy(wethStrategy),
            multiplier: 1
        });

        // add strategy multipliers to lagrange service
        lagrangeService.addStrategiesConsideredAndMultipliers(1, newStrategiesConsideredAndMultipliers);

        // opt into the lagrange service
        address slasherAddress = stdJson.readAddress(deployEIGData, ".addresses.slasher");
        ISlasher(slasherAddress).optIntoSlashing(address(lagrangeServiceManager));

        vm.stopBroadcast();
    }
}
