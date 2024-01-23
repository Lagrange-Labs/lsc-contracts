// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ISlasher} from "eigenlayer-contracts/src/contracts/interfaces/ISlasher.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";

import {LagrangeService} from "../contracts/protocol/LagrangeService.sol";
import {LagrangeCommittee} from "../contracts/protocol/LagrangeCommittee.sol";
import {StakeManager} from "../contracts/library/StakeManager.sol";
import {IVoteWeigher} from "../contracts/interfaces/IVoteWeigher.sol";

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
            stakeManager.setQuorumIndexes(0, quorumIndexes);
        } else {
            // TODO
        }

        vm.stopBroadcast();
    }
}
