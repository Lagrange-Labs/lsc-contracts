// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

interface ISlashingSingleVerifierTriage {
    function setRoute(uint256 routeIndex, address verifierAddress) external;
    function verify(bytes calldata proof, uint256 committeeSize) external returns (bool,uint[75] calldata);
}
