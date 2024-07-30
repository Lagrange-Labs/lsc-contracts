pragma solidity ^0.8.20;

import "./BaseScript.s.sol";

contract RemoveQuorum is BaseScript {
    function run() public {
        deployDataPath = string(bytes("script/output/deployed_lgr.json"));
        _readContracts();

        vm.startBroadcast(msg.sender);

        voteWeigher.removeQuorumMultiplier(0);

        vm.stopBroadcast();
    }
}
