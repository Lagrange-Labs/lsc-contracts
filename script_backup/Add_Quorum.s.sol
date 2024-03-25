// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IVoteWeigher} from "../contracts/interfaces/IVoteWeigher.sol";
import {StakeManager} from "../contracts/library/StakeManager.sol";

contract AddQuorum is Script, Test {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));
    string public configPath = string(bytes("config/LagrangeService.json"));

    struct TokenConfig {
        uint96 multiplier;
        address tokenAddress;
        string tokenName;
    }

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployLGRData = vm.readFile(deployedLGRPath);
        string memory configData = vm.readFile(configPath);

        IVoteWeigher voteWeigher = IVoteWeigher(stdJson.readAddress(deployLGRData, ".addresses.voteWeigher"));

        bool isNative = stdJson.readBool(configData, ".isNative");

        TokenConfig[] memory tokens;
        bytes memory tokensRaw = stdJson.parseRaw(configData, ".tokens");
        tokens = abi.decode(tokensRaw, (TokenConfig[]));

        if (isNative) {
            // add tokens to stake manager whitelist
            StakeManager stakeManager = StakeManager(stdJson.readAddress(deployLGRData, ".addresses.stakeManager"));

            address[] memory tokenAddresses = new address[](tokens.length);
            for (uint256 i = 0; i < tokens.length; i++) {
                tokenAddresses[i] = tokens[i].tokenAddress;
            }
            stakeManager.addTokensToWhitelist(tokenAddresses);
        }

        // add token multipliers to vote weigher
        IVoteWeigher.TokenMultiplier[] memory multipliers = new IVoteWeigher.TokenMultiplier[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            multipliers[i] = (IVoteWeigher.TokenMultiplier(tokens[i].tokenAddress, tokens[i].multiplier));
        }
        voteWeigher.addQuorumMultiplier(0, multipliers);

        vm.stopBroadcast();
    }
}
