// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";

interface ISlashingSingleVerifierTriage {
    function setRoute(uint256 routeIndex, address verifierAddress) external;
    
    function verify(
      EvidenceVerifier.Evidence calldata _evidence,
      bytes memory blsPubKey,
      uint256 committeeSize
    ) external returns (bool);
}
