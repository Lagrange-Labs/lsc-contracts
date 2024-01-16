// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILagrangeService {
    function register(uint256[2] memory _blsPubKey, uint32 serveUntilBlock) external;

    function owner() external view returns (address);
}
