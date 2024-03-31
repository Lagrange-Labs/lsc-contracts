pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {VoteWeigher} from "../contracts/protocol/VoteWeigher.sol";
import {LagrangeCommittee} from "../contracts/protocol/LagrangeCommittee.sol";

contract RemoveQuorum is Script, Test {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployLGRData = vm.readFile(deployedLGRPath);

        // VoteWeigher weigher = VoteWeigher(stdJson.readAddress(deployLGRData, ".addresses.voteWeigher"));

        // weigher.removeQuorumMultiplier(0);

        LagrangeCommittee committee =
            LagrangeCommittee(stdJson.readAddress(deployLGRData, ".addresses.lagrangeCommittee"));
        committee.updateChain(8453, -18190018, 1235534, 7000, 700, 0, 1000000000, 1000000000000);

        vm.stopBroadcast();
    }
}
