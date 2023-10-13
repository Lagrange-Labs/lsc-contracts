// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {ISlashingAggregateVerifierTriage} from "../interfaces/ISlashingAggregateVerifierTriage.sol";
import {Verifier} from "./slashing_aggregate_16/verifier.sol";
import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";

contract SlashingAggregateVerifierTriage is
    ISlashingAggregateVerifierTriage,
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
    
    function _getChainHeader(bytes32 blockHash, uint256 blockNumber, uint32 chainID) internal view returns (uint,uint) {
        uint _chainHeader1;
        uint _chainHeader2;

        bytes memory chainHeader = abi.encodePacked(
            blockHash,
            uint256(blockNumber),
            uint32(chainID)
        );
        
        bytes32 chHash = keccak256(chainHeader);
        bytes16 ch1 = bytes16(chHash);
        bytes16 ch2 = bytes16(chHash << 128);
        
        bytes32 _ch1 = bytes32(ch1) >> 128;
        bytes32 _ch2 = bytes32(ch2) >> 128;
        
        _chainHeader1 = uint256(_ch1);
        _chainHeader2 = uint256(_ch2);
        
        return (_chainHeader1, _chainHeader2);
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
       
        require(verifierAddress != address(0), "SlashingSingleVerifierTriage: Verifier address not set for committee size specified.");
        
        Verifier verifier = Verifier(verifierAddress);
        proofParams memory params = abi.decode(aggProof,(proofParams));
        
        (uint _chainHeader1, uint _chainHeader2) = _getChainHeader(blockHash,blockNumber,chainID);
        
        uint[5] memory input = [
            1,
            uint(currentCommitteeRoot),
            uint(nextCommitteeRoot),
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

