pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {ISlasher} from "eigenlayer-contracts/src/contracts/interfaces/ISlasher.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";

import {LagrangeService} from "../../contracts/protocol/LagrangeService.sol";
import {LagrangeCommittee} from "../../contracts/protocol/LagrangeCommittee.sol";

contract InitCommittee is Script {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));
    string public configPath = string(bytes("config/LagrangeService.json"));

    struct InitialChains {
        uint32 chainId;
        string chainName;
        uint256 epochPeriod;
        uint256 freezeDuration;
        uint256 genesisBlock;
        uint96 maxWeight;
        uint96 minWeight;
        uint8 quorumNumber;
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
                initialChains[i].chainId,
                initialChains[i].genesisBlock,
                initialChains[i].epochPeriod,
                initialChains[i].freezeDuration,
                initialChains[i].quorumNumber,
                initialChains[i].minWeight,
                initialChains[i].maxWeight
            );
        }

        vm.stopBroadcast();
    }
}
