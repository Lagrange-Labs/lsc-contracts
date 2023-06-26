pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {WETH9} from "src/mock/WETH9.sol";

contract DeployWETH9 is Script, Test {
    function run() public {
        // deploy WETH9
        vm.broadcast(msg.sender);
        WETH9 weth9 = new WETH9();
        weth9.initialize();
        console.logAddress(address(weth9));
    }
}
