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
        lagrangeService.register(CHAIN_ID, blsPubKey, type(uint32).max);

        // deregister operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION);
        lagrangeService.deregister(CHAIN_ID);

        // withdraw tokens from stake manager
        vm.expectRevert("Stake is locked");
        stakeManager.withdraw(address(token), amount);

        vm.roll(START_EPOCH + EPOCH_PERIOD + 1);
        stakeManager.withdraw(address(token), amount);

        vm.stopPrank();
    }

    function testFreezePeriod() public {
        address operator = vm.addr(555);
        bytes memory blsPubKey = new bytes(96);

        vm.startPrank(operator);

        // it should fail because the committee is in freeze period
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION + 1);
        vm.expectRevert("The related chain is in the freeze period");
        lagrangeService.register(CHAIN_ID, blsPubKey, type(uint32).max);
        // register operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION);
        lagrangeService.register(CHAIN_ID, blsPubKey, type(uint32).max);

        // deregister operator should fail due to the freeze period
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION + 1);
        vm.expectRevert("The related chain is in the freeze period");
        lagrangeService.deregister(CHAIN_ID);

        // deregister operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION);
        lagrangeService.deregister(CHAIN_ID);

        vm.stopPrank();
    }
}
