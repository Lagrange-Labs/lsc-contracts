pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategyManager} from "eigenlayer-contracts/src/contracts/interfaces/IStrategyManager.sol";
import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import "../../script/update/BaseScript.s.sol";
import "../../contracts/interfaces/IVoteWeigher.sol";

interface IEigenStrategy is IStrategy {
    function EIGEN() external view returns (address);

    function strategyManager() external view returns (address);
}

contract AddEigenQuorum is BaseScript {
    function run() public {
        _readContracts();

        IEigenStrategy eigenStrategy = _getEigenStrategyAddress();

        // Register Quorum to VoteWeigher
        uint96 multiplier = 1000000000;
        uint8 quorumNumber = 1;

        IVoteWeigher.TokenMultiplier[] memory multipliers = new IVoteWeigher.TokenMultiplier[](1);
        multipliers[0].token = address(eigenStrategy);
        multipliers[0].multiplier = multiplier;

        vm.prank(voteWeigher.owner());
        voteWeigher.addQuorumMultiplier(quorumNumber, multipliers);

        // Check if registered correctly
        {
            // calling multiplier index 0 should return above value
            (address _token, uint256 _multiplier) = voteWeigher.quorumMultipliers(quorumNumber, 0);
            assertEq(_token, address(eigenStrategy));
            assertEq(_multiplier, multiplier);

            // calling multiplier index 1 should revert
            vm.expectRevert();
            voteWeigher.quorumMultipliers(quorumNumber, 1);
        }
        

        // Get bEigenToken & strategyManager
        IERC20 bEigenToken = _getBEigenToken();
        IStrategyManager strategyManager = IStrategyManager(eigenStrategy.strategyManager());

        address operator = vm.addr(9876543210); // random address for testing        
        uint256 amount = 100 * 1e18;

        // airdrop bEigenToken to operator
        _airdropBEigenToken(operator, amount);
        
        vm.startPrank(operator);

        // deposit to strategyManager
        bEigenToken.approve(address(strategyManager), amount);
        strategyManager.depositIntoStrategy(IStrategy(address(eigenStrategy)), bEigenToken, amount);
        
        // register to delegation
        IDelegationManager delegation = strategyManager.delegation();
        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            earningsReceiver: operator,
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });        
        delegation.registerAsOperator(operatorDetails, "");

        // check if weightOfOperator returns correct
        uint96 weight = voteWeigher.weightOfOperator(quorumNumber, operator);
        uint96 expectedWeight = uint96((uint256(multiplier) * amount) / 1e18);
        assertEq(weight, expectedWeight, "Incorrect weight returned");
        
        vm.stopPrank();
    }

    function _getEigenStrategyAddress() internal view returns (IEigenStrategy) {
        if (block.chainid == 1) {
            return IEigenStrategy(address(0xaCB55C530Acdb2849e6d4f36992Cd8c9D50ED8F7));
        } else if (block.chainid == 17000) {
            return IEigenStrategy(address(0x43252609bff8a13dFe5e057097f2f45A24387a84));
        }
        return IEigenStrategy(address(0));
    }

    function _getEigenToken() internal view returns (IERC20) {
        return IERC20(_getEigenStrategyAddress().EIGEN());
    }

    function _getBEigenToken() internal view returns (IERC20) {
        return IERC20(_getEigenStrategyAddress().underlyingToken());
    }

    function _airdropBEigenToken(address to, uint256 amount) internal {
        IERC20 bEigenToken = _getBEigenToken();
        address airdropFrom = address(_getEigenToken());

        vm.prank(airdropFrom);
        bEigenToken.transfer(to, amount);
    }
}