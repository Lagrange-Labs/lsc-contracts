// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILagrangeService {
    function addOperatorToWhitelist(address operator) external;

    function removeOperatorFromWhitelist(address operator) external;

    function register(uint256[2] memory _blsPubKey) external;

    function subscribe(uint32 chainID) external;

    function unsubscribe(uint32 chainID) external;

    function deregister() external;

    function owner() external view returns (address);
}
