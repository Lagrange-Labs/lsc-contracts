pragma solidity ^0.8.12;

import "./BaseScript.s.sol";

contract RedeployLGR is BaseScript {
    function run() public {
        _readContracts();

        vm.startBroadcast(msg.sender);

        // deploy implementation contracts
        LagrangeCommittee lagrangeCommitteeImp = new LagrangeCommittee(lagrangeService, lagrangeCommittee.voteWeigher());
        LagrangeService lagrangeServiceImp = new LagrangeService(
            lagrangeCommittee,
            lagrangeService.stakeManager(),
            address(lagrangeService.avsDirectory()),
            lagrangeService.voteWeigher()
        );

        // upgrade proxy contracts
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))), address(lagrangeCommitteeImp)
        );
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(address(lagrangeService))), address(lagrangeServiceImp));

        vm.stopBroadcast();
    }
}
