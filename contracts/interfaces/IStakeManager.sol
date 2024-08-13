// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStakeManager {
    function deposit(IERC20 token, uint256 amount) external;

    function withdraw(IERC20 token, uint256 amount) external;

    function lockStakeUntil(address operator, uint256 serveUntilBlock) external;

    function operatorShares(address operator, address token) external view returns (uint256);

    // future use for slashing
    function freezeOperator(address toBeFrozen) external;

    function resetFrozenStatus(address[] calldata frozenAddresses) external;
}
