// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {ISlashingAggregateVerifierTriage} from "../interfaces/ISlashingAggregateVerifierTriage.sol";
import {ISlashingAggregateVerifier} from "../interfaces/ISlashingAggregateVerifier.sol";
import {ISlashingSingleVerifier} from "../interfaces/ISlashingSingleVerifier.sol";
import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";

contract SlashingAggregateVerifierTriage is ISlashingAggregateVerifierTriage, Initializable, OwnableUpgradeable, EvidenceVerifier {
    mapping(uint256 => address) public verifiers;

    constructor (address verifierAddress) EvidenceVerifier(address(0)) public {
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    struct proofParams {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
        uint256[5] input;
    }

    function setRoute(uint256 routeIndex, address verifierAddress) external onlyOwner {
        verifiers[routeIndex] = verifierAddress;
    }

    function verify(
        bytes calldata aggProof,
        bytes32 currentCommitteeRoot,
        bytes32 nextCommitteeRoot,
        bytes32 blockHash,
        uint256 blockNumber,
        uint32 chainID,
        uint256 committeeSize
    ) external view returns (bool) {
        uint256 routeIndex = _computeRouteIndex(committeeSize);
        address verifierAddress = verifiers[routeIndex];

        require(
            verifierAddress != address(0),
            "SlashingSingleVerifierTriage: Verifier address not set for committee size specified."
        );

        ISlashingAggregateVerifier verifier = ISlashingAggregateVerifier(verifierAddress);
        proofParams memory params = abi.decode(aggProof, (proofParams));

        (uint256 _chainHeader1, uint256 _chainHeader2) = _getChainHeader(blockHash, blockNumber, chainID);

        uint256[5] memory input =
            [1, uint256(currentCommitteeRoot), uint256(nextCommitteeRoot), _chainHeader1, _chainHeader2];

        bool result = verifier.verifyProof(params.a, params.b, params.c, input);

        return result;
    }
}
