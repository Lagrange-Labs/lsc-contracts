// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Strategy is IStrategy {
    function deposit(IERC20 token, uint256 amount) external returns (uint256) {
        return 0;
    }

    function withdraw(address depositor, IERC20 token, uint256 amountShares) external {}

    function sharesToUnderlying(uint256 amountShares) external returns (uint256) {
        return amountShares;
    }

    function underlyingToShares(uint256 amountUnderlying) external returns (uint256) {
        return amountUnderlying;
    }

    function userUnderlying(address user) external returns (uint256) {
        return 0;
    }

    function sharesToUnderlyingView(uint256 amountShares) external view returns (uint256) {
        return amountShares;
    }

    function underlyingToSharesView(uint256 amountUnderlying) external view returns (uint256) {
        return amountUnderlying;
    }

    function userUnderlyingView(address user) external view returns (uint256) {
        return 0;
    }

    function underlyingToken() external view returns (IERC20) {
        return IERC20(address(0));
    }

    function totalShares() external view returns (uint256) {
        return 0;
    }

    function explanation() external view returns (string memory) {}
}
