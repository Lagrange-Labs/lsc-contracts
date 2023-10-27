// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "./LagrangeDeployer.t.sol";

contract RegisterOperatorTest is LagrangeDeployer {
    function testDepositAndWithdraw() public {
        address operator = vm.addr(333);
        vm.deal(operator, 1e19);
        bytes memory blsPubKey = new bytes(96);
        uint256 amount = 1e15;

        vm.startPrank(operator);

        token.deposit{value: amount}();
        token.approve(address(stakeManager), amount);

        // deposit tokens to stake manager
        stakeManager.deposit(address(token), amount);

        // register operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION - 1);
        lagrangeService.register(blsPubKey, type(uint32).max);
        lagrangeService.subscribe(CHAIN_ID);
        lagrangeService.subscribe(CHAIN_ID + 1);

        // unsubscribe operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION);
        lagrangeService.unsubscribe(CHAIN_ID);

        // deregister operator
        vm.expectRevert("The operator is not able to deregister");
        lagrangeService.deregister();

        // unsubscribe operator
        vm.roll(START_EPOCH + EPOCH_PERIOD * 2 - FREEZE_DURATION * 2);
        lagrangeService.unsubscribe(CHAIN_ID + 1);

        // deregister operator
        lagrangeService.deregister();

        // withdraw tokens from stake manager
        vm.roll(START_EPOCH + EPOCH_PERIOD * 2);
        vm.expectRevert("Stake is locked");
        stakeManager.withdraw(address(token), amount);

        vm.roll(START_EPOCH + EPOCH_PERIOD * 2 + 1);
        stakeManager.withdraw(address(token), amount);

        vm.stopPrank();
    }

    function testFreezePeriod() public {
        address operator = vm.addr(555);
        bytes memory blsPubKey = new bytes(96);

        vm.startPrank(operator);

        // it should fail because the committee is in freeze period
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION + 1);
        lagrangeService.register(blsPubKey, type(uint32).max);
        vm.expectRevert("The dedicated chain is locked.");
        lagrangeService.subscribe(CHAIN_ID);

        // register operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION);
        lagrangeService.register(blsPubKey, type(uint32).max);
        lagrangeService.subscribe(CHAIN_ID);

        // deregister operator should fail due to the freeze period
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION + 1);
        vm.expectRevert("The dedicated chain is locked.");
        lagrangeService.unsubscribe(CHAIN_ID);

        // deregister operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION);
        lagrangeService.unsubscribe(CHAIN_ID);
        lagrangeService.deregister();

        vm.stopPrank();
    }
}
