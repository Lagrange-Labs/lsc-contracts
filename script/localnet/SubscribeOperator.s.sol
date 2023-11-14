pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {LagrangeService} from "src/protocol/LagrangeService.sol";
import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";

contract SubscribeOperator is Script, Test {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));
    string public deployedEIGPath = string(bytes("script/output/M1_deployment_data.json"));
    string public operatorPath = string(bytes("config/random_operator.json"));

    struct Operator {
        bytes32 blsPrivateKey;
        bytes blsPublicKey;
        bytes blsPublicPoint;
        uint32 chainId;
        bytes32 ecdsaPrivateKey;
        address operatorAddress;
    }

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployLGRData = vm.readFile(deployedLGRPath);
        string memory deployEIGData = vm.readFile(deployedEIGPath);
        string memory operatorData = vm.readFile(operatorPath);

        bytes memory operatorRaw = stdJson.parseRaw(operatorData, ".operator");
        Operator memory operator = abi.decode(operatorRaw, (Operator));

        ISlasher slasher = ISlasher(stdJson.readAddress(deployEIGData, ".addresses.slasher"));
        slasher.optIntoSlashing(stdJson.readAddress(deployLGRData, ".addresses.lagrangeServiceManager"));

        LagrangeService lagrangeService =
            LagrangeService(stdJson.readAddress(deployLGRData, ".addresses.lagrangeService"));
        lagrangeService.register(operator.blsPublicPoint, type(uint32).max);
        lagrangeService.subscribe(operator.chainId);

        vm.stopBroadcast();
    }
}
