pragma solidity ^0.8.12;

import "../../script/update/BaseScript.s.sol";
import "../../contracts/interfaces/IVoteWeigher.sol";

interface IEigenStrategy {
    function EIGEN() external view returns (address);
}

contract AddEigenQuorum is BaseScript {
    function run() public {
        _readContracts();

        address eigenStrategy = _getEigenStrategyAddress();

        IVoteWeigher.TokenMultiplier[] memory multipliers = new IVoteWeigher.TokenMultiplier[](1);
        multipliers[0].token = eigenStrategy;
        multipliers[0].multiplier = 1000000000;

        vm.prank(voteWeigher.owner());

        voteWeigher.addQuorumMultiplier(1, multipliers);

        {
            (address _token, uint256 _multiplier) = voteWeigher.quorumMultipliers(1, 0);
            assertEq(_token, eigenStrategy);
            assertEq(_multiplier, 1000000000);
        }
        {
            vm.expectRevert();
            voteWeigher.quorumMultipliers(1, 1);
        }

        console.log(_getEigenTokenAddress());
    }

    function _getEigenStrategyAddress() internal view returns (address) {
        if (block.chainid == 1) {
            return 0xaCB55C530Acdb2849e6d4f36992Cd8c9D50ED8F7;
        } else if (block.chainid == 17000) {
            return 0x43252609bff8a13dFe5e057097f2f45A24387a84;
        }
        return address(0);
    }

    function _getEigenTokenAddress() internal view returns (address) {
        return IEigenStrategy(_getEigenStrategyAddress()).EIGEN();
    }
}