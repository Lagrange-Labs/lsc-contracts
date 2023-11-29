pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ISlasher} from "eigenlayer-contracts/src/contracts/interfaces/ISlasher.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {VoteWeigherBaseStorage} from "eigenlayer-middleware/VoteWeigherBaseStorage.sol";

import {LagrangeService} from "src/protocol/LagrangeService.sol";
import {LagrangeServiceManager} from "src/protocol/LagrangeServiceManager.sol";
import {LagrangeCommittee} from "src/protocol/LagrangeCommittee.sol";

contract InitCommittee is Script, Test {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));
    string public configPath = string(bytes("config/LagrangeService.json"));

    struct InitialChains {
        uint32 chainId;
        string chainName;
        uint256 epochPeriod;
        uint256 freezeDuration;
    }

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployLGRData = vm.readFile(deployedLGRPath);
        string memory configData = vm.readFile(configPath);

        LagrangeCommittee lagrangeCommittee =
            LagrangeCommittee(stdJson.readAddress(deployLGRData, ".addresses.lagrangeCommittee"));

        // initialize the lagrange committee
        bytes memory initChains = stdJson.parseRaw(configData, ".chains");
        InitialChains[] memory initialChains = abi.decode(initChains, (InitialChains[]));

        for (uint256 i = 0; i < initialChains.length; i++) {
            lagrangeCommittee.registerChain(
                initialChains[i].chainId, initialChains[i].epochPeriod, initialChains[i].freezeDuration
            );
        }

        vm.stopBroadcast();
    }
}
