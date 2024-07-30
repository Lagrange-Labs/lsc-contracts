// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LagrangeDeployer.t.sol";

contract RegisterOperatorTest is LagrangeDeployer {
    function testDepositAndWithdraw() public {
        uint256 privateKey = 111;
        address operator = vm.addr(privateKey);
        vm.deal(operator, 1e19);
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0] = _readKnownBlsPubKey(1);
        uint256 amount = 1e15;

        // add operator to whitelist
        vm.prank(vm.addr(adminPrivateKey));
        address[] memory operators = new address[](1);
        operators[0] = operator;
        lagrangeService.addOperatorsToWhitelist(operators);

        vm.startPrank(operator);

        token.deposit{value: amount}();
        token.approve(address(stakeManager), amount);

        // deposit tokens to stake manager
        stakeManager.deposit(IERC20(address(token)), amount);

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
        lagrangeService.register(operator, _calcProofForBLSKeys(operator, blsPubKeys), operatorSignature);
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
        uint256 privateKey = 111;
        address operator = vm.addr(privateKey);
        vm.deal(operator, 1e19);
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0] = _readKnownBlsPubKey(1);
        uint256 amount = 1e16;

        // add operator to whitelist
        vm.prank(vm.addr(adminPrivateKey));
        address[] memory operators = new address[](1);
        operators[0] = operator;
        lagrangeService.addOperatorsToWhitelist(operators);

        vm.startPrank(operator);

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        {
            operatorSignature.expiry = block.timestamp + 60;
            operatorSignature.salt = bytes32(0x0);
            bytes32 digest = avsDirectory.calculateOperatorAVSRegistrationDigestHash(
                operator, address(lagrangeService), operatorSignature.salt, operatorSignature.expiry
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
            operatorSignature.signature = abi.encodePacked(r, s, v);
        }
        // deposit tokens to stake manager
        token.deposit{value: amount}();
        token.approve(address(stakeManager), amount);
        stakeManager.deposit(IERC20(address(token)), amount);

        vm.roll(START_EPOCH + EPOCH_PERIOD - FREEZE_DURATION);
        lagrangeService.register(operator, _calcProofForBLSKeys(operator, blsPubKeys), operatorSignature);

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

        // re-register operator
        vm.roll(START_EPOCH + EPOCH_PERIOD);
        IBLSKeyChecker.BLSKeyWithProof memory keyWithProof = _calcProofForBLSKeys(operator, blsPubKeys);
        vm.expectRevert("BLSKeyChecker.checkBLSKeyWithProof: salt already spent");
        lagrangeService.register(operator, keyWithProof, operatorSignature);

        keyWithProof = _calcProofForBLSKeys(operator, blsPubKeys, bytes32("salt2"));
        vm.expectRevert("AVSDirectory.registerOperatorToAVS: salt already spent");
        lagrangeService.register(operator, keyWithProof, operatorSignature);
        // new operator signature
        {
            operatorSignature.expiry = block.timestamp + 60;
            operatorSignature.salt = bytes32(0x0000000000000000000000000000000000000000000000000000000000000001);
            bytes32 digest = avsDirectory.calculateOperatorAVSRegistrationDigestHash(
                operator, address(lagrangeService), operatorSignature.salt, operatorSignature.expiry
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
            operatorSignature.signature = abi.encodePacked(r, s, v);
        }
        lagrangeService.register(
            operator, _calcProofForBLSKeys(operator, blsPubKeys, bytes32("salt2")), operatorSignature
        );
        lagrangeService.subscribe(CHAIN_ID);

        // unsubscribe and subscribe operator
        lagrangeService.unsubscribe(CHAIN_ID);
        vm.expectRevert("The dedciated chain is while unsubscribing.");
        lagrangeService.subscribe(CHAIN_ID);
        vm.roll(START_EPOCH + EPOCH_PERIOD * 2 + 1);
        lagrangeService.subscribe(CHAIN_ID);

        vm.stopPrank();
    }

    function testEjection_failOnMainnet() public {
        vm.chainId(1);
        address[] memory operators = new address[](1);
        operators[0] = vm.addr(123);

        vm.prank(lagrangeService.owner());
        vm.expectRevert("Only Holesky testnet is allowed");
        lagrangeService.unsubscribeByAdmin(operators, CHAIN_ID);
    }

    function testEjection_failNonOwner() public {
        vm.chainId(17000);
        address[] memory operators = new address[](1);
        operators[0] = vm.addr(123);

        vm.expectRevert("Ownable: caller is not the owner");
        lagrangeService.unsubscribeByAdmin(operators, CHAIN_ID);
    }

    function testEjection_single() public {
        vm.chainId(17000); // holesky testnet
        uint256 privateKey = 111;
        address operator = vm.addr(privateKey);
        address[] memory operators = new address[](1);
        operators[0] = operator;
        uint256 amount = 1e15;
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0] = _readKnownBlsPubKey(1);

        _registerOperator(operator, privateKey, amount, blsPubKeys, CHAIN_ID);

        // check if the operator is subscribed on such chains
        assertEq(lagrangeCommittee.subscribedChains(CHAIN_ID, operator), true);
        (, uint8 subscribedChainCountOrg) = lagrangeCommittee.operatorsStatus(operator);

        vm.prank(lagrangeService.owner());
        lagrangeService.unsubscribeByAdmin(operators, CHAIN_ID);

        // check if the operator is subscribed on such chains
        assertEq(lagrangeCommittee.subscribedChains(CHAIN_ID, operator), false);
        (, uint8 subscribedChainCountNew) = lagrangeCommittee.operatorsStatus(operator);
        assertEq(subscribedChainCountNew + 1, subscribedChainCountOrg);
    }

    function testEjection_multiple() public {
        vm.chainId(17000); // holesky testnet
        uint256 count = 3;
        uint256[] memory privateKeys = new uint256[](3);
        privateKeys[0] = 111;
        privateKeys[1] = 222;
        privateKeys[2] = 333;
        address[] memory operators = new address[](3);
        for (uint256 i; i < count; i++) {
            operators[i] = vm.addr(privateKeys[i]);
        }

        uint8[] memory subscribedChainCountOrg = new uint8[](3);

        uint256 _blsKeyCounter = 1;

        for (uint256 i; i < count; i++) {
            uint256 amount = 1e15;
            uint256[2][] memory blsPubKeys = new uint256[2][](1);
            blsPubKeys[0] = _readKnownBlsPubKey(_blsKeyCounter++);

            _registerOperator(operators[i], privateKeys[i], amount, blsPubKeys, CHAIN_ID);

            // check if the operator is subscribed on such chains
            assertEq(lagrangeCommittee.subscribedChains(CHAIN_ID, operators[i]), true);
            (, uint8 _subscribedChainCountOrg) = lagrangeCommittee.operatorsStatus(operators[i]);
            subscribedChainCountOrg[i] = _subscribedChainCountOrg;
        }

        vm.prank(lagrangeService.owner());
        lagrangeService.unsubscribeByAdmin(operators, CHAIN_ID);

        for (uint256 i; i < count; i++) {
            // check if the operator is subscribed on such chains
            assertEq(lagrangeCommittee.subscribedChains(CHAIN_ID, operators[i]), false);
            (, uint8 subscribedChainCountNew) = lagrangeCommittee.operatorsStatus(operators[i]);
            assertEq(subscribedChainCountNew + 1, subscribedChainCountOrg[i]);
        }
    }

    function testEjection_resubscribe() public {
        vm.chainId(17000); // holesky testnet
        uint256 privateKey = 111;
        address operator = vm.addr(privateKey);
        address[] memory operators = new address[](1);
        operators[0] = operator;
        uint256 amount = 1e15;
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0] = _readKnownBlsPubKey(1);

        _registerOperator(operator, privateKey, amount, blsPubKeys, CHAIN_ID);
        vm.prank(operator);
        lagrangeService.subscribe(CHAIN_ID + 1);

        // check if the operator is subscribed on such chains
        assertEq(lagrangeCommittee.subscribedChains(CHAIN_ID, operator), true);
        assertEq(lagrangeCommittee.subscribedChains(CHAIN_ID + 1, operator), true);

        vm.prank(lagrangeService.owner());
        lagrangeService.unsubscribeByAdmin(operators, CHAIN_ID);

        // check if the operator is subscribed on such chains
        assertEq(lagrangeCommittee.subscribedChains(CHAIN_ID, operator), false);
        assertEq(lagrangeCommittee.subscribedChains(CHAIN_ID + 1, operator), true); // this chain should be still subscribed

        // free to subscribe again
        vm.prank(operator);
        lagrangeService.subscribe(CHAIN_ID);
        assertEq(lagrangeCommittee.subscribedChains(CHAIN_ID, operator), true);

        // deregister is possible, after ejected
        vm.prank(lagrangeService.owner());
        lagrangeService.unsubscribeByAdmin(operators, CHAIN_ID);
        vm.prank(lagrangeService.owner());
        lagrangeService.unsubscribeByAdmin(operators, CHAIN_ID + 1);
        vm.prank(operator);
        lagrangeService.deregister();
    }
}
