// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Script.sol";

// import "../../contracts/protocol/LagrangeService.sol";
// import "../../contracts/protocol/LagrangeCommittee.sol";
import "../foundry/CommitteeTree.t.sol";

// import {WETH9} from "../../contracts/mock/WETH9.sol";

// forge script --rpc-url http://localhost:8545 ./test/e2e/CommitteeTest.s.sol:CommitteeTest -vvv

contract CommitteeTest is Script, CommitteeTreeTest {
    string deployedLGRPath = string(bytes("script/output/deployed_lgr.json"));
    string serviceDataPath = string(bytes("config/LagrangeService.json"));
    uint256 private constant _OPERATOR_COUNT = 4;
    uint32 private chainIDArb;
    uint32 private chainIDOpt;

    struct TokenConfig {
        uint96 multiplier;
        address tokenAddress;
        string tokenName;
    }


    function setUp() public override {
        string memory deployLGRData = vm.readFile(deployedLGRPath);
        string memory configData = vm.readFile(serviceDataPath);
        lagrangeCommittee = LagrangeCommittee(
            stdJson.readAddress(deployLGRData, ".addresses.lagrangeCommittee")
        );
        lagrangeService = LagrangeService(
            stdJson.readAddress(deployLGRData, ".addresses.lagrangeService")
        );

        TokenConfig[] memory tokens;
        bytes memory tokensRaw = stdJson.parseRaw(configData, ".tokens");
        tokens = abi.decode(tokensRaw, (TokenConfig[]));
        token = WETH9(payable(tokens[0].tokenAddress));

        stakeManager = StakeManager(stdJson.readAddress(deployLGRData, ".addresses.stakeManager"));
        chainIDArb = 1337;
        chainIDOpt = 420;
    }

    function run() public {
        uint256 originalLeaves = 10;
        address[_OPERATOR_COUNT] memory operators;
        uint256[_OPERATOR_COUNT] memory amounts;
        uint256[2][][_OPERATOR_COUNT] memory blsPubKeysArray;
        uint256[][_OPERATOR_COUNT] memory expectedVotingPowers;

        operators[0] = vm.addr(111);
        operators[1] = vm.addr(222);
        operators[2] = vm.addr(333);
        operators[3] = vm.addr(444);

        // minWeight = 1e6
        // maxWeight = 5e6

        {
            amounts[0] = 1e15; // weight = 1e6, voting_power = 0
            blsPubKeysArray[0] = new uint256[2][](1); // voting_powers = [1e6]

            expectedVotingPowers[0] = new uint256[](1);
            expectedVotingPowers[0][0] = 1e6;
        }

        {
            amounts[1] = 7.5e15; // weight = 7.5e6, voting_power = 7.5e6
            blsPubKeysArray[1] = new uint256[2][](3); // voting_powers = [5e6, 2.5e6], the third blsPubKey is not active

            expectedVotingPowers[1] = new uint256[](2);
            expectedVotingPowers[1][0] = 5e6;
            expectedVotingPowers[1][1] = 2.5e6;
        }

        {
            amounts[2] = 10.5e15; // weight = 10.5e6, voting_power = 10.5e6
            blsPubKeysArray[2] = new uint256[2][](4); // voting_powers = [5e6, 1e6, 4.5e6], the last blsPubKey is not active

            expectedVotingPowers[2] = new uint256[](3);
            expectedVotingPowers[2][0] = 5e6;
            expectedVotingPowers[2][1] = 1e6;
            expectedVotingPowers[2][2] = 4.5e6;
        }

        {
            amounts[3] = 30e15; // weight = 30e6, voting_power = 30e6
            blsPubKeysArray[3] = new uint256[2][](1); // voting_powers = [5e6], 25e6 can't run for voting

            expectedVotingPowers[3] = new uint256[](1);
            expectedVotingPowers[3][0] = 5e6;
        }

        uint256 _blsKeyCounter = 1;
        for (uint256 i; i < _OPERATOR_COUNT; i++) {
            for (uint256 j; j < blsPubKeysArray[i].length; j++) {
                blsPubKeysArray[i][j] = [_blsKeyCounter++, _blsKeyCounter];
            }
        }

        for (uint256 i; i < _OPERATOR_COUNT; i++) {
            _registerOperator(operators[i], amounts[i], blsPubKeysArray[i], chainIDArb);
        }

        ILagrangeCommittee.CommitteeData memory cur;
        {
            (uint256 startBlock, uint256 _genesisBlock, uint256 duration, uint256 freezeDuration, , , ) = lagrangeCommittee.committeeParams(chainIDArb);

            // update the tree
            vm.roll(startBlock + duration - freezeDuration + 1);
            lagrangeCommittee.update(chainIDArb, 1);
            cur = lagrangeCommittee.getCommittee(chainIDArb, startBlock + duration);
        }

        uint256 expectedLeafCount = originalLeaves;
        for (uint256 i; i < _OPERATOR_COUNT; i++) {
            uint224 expectedVotingPower;
            for (uint256 j; j < expectedVotingPowers[i].length; j++) {
                expectedVotingPower += uint224(expectedVotingPowers[i][j]);
            }
            expectedLeafCount += expectedVotingPowers[i].length;

            uint96[] memory individualVotingPowers = lagrangeCommittee.getBlsPubKeyVotingPowers(operators[i], chainIDArb);
            uint96 operatorVotingPower = lagrangeCommittee.getOperatorVotingPower(operators[i], chainIDArb);

            assertEq(operatorVotingPower, expectedVotingPower);
            assertEq(individualVotingPowers.length, expectedVotingPowers[i].length);
            for (uint256 j; j < individualVotingPowers.length; j++) {
                assertEq(individualVotingPowers[j], expectedVotingPowers[i][j]);
            }
        }

        assertEq(cur.leafCount, expectedLeafCount);

        {
            uint256[2][] memory additionalBlsPubKeys;
            additionalBlsPubKeys = new uint256[2][](1);
            additionalBlsPubKeys[0] = [_blsKeyCounter++, _blsKeyCounter];
            (uint256 startBlock, uint256 _genesisBlock, uint256 duration, uint256 freezeDuration, , , ) = lagrangeCommittee.committeeParams(chainIDArb);

            _addBlsPubKeys(operators[0], additionalBlsPubKeys, chainIDArb);
            vm.roll(startBlock + duration * 2 - freezeDuration + 1);
            lagrangeCommittee.update(chainIDArb, 2);
        }
    }
}
