pragma solidity ^0.8.20;

import "./BaseScript.s.sol";

contract RedeployLGR is BaseScript {
    function run() public {
        _readContracts();
        _redeployService();
        _redeployCommittee();
    }
}
