// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LagrangeDeployer.t.sol";

contract RegisterOperatorTest is LagrangeDeployer {
    function testDepositAndWithdraw() public {
        uint256 privateKey = 333;
        address operator = vm.addr(privateKey);
        vm.deal(operator, 1e19);
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0][0] = 1;
        blsPubKeys[0][1] = 2;
        uint256 amount = 1e15;

        // add operator to whitelist
        vm.prank(vm.addr(1));
        address[] memory operators = new address[](1);
        operators[0] = operator;
        lagrangeService.addOperatorsToWhitelist(operators);

        vm.startPrank(operator);

        token.deposit{value: amount}();
        token.approve(address(stakeManager), amount);

        // deposit tokens to stake manager
        stakeManager.deposit(IERC20(address(token)), amount);

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature; // TODO: need to generate signature
        operatorSignature.expiry = block.timestamp + 60;
        operatorSignature.salt = bytes32(0x0);
        bytes32 digest = avsDirectory.calculateOperatorAVSRegistrationDigestHash(
            operator, address(lagrangeService), operatorSignature.salt, operatorSignature.expiry
        );

        console.logBytes32(digest);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        operatorSignature.signature = abi.encodePacked(r, s, v);

        // register operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION - 1);
        lagrangeService.register(blsPubKeys, operatorSignature);
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
        stakeManager.withdraw(IERC20(address(token)), amount);

        vm.roll(START_EPOCH + EPOCH_PERIOD * 2 + 1);
        stakeManager.withdraw(IERC20(address(token)), amount);

        vm.stopPrank();
    }

    function testFreezePeriod() public {
        address operator = vm.addr(555);
        vm.deal(operator, 1e19);
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0][0] = 1;
        blsPubKeys[0][1] = 2;
        uint256 amount = 1e16;

        // add operator to whitelist
        vm.prank(vm.addr(1));
        address[] memory operators = new address[](1);
        operators[0] = operator;
        lagrangeService.addOperatorsToWhitelist(operators);

        vm.startPrank(operator);

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature; // TODO: need to generate signature

        // deposit tokens to stake manager
        token.deposit{value: amount}();
        token.approve(address(stakeManager), amount);
        stakeManager.deposit(IERC20(address(token)), amount);

        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION);
        lagrangeService.register(blsPubKeys, operatorSignature);

        // it should fail because the committee is in freeze period
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION + 1);
        vm.expectRevert("The dedicated chain is locked.");
        lagrangeService.subscribe(CHAIN_ID);

        // register operator
        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION);
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
