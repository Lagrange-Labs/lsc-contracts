// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";

import {LagrangeCommittee} from "../../contracts/protocol/LagrangeCommittee.sol";
import {ILagrangeService} from "../../contracts/interfaces/ILagrangeService.sol";
import {IVoteWeigher} from "../../contracts/interfaces/IVoteWeigher.sol";
import {LagrangeDeployer} from "./LagrangeDeployer.t.sol";

// This contract is used to deploy LagrangeService contract to the testnet
contract GasCalc is Test, LagrangeDeployer {
    uint256 constant OPERATOR_COUNT = 1000;
    uint256 constant BLS_PUB_KEY_PER_OPERATOR = 2;

    function testGasCalc() public {
        vm.startPrank(vm.addr(1));
        uint32 chainID = 1;
        lagrangeCommittee.registerChain(chainID, 8000, 2000, 1, 2000, 5000);


        vm.roll(2000);
        console.log("testGasCalc", block.number);
        
        for (uint256 i; i < OPERATOR_COUNT; i++) {
            address operator = vm.addr(i + 100);
            uint256[2][] memory blsPubKeys = new uint256[2][](
                BLS_PUB_KEY_PER_OPERATOR
            );
            for (uint256 j; j < BLS_PUB_KEY_PER_OPERATOR; j++) {
                blsPubKeys[j][0] = 2 * (i * BLS_PUB_KEY_PER_OPERATOR + j) + 100;
                blsPubKeys[j][1] = 2 * (i * BLS_PUB_KEY_PER_OPERATOR + j) + 101;
            }

            lagrangeCommittee.addOperator(operator, blsPubKeys);
            lagrangeCommittee.subscribeChain(operator, chainID);
        }

        vm.roll(7000);

        lagrangeCommittee.update(chainID, 1);
        vm.stopPrank();
    }
}
