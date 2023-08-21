pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";
import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategy.sol";
import {VoteWeigherBaseStorage} from "eigenlayer-contracts/middleware/VoteWeigherBaseStorage.sol";

import {LagrangeService} from "src/protocol/LagrangeService.sol";
import {LagrangeServiceManager} from "src/protocol/LagrangeServiceManager.sol";
import {LagrangeCommittee} from "src/protocol/LagrangeCommittee.sol";

contract AddQuorum is Script, Test {
    string public deployedLGRPath =
        string(bytes("script/output/deployed_lgr.json"));
    string public configPath = string(bytes("config/LagrangeService.json"));

    struct StrategyConfig {
        uint96 multiplier;
        address strategyAddress;
        string strategyName;
    }

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployLGRData = vm.readFile(deployedLGRPath);
        string memory configData = vm.readFile(configPath);

        LagrangeCommittee committee = LagrangeCommittee(
            stdJson.readAddress(deployLGRData, ".addresses.lagrangeCommittee")
        );

        // add strategy multipliers to lagrange service
        StrategyConfig[] memory strategies;
        bytes memory strategiesRaw = stdJson.parseRaw(
            configData,
            ".strategies"
        );
        strategies = abi.decode(strategiesRaw, (StrategyConfig[]));
        VoteWeigherBaseStorage.StrategyAndWeightingMultiplier[]
            memory newStrategiesConsideredAndMultipliers = new VoteWeigherBaseStorage.StrategyAndWeightingMultiplier[](
                strategies.length
            );

        for (uint256 i = 0; i < strategies.length; i++) {
            newStrategiesConsideredAndMultipliers[i] = VoteWeigherBaseStorage
                .StrategyAndWeightingMultiplier({
                    strategy: IStrategy(strategies[i].strategyAddress),
                    multiplier: strategies[i].multiplier
                });
        }

        committee.addStrategiesConsideredAndMultipliers(
            1,
            newStrategiesConsideredAndMultipliers
        );

        vm.stopBroadcast();
    }
}
