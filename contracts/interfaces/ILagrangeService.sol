// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";

interface ILagrangeService {
    function addOperatorsToWhitelist(address[] calldata operators) external;

    function removeOperatorsFromWhitelist(address[] calldata operators) external;

    function register(
        uint256[2][] memory blsPubKeys,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    function addBlsPubKeys(uint256[2][] memory additionalBlsPubKeys) external;

    function subscribe(uint32 chainID) external;

    function unsubscribe(uint32 chainID) external;

    function deregister() external;

    function owner() external view returns (address);
}
