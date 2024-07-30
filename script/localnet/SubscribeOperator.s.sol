pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {LagrangeService} from "../../contracts/protocol/LagrangeService.sol";
import {ISlasher} from "eigenlayer-contracts/src/contracts/interfaces/ISlasher.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";

contract SubscribeOperator is Script, Test {
    string public deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));
    string public deployedEIGPath = string(bytes("script/output/M1_deployment_data.json"));
    string public operatorPath = string(bytes("config/random_operator.json"));

    struct Operator {
        bytes32 blsPrivateKey;
        bytes blsPublicKey;
        uint256[2] blsPublicPoint;
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
        uint256[2][] memory _blsPublicPoints = new uint256[2][](1);
        _blsPublicPoints[0] = operator.blsPublicPoint;
        // ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature; // TODO: need to generate signature
        // lagrangeService.register(operator.operatorAddress, _blsPublicPoints, operatorSignature);
        lagrangeService.subscribe(operator.chainId);

        vm.stopBroadcast();
    }
}
