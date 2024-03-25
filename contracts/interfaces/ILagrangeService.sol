// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILagrangeService {
    function addOperatorsToWhitelist(address[] calldata operators) external;

    function removeOperatorsFromWhitelist(address[] calldata operators) external;

    function register(uint256[2][] memory blsPubKeys) external;

    function addBlsPubKeys(uint256[2][] memory additionalBlsPubKeys) external;

    function subscribe(uint32 chainID) external;

    function unsubscribe(uint32 chainID) external;

    function deregister() external;

    function owner() external view returns (address);
}
