pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {WETH9} from "../../contracts/mock/WETH9.sol";

import {LagrangeService} from "../../contracts/protocol/LagrangeService.sol";
import {LagrangeServiceManager} from "../../contracts/protocol/LagrangeServiceManager.sol";
import {LagrangeCommittee} from "../../contracts/protocol/LagrangeCommittee.sol";
import {VoteWeigherBaseMock} from "../../contracts/mock/VoteWeigherBaseMock.sol";
import {StakeManager} from "../../contracts/library/StakeManager.sol";

contract DepositStake is Script, Test {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));
    string public configPath = string(bytes("config/LagrangeService.json"));

    function run() public {
        string memory deployLGRData = vm.readFile(deployedLGRPath);
        string memory configData = vm.readFile(configPath);

        bool isNative = stdJson.readBool(configData, ".isNative");

        vm.startBroadcast(msg.sender);
        if (isNative) {
            StakeManager stakeManager = StakeManager(stdJson.readAddress(deployLGRData, ".addresses.stakeManager"));
            WETH9 token = WETH9(payable(stdJson.readAddress(configData, ".tokens.[0].token_address")));
            token.deposit{value: 1e15}();
            token.approve(address(stakeManager), 1e15);
            stakeManager.deposit(address(token), 1e15);
        }
        vm.stopBroadcast();
    }
}
