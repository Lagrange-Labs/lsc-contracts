// SPDX-License-Identifier: BUSL-1.1

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.20;

import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Strategy is IStrategy {
    function deposit(IERC20 /*token*/, uint256 /*amount*/) external pure returns (uint256) {
        return 0;
    }

    function withdraw(address /*depositor*/, IERC20 /*token*/, uint256 /*amountShares*/) external pure {}

    function sharesToUnderlying(uint256 amountShares) external pure returns (uint256) {
        return amountShares;
    }

    function underlyingToShares(uint256 amountUnderlying) external pure returns (uint256) {
        return amountUnderlying;
    }

    function userUnderlying(address /*user*/) external pure returns (uint256) {
        return 0;
    }

    function shares(address /*user*/) external pure returns (uint256) {
        return 0;
    }

    function sharesToUnderlyingView(uint256 amountShares) external pure returns (uint256) {
        return amountShares;
    }

    function underlyingToSharesView(uint256 amountUnderlying) external pure returns (uint256) {
        return amountUnderlying;
    }

    function userUnderlyingView(address /*user*/) external pure returns (uint256) {
        return 0;
    }

    function underlyingToken() external pure returns (IERC20) {
        return IERC20(address(0));
    }

    function totalShares() external pure returns (uint256) {
        return 0;
    }

    function explanation() external pure returns (string memory) {}
}
// forgefmt: disable-end
