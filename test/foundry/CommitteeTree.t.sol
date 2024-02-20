// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LagrangeDeployer.t.sol";

contract CommitteeTreeTest is LagrangeDeployer {
    function _deposit(address operator, uint256 amount) internal {
        vm.startPrank(operator);

        token.deposit{value: amount}();
        token.approve(address(stakeManager), amount);

        // deposit tokens to stake manager
        stakeManager.deposit(IERC20(address(token)), amount);

        vm.stopPrank();
    }

    function _registerOperator(address operator, uint256 amount, uint256[2] memory blsPubKey) internal {
        vm.deal(operator, 1e19);
        // add operator to whitelist
        vm.prank(vm.addr(1));
        address[] memory operators = new address[](1);
        operators[0] = operator;
        lagrangeService.addOperatorsToWhitelist(operators);

        _deposit(operator, amount);

        vm.startPrank(operator);
        // register operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION - 1);
        lagrangeService.register(blsPubKey);
        lagrangeService.subscribe(CHAIN_ID);

        vm.stopPrank();
    }

    function testSubscribeChain() public {
        uint256[2] memory blsPubKey;
        blsPubKey = [uint256(1), 2];
        address operator = vm.addr(101);

        vm.deal(operator, 1e19);
        // add operator to whitelist
        vm.prank(vm.addr(1));
        address[] memory operators = new address[](1);
        operators[0] = operator;
        lagrangeService.addOperatorsToWhitelist(operators);

        _deposit(operator, 1e5); // which is less than the dividend threshold, the voting power is 0

        vm.startPrank(operator);

        // register operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION - 1);
        lagrangeService.register(blsPubKey);
        // subscribe chain
        vm.expectRevert("The operator has no voting power.");
        lagrangeService.subscribe(CHAIN_ID);
        vm.stopPrank();

        _deposit(operator, 1e9); // now the voting power is 1

        vm.startPrank(operator);
        lagrangeService.subscribe(CHAIN_ID);
        vm.stopPrank();
    }

    function testTreeConstruct() public {
        uint256[2] memory blsPubKey;
        blsPubKey = [uint256(1), 2];
        _registerOperator(vm.addr(111), 1e15, blsPubKey);
        blsPubKey = [uint256(2), 3];
        _registerOperator(vm.addr(222), 2e15, blsPubKey);
        blsPubKey = [uint256(3), 4];
        _registerOperator(vm.addr(333), 3e15, blsPubKey);

        // update the tree
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION + 1);
        lagrangeCommittee.update(CHAIN_ID, 1);

        (ILagrangeCommittee.CommitteeData memory cur, bytes32 next) =
            lagrangeCommittee.getCommittee(CHAIN_ID, START_EPOCH + EPOCH_PERIOD);

        assertEq(cur.totalVotingPower, 6e6);
        assertEq(cur.leafCount, 3);
        assertEq(cur.root, 0xb36023a1020f51f4b8ba6238d383002481e1dcce915043fecd5d2159513808e3);
        assertEq(cur.root, next);

        // update the amount of operator 1
        _deposit(vm.addr(111), 1e15);
        vm.expectRevert("The dedicated chain is locked.");
        vm.roll(START_EPOCH + EPOCH_PERIOD * 2 - FREEZE_DURATION + 1);
        lagrangeCommittee.updateOperatorAmount(vm.addr(111), CHAIN_ID);

        vm.roll(START_EPOCH + EPOCH_PERIOD * 2 - FREEZE_DURATION);
        // anoymous call
        lagrangeCommittee.updateOperatorAmount(vm.addr(111), CHAIN_ID);
        vm.expectRevert("Block number is prior to committee freeze window.");
        lagrangeCommittee.update(CHAIN_ID, 2);

        vm.roll(START_EPOCH + EPOCH_PERIOD * 2 - FREEZE_DURATION + 1);
        lagrangeCommittee.update(CHAIN_ID, 2);

        (cur, next) = lagrangeCommittee.getCommittee(CHAIN_ID, START_EPOCH + EPOCH_PERIOD * 2);
        assertEq(cur.totalVotingPower, 7e6);
        assertEq(cur.leafCount, 3);
        assertEq(cur.root, 0x02f507202eec14a32171bbca5d048778e4c67238b21037a90b90608c71b6276a);
        assertEq(cur.root, next);
    }
}
