pragma solidity ^0.8.12;

import "./BaseScript.s.sol";

contract TransferOwnership is BaseScript {
    function run() public {
        _readContracts();

        address oldOwner = lagrangeService.owner();
        address newOwner = vm.addr(1); // modify me

        // require(oldOwner == msg.sender);

        vm.startBroadcast(oldOwner);

        proxyAdmin.transferOwnership(newOwner);
        lagrangeService.transferOwnership(newOwner);
        lagrangeCommittee.transferOwnership(newOwner);
        voteWeigher.transferOwnership(newOwner);

        vm.stopBroadcast();

        assertEq(proxyAdmin.owner(), newOwner);
        assertEq(lagrangeService.owner(), newOwner);
        assertEq(lagrangeCommittee.owner(), newOwner);
        assertEq(voteWeigher.owner(), newOwner);
    }
}
