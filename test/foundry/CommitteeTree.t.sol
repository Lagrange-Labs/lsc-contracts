// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LagrangeDeployer.t.sol";

contract CommitteeTreeTest is LagrangeDeployer {
    function testSubscribeChain() public {
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0] = _readKnownBlsPubKey(1);
        uint256 privateKey = 111;
        address operator = vm.addr(privateKey);

        vm.deal(operator, 1e19);
        // add operator to whitelist
        vm.prank(vm.addr(adminPrivateKey));
        address[] memory operators = new address[](1);
        operators[0] = operator;
        lagrangeService.addOperatorsToWhitelist(operators);

        _deposit(operator, 1e5); // which is less than the dividend threshold, the voting power is 0

        vm.startPrank(operator);

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        operatorSignature.expiry = block.timestamp + 60;
        operatorSignature.salt = bytes32(0x0);
        bytes32 digest = avsDirectory.calculateOperatorAVSRegistrationDigestHash(
            operator, address(lagrangeService), operatorSignature.salt, operatorSignature.expiry
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        operatorSignature.signature = abi.encodePacked(r, s, v);

        // register operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION - 1);
        lagrangeService.register(operator, _calcProofForBLSKeys(privateKey, blsPubKeys), operatorSignature);
        // subscribe chain
        vm.expectRevert("Insufficient Vote Weight");
        lagrangeService.subscribe(CHAIN_ID);
        vm.stopPrank();

        _deposit(operator, 1e15);

        vm.startPrank(operator);
        lagrangeService.subscribe(CHAIN_ID);
        vm.stopPrank();
    }

    uint256 private constant OPERATOR_COUNT = 3;

    function testTreeConstructForSingleBlsPubKey() public {
        uint256[OPERATOR_COUNT] memory privateKeys;
        address[OPERATOR_COUNT] memory operators;
        uint256[OPERATOR_COUNT] memory amounts;
        uint256[2][][OPERATOR_COUNT] memory blsPubKeysArray;

        privateKeys[0] = 111;
        privateKeys[1] = 222;
        privateKeys[2] = 333;

        for (uint256 i; i < OPERATOR_COUNT; i++) {
            operators[i] = vm.addr(privateKeys[i]);
        }

        amounts[0] = 1e15;
        amounts[1] = 2e15;
        amounts[2] = 3e15;

        blsPubKeysArray[0] = new uint256[2][](1);
        blsPubKeysArray[0][0] = _readKnownBlsPubKey(1);
        blsPubKeysArray[1] = new uint256[2][](1);
        blsPubKeysArray[1][0] = _readKnownBlsPubKey(2);
        blsPubKeysArray[2] = new uint256[2][](1);
        blsPubKeysArray[2][0] = _readKnownBlsPubKey(3);

        for (uint256 i; i < OPERATOR_COUNT; i++) {
            _registerOperator(operators[i], privateKeys[i], amounts[i], blsPubKeysArray[i], CHAIN_ID);
        }

        // update the tree
        uint256 updatingBlock1 = START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION + 1;
        vm.roll(updatingBlock1);
        lagrangeCommittee.update(CHAIN_ID, 1);

        ILagrangeCommittee.CommitteeData memory cur =
            lagrangeCommittee.getCommittee(CHAIN_ID, START_EPOCH + EPOCH_PERIOD);

        assertEq(cur.leafCount, 3);
        assertEq(cur.root, 0x2c2afeea04cd68138240e7a57513c5276ac52910e01210ad8dd83a1c8c3fc070);

        _deposit(operators[0], 1e15);

        uint256 updatingBlock2 = updatingBlock1 + EPOCH_PERIOD - FREEZE_DURATION + 1;
        vm.roll(updatingBlock2 - 1);
        vm.expectRevert("Block number is prior to committee freeze window.");
        lagrangeCommittee.update(CHAIN_ID, 2);

        vm.roll(updatingBlock2);
        lagrangeCommittee.update(CHAIN_ID, 2);

        cur = lagrangeCommittee.getCommittee(CHAIN_ID, updatingBlock2 + 1);
        assertEq(cur.leafCount, 3);
        assertEq(cur.root, 0x40f94114329d62f0875538d1d999c88d9369bb2ec18e085836e9142b2cbf31ee);
    }

    function testRevertEpoch() public {
        uint256[OPERATOR_COUNT] memory privateKeys;
        address[OPERATOR_COUNT] memory operators;
        uint256[OPERATOR_COUNT] memory amounts;
        uint256[2][][OPERATOR_COUNT] memory blsPubKeysArray;

        privateKeys[0] = 111;
        privateKeys[1] = 222;
        privateKeys[2] = 333;

        for (uint256 i; i < OPERATOR_COUNT; i++) {
            operators[i] = vm.addr(privateKeys[i]);
        }

        amounts[0] = 1e15;
        amounts[1] = 2e15;
        amounts[2] = 3e15;

        blsPubKeysArray[0] = new uint256[2][](1);
        blsPubKeysArray[0][0] = _readKnownBlsPubKey(1);
        blsPubKeysArray[1] = new uint256[2][](1);
        blsPubKeysArray[1][0] = _readKnownBlsPubKey(2);
        blsPubKeysArray[2] = new uint256[2][](1);
        blsPubKeysArray[2][0] = _readKnownBlsPubKey(3);

        for (uint256 i; i < OPERATOR_COUNT; i++) {
            _registerOperator(operators[i], privateKeys[i], amounts[i], blsPubKeysArray[i], CHAIN_ID);
        }

        // update the tree
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION + 1);
        lagrangeCommittee.update(CHAIN_ID, 1);

        _deposit(operators[0], 1e15);

        vm.roll(START_EPOCH + EPOCH_PERIOD * 2 - FREEZE_DURATION + 1);
        lagrangeCommittee.update(CHAIN_ID, 2);

        vm.startPrank(lagrangeService.owner());
        vm.expectRevert("The epochNumber is not the latest.");
        lagrangeCommittee.revertEpoch(CHAIN_ID, 1);
        lagrangeCommittee.revertEpoch(CHAIN_ID, 2);
        vm.stopPrank();

        vm.roll(START_EPOCH + EPOCH_PERIOD * 2);
        lagrangeCommittee.update(CHAIN_ID, 2);
        ILagrangeCommittee.CommitteeData memory cur =
            lagrangeCommittee.getCommittee(CHAIN_ID, START_EPOCH + EPOCH_PERIOD * 2);
        assertEq(cur.leafCount, 3);
        assertEq(cur.updatedBlock, START_EPOCH + EPOCH_PERIOD * 2);
    }

    uint256 private constant OPERATOR_COUNT2 = 4;

    function testTreeConstructForMultipleBlsKeys() public {
        uint256[OPERATOR_COUNT2] memory privateKeys;
        address[OPERATOR_COUNT2] memory operators;
        uint256[OPERATOR_COUNT2] memory amounts;
        uint256[2][][OPERATOR_COUNT2] memory blsPubKeysArray;
        uint256[][OPERATOR_COUNT2] memory expectedVotingPowers;

        privateKeys[0] = 111;
        privateKeys[1] = 222;
        privateKeys[2] = 333;
        privateKeys[3] = 444;

        for (uint256 i; i < OPERATOR_COUNT2; i++) {
            operators[i] = vm.addr(privateKeys[i]);
        }

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
        for (uint256 i; i < OPERATOR_COUNT2; i++) {
            for (uint256 j; j < blsPubKeysArray[i].length; j++) {
                blsPubKeysArray[i][j] = _readKnownBlsPubKey(_blsKeyCounter++);
            }
        }

        for (uint256 i; i < OPERATOR_COUNT2; i++) {
            _registerOperator(operators[i], privateKeys[i], amounts[i], blsPubKeysArray[i], CHAIN_ID);
        }

        ILagrangeCommittee.CommitteeData memory cur;
        {
            (uint256 startBlock,,, uint256 duration, uint256 freezeDuration,,,) =
                lagrangeCommittee.committeeParams(CHAIN_ID);

            // update the tree
            vm.roll(startBlock + duration - freezeDuration + 1);
            lagrangeCommittee.update(CHAIN_ID, 1);
            cur = lagrangeCommittee.getCommittee(CHAIN_ID, startBlock + duration);
        }

        uint256 expectedLeafCount;
        for (uint256 i; i < OPERATOR_COUNT2; i++) {
            uint224 expectedVotingPower;
            for (uint256 j; j < expectedVotingPowers[i].length; j++) {
                expectedVotingPower += uint224(expectedVotingPowers[i][j]);
            }
            expectedLeafCount += expectedVotingPowers[i].length;

            uint96[] memory individualVotingPowers = lagrangeCommittee.getBlsPubKeyVotingPowers(operators[i], CHAIN_ID);
            uint96 operatorVotingPower = lagrangeCommittee.getOperatorVotingPower(operators[i], CHAIN_ID);

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
            additionalBlsPubKeys[0] = _readKnownBlsPubKey(_blsKeyCounter++);
            (uint256 startBlock,,, uint256 duration, uint256 freezeDuration,,,) =
                lagrangeCommittee.committeeParams(CHAIN_ID);

            vm.roll(startBlock + duration - freezeDuration - 1);

            IBLSKeyChecker.BLSKeyWithProof memory blsKeyWithProof =
                _calcProofForBLSKeys(privateKeys[0], additionalBlsPubKeys, "salt2");
            vm.prank(operators[0]);
            lagrangeService.addBlsPubKeys(blsKeyWithProof);
            vm.roll(startBlock + duration * 2 - freezeDuration + 1);
            lagrangeCommittee.update(CHAIN_ID, 2);
        }
    }

    function testOperatorUpdateBLSKeys() public {
        uint256 privateKey = 111;
        address operator = vm.addr(privateKey);
        uint256 amount = 1e19;
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0] = _readKnownBlsPubKey(1);

        _registerOperator(operator, privateKey, amount, blsPubKeys, CHAIN_ID);

        uint256[2][] memory additionalBlsPubKeys = new uint256[2][](2);
        additionalBlsPubKeys[0] = _readKnownBlsPubKey(2);
        additionalBlsPubKeys[1] = _readKnownBlsPubKey(3);
        vm.startPrank(address(lagrangeService));
        lagrangeCommittee.addBlsPubKeys(
            operator, _calcProofForBLSKeys(privateKey, additionalBlsPubKeys, bytes32("salt2"))
        );
        uint256[2][] memory _blsPubKeys = lagrangeCommittee.getBlsPubKeys(operator);
        assertEq(_blsPubKeys.length, 3);
        assertEq(_blsPubKeys[0][0], blsPubKeys[0][0]);
        assertEq(_blsPubKeys[1][1], additionalBlsPubKeys[0][1]);
        assertEq(_blsPubKeys[2][0], additionalBlsPubKeys[1][0]);

        uint256[2] memory newBlsPubKey = _readKnownBlsPubKey(4);
        lagrangeCommittee.updateBlsPubKey(operator, 1, _calcProofForBLSKey(privateKey, newBlsPubKey, bytes32("salt3")));
        _blsPubKeys = lagrangeCommittee.getBlsPubKeys(operator);
        assertEq(_blsPubKeys[1][0], newBlsPubKey[0]);
        assertEq(_blsPubKeys[1][1], newBlsPubKey[1]);
        assertEq(_blsPubKeys[0][1], blsPubKeys[0][1]);
        assertEq(_blsPubKeys[2][1], additionalBlsPubKeys[1][1]);

        uint32[] memory indices = new uint32[](2);
        indices[0] = 2;
        indices[1] = 0;
        lagrangeCommittee.removeBlsPubKeys(operator, indices);
        _blsPubKeys = lagrangeCommittee.getBlsPubKeys(operator);
        assertEq(_blsPubKeys.length, 1);
        assertEq(_blsPubKeys[0][0], _readKnownBlsPubKey(4)[0]);
        assertEq(_blsPubKeys[0][1], _readKnownBlsPubKey(4)[1]);

        // removing all blsPubKeys should revert
        uint32[] memory indices2 = new uint32[](1);
        indices2[0] = 0;
        vm.expectRevert("Invalid indices length, BLS keys cannot be empty.");
        lagrangeCommittee.removeBlsPubKeys(operator, indices2);

        {
            // zero value should revert
            uint256[2][] memory additionalBlsPubKeys1 = new uint256[2][](1);
            additionalBlsPubKeys1[0] = _readKnownBlsPubKey(5);

            lagrangeCommittee.addBlsPubKeys(
                operator, _calcProofForBLSKeys(privateKey, additionalBlsPubKeys1, bytes32("salt4"))
            );
            uint256[2][] memory _blsPubKeys1 = lagrangeCommittee.getBlsPubKeys(operator);
            assertEq(_blsPubKeys1.length, 2);
            assertEq(_blsPubKeys1[1][0], _readKnownBlsPubKey(5)[0]);
            assertEq(_blsPubKeys1[1][1], _readKnownBlsPubKey(5)[1]);
        }

        {
            // removing non-existing blsPubKeys should revert
            uint32[] memory indices3 = new uint32[](1);
            indices3[0] = 2;
            vm.expectRevert("Invalid index");
            lagrangeCommittee.removeBlsPubKeys(operator, indices3);
        }

        {
            uint256[2] memory newBlsPubKey1;
            newBlsPubKey1 = _readKnownBlsPubKey(1);
            lagrangeCommittee.updateBlsPubKey(
                operator, 0, _calcProofForBLSKey(privateKey, newBlsPubKey1, bytes32("salt5"))
            );
            _blsPubKeys = lagrangeCommittee.getBlsPubKeys(operator);
            assertEq(_blsPubKeys[1][0], _readKnownBlsPubKey(5)[0]);
            assertEq(_blsPubKeys[1][1], _readKnownBlsPubKey(5)[1]);
            assertEq(_blsPubKeys[0][0], _readKnownBlsPubKey(1)[0]);
            assertEq(_blsPubKeys[0][1], _readKnownBlsPubKey(1)[1]);
        }

        lagrangeCommittee.updateSignAddress(operator, vm.addr(102));
        (address signAddress,) = lagrangeCommittee.operatorsStatus(operator);
        assertEq(signAddress, vm.addr(102));
    }
}
