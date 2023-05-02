// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/LagrangeService.sol";

// TODO: add unit tests for LagrangeService, now this implementation is a kind of e2e test
contract LagrangeServiceTest is Test {
    LagrangeService public service;
    address LagrangeServiceAddress = 0x98f07aB2d35638B79582b250C01444cEce0E517A;
    address OperatorAddress = 0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9;

    function setUp() public {
        service = LagrangeService(LagrangeServiceAddress);
    }

    function testFreezeOperator() public {
        // test slashing
        vm.prank(OperatorAddress);
        service.freezeOperator(OperatorAddress);
        require(service.isFrozen(OperatorAddress), "operator should be frozen");
    }
}
