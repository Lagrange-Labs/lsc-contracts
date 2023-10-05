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

        // write deployment data to file
        string memory parent_object = "parent object";
        string memory final_json = vm.serializeAddress(parent_object, "WETH9", address(weth9));
        vm.writeFile("script/output/deployed_weth9.json", final_json);
    }
}
