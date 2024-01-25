pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {VoteWeigher} from "../contracts/protocol/VoteWeigher.sol";

contract RemoveQuorum is Script, Test {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployLGRData = vm.readFile(deployedLGRPath);

        VoteWeigher weigher = VoteWeigher(stdJson.readAddress(deployLGRData, ".addresses.voteWeigher"));

        weigher.removeQuorumMultiplier(0);

        vm.stopBroadcast();
    }
}
