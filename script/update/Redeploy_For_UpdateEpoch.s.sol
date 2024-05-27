pragma solidity ^0.8.12;
pragma solidity ^0.8.12;

import "./BaseScript.s.sol";

contract Redeploy_For_UpdateEpoch is BaseScript {
    function run() public {
        _readContracts();

        vm.startBroadcast(msg.sender);

        // deploy lagrangeCommittee implementation
        LagrangeCommittee lagrangeCommitteeImp = new LagrangeCommittee(lagrangeService, lagrangeCommittee.voteWeigher());
        // upgrade proxy contract
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))), address(lagrangeCommitteeImp)
        );

        uint256 chainCount = 3; // @note Please set this value exactly

        for (uint256 i = 0; i < chainCount; i++) {
            // Get Chain ID
            uint32 chainID = lagrangeCommittee.chainIDs(0);
            // set first epoch period for CHAIN_ID
            lagrangeCommittee.setFirstEpochPeriod(chainID);
        }

        vm.stopBroadcast();
    }
}
