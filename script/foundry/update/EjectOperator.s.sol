pragma solidity ^0.8.20;

import "./BaseScript.s.sol";

contract EjectOperator is BaseScript {
    address[] private operators;
    address[] private testingOperators;

    function run() public {
        _readContracts();

        // Please add addresses of testing operators
        // testingOperators.push(... operator address here);

        _eject(10, 25); // Eject 25 operators from chain 10
        _revertEpoch(10); // Revert epoch from chain 10
        _eject(8453, 18); // Eject 18 operators from chain 8453
        _revertEpoch(8453); // Revert epoch from chain 8453
    }

    function _eject(uint32 chainId, uint256 operatorCount) internal {
        console.log("Eject operator from chain", chainId);
        address owner = lagrangeCommittee.owner();

        while (operators.length > 0) {
            operators.pop();
        }

        for (uint256 i; i < operatorCount; i++) {
            address operator = lagrangeCommittee.committeeAddrs(chainId, i);
            if (lagrangeCommittee.subscribedChains(chainId, operator)) {
                bool forTesting;
                for (uint256 j; j < testingOperators.length; j++) {
                    if (operator == testingOperators[j]) {
                        forTesting = true;
                        break;
                    }
                }
                if (!forTesting) {
                    operators.push(operator);

                    (, uint8 subscribedChainCount) = lagrangeCommittee.operatorsStatus(operator);
                    console.log("Need to unsubscribe", operator, subscribedChainCount);
                }
            }
        }

        vm.startBroadcast(owner);

        address committeeAddr = address(lagrangeService.committee());
        console.log("committeeAddr", committeeAddr);

        lagrangeService.unsubscribeByAdmin(operators, chainId);
        for (uint256 i; i < operators.length; i++) {
            assertEq(lagrangeCommittee.subscribedChains(chainId, operators[i]), false);
        }

        vm.stopBroadcast();
    }

    function _revertEpoch(uint32 chainId) internal {
        uint256 epochNumber = lagrangeCommittee.updatedEpoch(chainId);
        console.log("Reverting Epoch Number", epochNumber);

        vm.startBroadcast(lagrangeCommittee.owner());

        lagrangeCommittee.revertEpoch(chainId, epochNumber);

        uint256 newEpochNumber = lagrangeCommittee.updatedEpoch(chainId);

        require(newEpochNumber + 1 == epochNumber, "Epoch not reverted");

        vm.stopBroadcast();
    }
}
