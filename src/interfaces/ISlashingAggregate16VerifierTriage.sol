// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";

interface ISlashingAggregate16VerifierTriage {
    function setRoute(uint256 routeIndex, address verifierAddress) external;
    function verify(EvidenceVerifier.Evidence calldata _evidence, uint256 committeeSize) external returns (bool);
}
