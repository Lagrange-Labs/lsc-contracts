// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

interface ISlashingAggregate16VerifierTriage {
    function setRoute(uint256 routeIndex, address verifierAddress) external;
    function verify(bytes calldata payload, uint256 ct) external returns (bool);
}
