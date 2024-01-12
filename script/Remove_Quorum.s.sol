pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ISlasher} from "eigenlayer-contracts/src/contracts/interfaces/ISlasher.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {VoteWeigherBaseStorage} from "eigenlayer-middleware/VoteWeigherBaseStorage.sol";

import {LagrangeService} from "../contracts/protocol/LagrangeService.sol";
import {LagrangeServiceManager} from "../contracts/protocol/LagrangeServiceManager.sol";
import {VoteWeigherBaseMock} from "../contracts/mock/VoteWeigherBaseMock.sol";

contract RemoveQuorum is Script, Test {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployLGRData = vm.readFile(deployedLGRPath);

        VoteWeigherBaseMock weigher = VoteWeigherBaseMock(stdJson.readAddress(deployLGRData, ".addresses.voteWeigher"));

        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        weigher.removeStrategiesConsideredAndMultipliers(1, indexes);

        vm.stopBroadcast();
    }
}
