// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LagrangeDeployer.t.sol";
// import {ILagrangeCommitte} from "../../contracts/interfaces/ILagrangeCommitte.sol";

contract CommitteeTreeTest is LagrangeDeployer {
    function _deposit(address operator, uint256 amount) internal {
        vm.startPrank(operator);

        token.deposit{value: amount}();
        token.approve(address(stakeManager), amount);

        // deposit tokens to stake manager
        stakeManager.deposit(IERC20(address(token)), amount);

        vm.stopPrank();
    }

    function _registerOperator(
        address operator,
        uint256 privateKey,
        uint256 amount,
        uint256[2][] memory blsPubKeys,
        uint32 chainID
    ) internal {
        vm.deal(operator, 1e19);
        // add operator to whitelist
        vm.prank(lagrangeService.owner());
        address[] memory operators = new address[](1);
        operators[0] = operator;
        lagrangeService.addOperatorsToWhitelist(operators);

        _deposit(operator, amount);

        vm.startPrank(operator);
        // register operator

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        operatorSignature.expiry = block.timestamp + 60;
        operatorSignature.salt = bytes32(0x0);
        bytes32 digest = avsDirectory.calculateOperatorAVSRegistrationDigestHash(
            operator, address(lagrangeService), operatorSignature.salt, operatorSignature.expiry
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        operatorSignature.signature = abi.encodePacked(r, s, v);

        (uint256 startBlock,,, uint256 duration, uint256 freezeDuration,,,) = lagrangeCommittee.committeeParams(chainID);
        vm.roll(startBlock + duration - freezeDuration - 1);
        lagrangeService.register(operator, blsPubKeys, operatorSignature);

        lagrangeCommittee.getEpochNumber(chainID, block.number);
        lagrangeCommittee.isLocked(chainID);

        lagrangeService.subscribe(chainID);

        vm.stopPrank();
    }

    function _addBlsPubKeys(address operator, uint256[2][] memory blsPubKeys, uint32 chainID) internal {
        if (blsPubKeys.length > 0) {
            vm.startPrank(operator);
            // register operator
            (uint256 startBlock,,, uint256 duration, uint256 freezeDuration,,,) =
                lagrangeCommittee.committeeParams(chainID);
            vm.roll(startBlock + duration - freezeDuration - 1);
            lagrangeService.addBlsPubKeys(blsPubKeys);

            vm.stopPrank();
        }
    }

    function testSubscribeChain() public {
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0] = [uint256(1), 2];
        uint256 privateKey = 101;
        address operator = vm.addr(privateKey);

        vm.deal(operator, 1e19);
        // add operator to whitelist
        vm.prank(vm.addr(1));
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
        lagrangeService.register(operator, blsPubKeys, operatorSignature);
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
        blsPubKeysArray[0][0] = [uint256(1), 2];
        blsPubKeysArray[1] = new uint256[2][](1);
        blsPubKeysArray[1][0] = [uint256(2), 3];
        blsPubKeysArray[2] = new uint256[2][](1);
        blsPubKeysArray[2][0] = [uint256(3), 4];

        for (uint256 i; i < OPERATOR_COUNT; i++) {
            _registerOperator(operators[i], privateKeys[i], amounts[i], blsPubKeysArray[i], CHAIN_ID);
        }

        // update the tree
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION + 1);
        lagrangeCommittee.update(CHAIN_ID, 1);

        ILagrangeCommittee.CommitteeData memory cur =
            lagrangeCommittee.getCommittee(CHAIN_ID, START_EPOCH + EPOCH_PERIOD);

        assertEq(cur.leafCount, 3);
        assertEq(cur.root, 0xb36023a1020f51f4b8ba6238d383002481e1dcce915043fecd5d2159513808e3);

        _deposit(operators[0], 1e15);

        vm.roll(START_EPOCH + EPOCH_PERIOD * 2 - FREEZE_DURATION);
        vm.expectRevert("Block number is prior to committee freeze window.");
        lagrangeCommittee.update(CHAIN_ID, 2);

        vm.roll(START_EPOCH + EPOCH_PERIOD * 2 - FREEZE_DURATION + 1);
        lagrangeCommittee.update(CHAIN_ID, 2);

        cur = lagrangeCommittee.getCommittee(CHAIN_ID, START_EPOCH + EPOCH_PERIOD * 2);
        assertEq(cur.leafCount, 3);
        assertEq(cur.root, 0x02f507202eec14a32171bbca5d048778e4c67238b21037a90b90608c71b6276a);
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
        blsPubKeysArray[0][0] = [uint256(1), 2];
        blsPubKeysArray[1] = new uint256[2][](1);
        blsPubKeysArray[1][0] = [uint256(2), 3];
        blsPubKeysArray[2] = new uint256[2][](1);
        blsPubKeysArray[2][0] = [uint256(3), 4];

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
                blsPubKeysArray[i][j] = [_blsKeyCounter++, _blsKeyCounter];
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
        // assertEq(cur.root, 0xb36023a1020f51f4b8ba6238d383002481e1dcce915043fecd5d2159513808e3);
        {
            uint256[2][] memory additionalBlsPubKeys;
            additionalBlsPubKeys = new uint256[2][](1);
            additionalBlsPubKeys[0] = [_blsKeyCounter++, _blsKeyCounter];
            (uint256 startBlock,,, uint256 duration, uint256 freezeDuration,,,) =
                lagrangeCommittee.committeeParams(CHAIN_ID);

            _addBlsPubKeys(operators[0], additionalBlsPubKeys, CHAIN_ID);
            vm.roll(startBlock + duration * 2 - freezeDuration + 1);
            lagrangeCommittee.update(CHAIN_ID, 2);
        }
    }
}
