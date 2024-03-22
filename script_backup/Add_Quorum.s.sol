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

        // add token multipliers to stake manager
        TokenConfig[] memory tokens;
        bytes memory tokensRaw = stdJson.parseRaw(configData, ".tokens");
        tokens = abi.decode(tokensRaw, (TokenConfig[]));
        IVoteWeigher.TokenMultiplier[] memory multipliers = new IVoteWeigher.TokenMultiplier[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            multipliers[i] = (IVoteWeigher.TokenMultiplier(tokens[i].tokenAddress, tokens[i].multiplier));
        }
        voteWeigher.addQuorumMultiplier(0, multipliers);

        vm.stopBroadcast();
    }
}
