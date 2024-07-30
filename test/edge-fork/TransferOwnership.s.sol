pragma solidity ^0.8.20;

import "../../script/update/BaseScript.s.sol";

import "@safe/contracts/interfaces/ISafe.sol";
import {Enum} from "@safe/contracts/libraries/Enum.sol";

import "../../contracts/mock/SafeMock.sol";

contract TransferOwnershipTest is BaseScript {
    function run() public {
        _readContracts();

        ISafe safe;
        uint256 ownerCnt = 5;
        uint256[] memory privateKeys;
        address[] memory owners;
        uint256 threshold = 3;

        (privateKeys, owners) = _getSortedAddresses(ownerCnt);
        // deploySafe
        {
            Safe _safe = new SafeMock();

            _safe.setup(owners, 3, address(0), "", address(0), address(0), 0, payable(address(0)));

            safe = ISafe(address(_safe));
        }

        vm.prank(proxyAdmin.owner());
        proxyAdmin.transferOwnership(address(safe));
        assertEq(proxyAdmin.owner(), address(safe));

        vm.prank(lagrangeService.owner());
        lagrangeService.transferOwnership(address(safe));
        assertEq(lagrangeService.owner(), address(safe));

        vm.prank(lagrangeCommittee.owner());
        lagrangeCommittee.transferOwnership(address(safe));
        assertEq(lagrangeCommittee.owner(), address(safe));

        vm.prank(voteWeigher.owner());
        voteWeigher.transferOwnership(address(safe));
        assertEq(voteWeigher.owner(), address(safe));

        // test transaction
        {
            address[] memory testOperators = new address[](1);
            testOperators[0] = vm.addr(6);
            assertEq(lagrangeService.operatorWhitelist(testOperators[0]), false);

            address to = address(lagrangeService);
            uint256 value = 0;
            bytes memory data = abi.encodeWithSelector(bytes4(keccak256("addOperatorsToWhitelist(address[])")), testOperators);
            uint256 nonce = safe.nonce();

            bytes32 txHash =
                safe.getTransactionHash(to, value, data, Enum.Operation.Call, 0, 0, 0, address(0), address(0), nonce);

            bytes[] memory _signatures = new bytes[](ownerCnt);

            for (uint256 i; i < ownerCnt; i++) {
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[i], txHash);
                _signatures[i] = abi.encodePacked(r, s, v);
            }

            bytes memory signatures;
            for (uint256 i; i < threshold - 1; i++) {
                signatures = bytes.concat(signatures, _signatures[i]);
            }

            vm.expectRevert("GS020");
            safe.execTransaction(
                to, value, data, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), signatures
            );


            signatures = bytes.concat(signatures, _signatures[threshold - 1]);
            safe.execTransaction(
                to, value, data, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), signatures
            );

            assertEq(lagrangeService.operatorWhitelist(testOperators[0]), true);
        }
    }

    function _getSortedAddresses(uint256 cnt) internal view returns (uint256[] memory, address[] memory) {
        uint256[] memory privateKeys = new uint256[](cnt);
        address[] memory addresses = new address[](cnt);

        for (uint256 i; i < cnt; i++) {
            privateKeys[i] = i + 1;
            addresses[i] = vm.addr(privateKeys[i]);
        }

        for (uint256 i; i < cnt; i++) {
            for (uint256 j = i + 1; j < cnt; j++) {
                if (addresses[i] > addresses[j]) {
                    address tmp = addresses[i];
                    addresses[i] = addresses[j];
                    addresses[j] = tmp;

                    uint256 tmp2 = privateKeys[i];
                    privateKeys[i] = privateKeys[j];
                    privateKeys[j] = tmp2;
                }
            }
        }

        return (privateKeys, addresses);
    }

}
