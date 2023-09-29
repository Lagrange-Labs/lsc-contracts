// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {ISlashingAggregate16VerifierTriage} from "../interfaces/ISlashingAggregate16VerifierTriage.sol";
import {Verifier} from "./slashing_aggregate_16/verifier.sol";
import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";

contract SlashingAggregate16VerifierTriage is
    ISlashingAggregate16VerifierTriage,
    Initializable,
    OwnableUpgradeable
{
    
    mapping(uint256 => address) public verifiers;

    constructor() {}

    function initialize(
      address initialOwner
    ) external initializer {
        _transferOwnership(initialOwner);
    }

    struct proofParams {
        uint[2] a;
        uint[2][2] b;
        uint[2] c;
        uint[5] input;
    }
    
    function setRoute(uint256 routeIndex, address verifierAddress) external onlyOwner {
        verifiers[routeIndex] = verifierAddress;
    }
    
    function _getChainHeader(EvidenceVerifier.Evidence calldata _evidence) internal returns (uint,uint) {
        bytes memory chainHeader = abi.encode(
            _evidence.blockHash,
            uint256(_evidence.blockNumber),
            uint32(_evidence.chainID)
        );
        
        bytes32 chHash = keccak256(chainHeader);
        bytes16 ch1 = bytes16(chHash);
        bytes16 ch2 = bytes16(chHash << 128);
        uint _chainHeader1 = uint(bytes32(ch1));
        uint _chainHeader2 = uint(bytes32(ch2));
        return (_chainHeader1, _chainHeader2);
    }

    function verify(EvidenceVerifier.Evidence calldata _evidence, uint256 committeeSize) external returns (bool) {
        bytes calldata proof = _evidence.aggProof;
        
        uint256 routeIndex = _computeRouteIndex(committeeSize);
        address verifierAddress = verifiers[routeIndex];
       
        require(verifierAddress != address(0), "SlashingSingleVerifierTriage: Verifier address not set for committee size specified.");
        
        Verifier verifier = Verifier(verifierAddress);
        proofParams memory params = abi.decode(proof,(proofParams));
        
        (uint _chainHeader1, uint _chainHeader2) = _getChainHeader(_evidence);
        
        uint[5] memory input = [
            1,
            uint(_evidence.currentCommitteeRoot),
            uint(_evidence.nextCommitteeRoot),
            _chainHeader1,
            _chainHeader2
        ];

        bool result = verifier.verifyProof(params.a, params.b, params.c, input);
        
        return result;
    }
    
    function _computeRouteIndex(uint256 committeeSize) internal pure returns (uint256) {
        uint256 routeIndex = 1;
        while (routeIndex < committeeSize) {
            routeIndex = routeIndex * 2;
        }
        return routeIndex;
    }
}

