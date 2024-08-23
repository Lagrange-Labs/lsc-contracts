pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {WETH9} from "../../../contracts/mock/WETH9.sol";
import {LagrangeService} from "../../../contracts/protocol/LagrangeService.sol";
import {LagrangeCommittee} from "../../../contracts/protocol/LagrangeCommittee.sol";
import {VoteWeigher} from "../../../contracts/protocol/VoteWeigher.sol";
import {StakeManager} from "../../../contracts/library/StakeManager.sol";

contract DepositStake is Script, Test {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));
    string public configPath = string(bytes("config/LagrangeService.json"));

    function run() public {
        string memory deployLGRData = vm.readFile(deployedLGRPath);
        string memory configData = vm.readFile(configPath);

        vm.startBroadcast(msg.sender);

        StakeManager stakeManager = StakeManager(stdJson.readAddress(deployLGRData, ".addresses.stakeManager"));
        WETH9 token = WETH9(payable(stdJson.readAddress(configData, ".tokens.[0].token_address")));
        token.deposit{value: 1e15}();
        token.approve(address(stakeManager), 1e15);
        stakeManager.deposit(IERC20(address(token)), 1e15);

        vm.stopBroadcast();
    }
}
