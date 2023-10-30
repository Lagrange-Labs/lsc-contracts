// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";

interface ISlashingAggregateVerifierTriage {
    function setRoute(uint256 routeIndex, address verifierAddress) external;
    function verify(
        bytes memory aggProof,
        bytes32 currentCommitteeRoot,
        bytes32 nextCommitteeRoot,
        bytes32 blockHash,
        uint256 blockNumber,
        uint32 chainID,
        uint256 committeeSize
    ) external returns (bool);
}
