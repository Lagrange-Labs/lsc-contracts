// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";

interface ILagrangeService {
    function addOperatorsToWhitelist(address[] calldata operators) external;

    function removeOperatorsFromWhitelist(address[] calldata operators) external;

    function register(
        address signAddress,
        uint256[2][] memory blsPubKeys,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    function addBlsPubKeys(uint256[2][] memory additionalBlsPubKeys) external;

    function updateBlsPubKey(uint32 index, uint256[2] memory blsPubKey) external;

    function removeBlsPubKeys(uint32[] memory indices) external;

    function updateSignAddress(address newSignAddress) external;

    function subscribe(uint32 chainID) external;

    function unsubscribe(uint32 chainID) external;

    function unsubscribeByAdmin(address operator, uint32 chainID) external;

    function deregister() external;

    function owner() external view returns (address);
}
