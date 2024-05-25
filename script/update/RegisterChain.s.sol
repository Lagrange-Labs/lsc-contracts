pragma solidity ^0.8.12;

import "./BaseScript.s.sol";

contract RegisterChain is BaseScript {
    function run() public {
        _readContracts();

        address owner = lagrangeCommittee.owner();

        vm.startBroadcast(owner);

        // need to put values manually here
        uint32 chainId = 42161;
        uint256 epochPeriod = 1500;
        uint256 freezeDuration = 150;
        uint256 genesisBlock = 19920587;
        uint96 maxWeight = 10000000000000;
        uint96 minWeight = 1000000000;
        uint8 quorumNumber = 0;

        // Check if it is not registered yet
        {
            (,,,,,,, uint96 _oldMaxWeight) = lagrangeCommittee.committeeParams(chainId);
            assertEq(_oldMaxWeight, 0);
        }

        // Register chain
        lagrangeCommittee.registerChain(
            chainId, genesisBlock, epochPeriod, freezeDuration, quorumNumber, minWeight, maxWeight
        );

        // Check if it is registered correctly
        {
            (,,,,,,, uint96 _newMaxWeight) = lagrangeCommittee.committeeParams(chainId);
            assertEq(_newMaxWeight, maxWeight);
        }

        vm.stopBroadcast();
    }
}
