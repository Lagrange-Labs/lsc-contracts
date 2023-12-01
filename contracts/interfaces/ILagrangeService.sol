// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILagrangeService {
    function register(bytes memory _blsPubKey, uint32 serveUntilBlock) external;

    function owner() external view returns (address);
}
