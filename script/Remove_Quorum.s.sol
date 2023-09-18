pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";
import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategy.sol";
import {VoteWeigherBaseStorage} from "eigenlayer-contracts/middleware/VoteWeigherBaseStorage.sol";

import {LagrangeService} from "src/protocol/LagrangeService.sol";
import {LagrangeServiceManager} from "src/protocol/LagrangeServiceManager.sol";
import {VoteWeigherBaseMock} from "src/mock/VoteWeigherBaseMock.sol";

contract RemoveQuorum is Script, Test {
    string public deployedLGRPath =
        string(bytes("script/output/deployed_lgr.json"));

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployLGRData = vm.readFile(deployedLGRPath);

        VoteWeigherBaseMock weigher = VoteWeigherBaseMock(
            stdJson.readAddress(deployLGRData, ".addresses.voteWeigher")
        );

        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(0x91E333A3d61862B1FE976351cf0F3b30aff1D202);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        weigher.removeStrategiesConsideredAndMultipliers(
            1,
            strategies,
            indexes
        );

        vm.stopBroadcast();
    }
}
