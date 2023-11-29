// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ISlasher} from "eigenlayer-contracts/src/contracts/interfaces/ISlasher.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IVoteWeigher} from "eigenlayer-middleware/interfaces/IVoteWeigher.sol";

import {LagrangeService} from "src/protocol/LagrangeService.sol";
import {LagrangeServiceManager} from "src/protocol/LagrangeServiceManager.sol";
import {LagrangeCommittee} from "src/protocol/LagrangeCommittee.sol";
import {VoteWeigherBaseMock} from "src/mock/VoteWeigherBaseMock.sol";
import {StakeManager} from "src/library/StakeManager.sol";

contract AddQuorum is Script, Test {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));
    string public configPath = string(bytes("config/LagrangeService.json"));

    struct StrategyConfig {
        uint96 multiplier;
        address strategyAddress;
        string strategyName;
    }

    struct TokenConfig {
        uint96 multiplier;
        address tokenAddress;
        string tokenName;
    }

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployLGRData = vm.readFile(deployedLGRPath);
        string memory configData = vm.readFile(configPath);

        bool isNative = stdJson.readBool(configData, ".isNative");

        if (isNative) {
            StakeManager stakeManager = StakeManager(stdJson.readAddress(deployLGRData, ".addresses.stakeManager"));

            // add token multipliers to stake manager
            TokenConfig[] memory tokens;
            bytes memory tokensRaw = stdJson.parseRaw(configData, ".tokens");
            tokens = abi.decode(tokensRaw, (TokenConfig[]));
            for (uint256 i = 0; i < tokens.length; i++) {
                stakeManager.setTokenMultiplier(tokens[i].tokenAddress, tokens[i].multiplier);
            }
            uint8[] memory quorumIndexes = new uint8[](1);
            quorumIndexes[0] = 0;
            stakeManager.setQuorumIndexes(1, quorumIndexes);
        } else {
            VoteWeigherBaseMock voteWeigher =
                VoteWeigherBaseMock(stdJson.readAddress(deployLGRData, ".addresses.voteWeigher"));

            // add strategy multipliers to lagrange service
            StrategyConfig[] memory strategies;
            bytes memory strategiesRaw = stdJson.parseRaw(configData, ".strategies");
            strategies = abi.decode(strategiesRaw, (StrategyConfig[]));
            IVoteWeigher.StrategyAndWeightingMultiplier[] memory newStrategiesConsideredAndMultipliers =
            new IVoteWeigher.StrategyAndWeightingMultiplier[](
                    strategies.length
                );

            for (uint256 i = 0; i < strategies.length; i++) {
                newStrategiesConsideredAndMultipliers[i] = IVoteWeigher.StrategyAndWeightingMultiplier({
                    strategy: IStrategy(strategies[i].strategyAddress),
                    multiplier: strategies[i].multiplier
                });
            }
            voteWeigher.addStrategiesConsideredAndMultipliers(1, newStrategiesConsideredAndMultipliers);
        }

        vm.stopBroadcast();
    }
}
