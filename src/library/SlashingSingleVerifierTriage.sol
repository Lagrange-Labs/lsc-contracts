// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {ISlashingSingleVerifierTriage} from "../interfaces/ISlashingSingleVerifierTriage.sol";
import {Verifier} from "./slashing_single/verifier.sol";
import {EvidenceVerifier} from "./EvidenceVerifier.sol";

contract SlashingSingleVerifierTriage is
    ISlashingSingleVerifierTriage,
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
        uint[75] input;
    }
    
    function setRoute(uint256 routeIndex, address verifierAddress) external onlyOwner {
        verifiers[routeIndex] = verifierAddress;
    }
/*
    function getSigningRoot(bytes32 blockHash, uint256 blockNumber, uint32 chainID, bytes32 currentCommittee, bytes32 nextCommittee) external view returns (bytes32) {
        bytes memory chainHeader = abi.encodePacked(
            blockHash,
            uint256(blockNumber),
            uint32(chainID),
        );
    }
*/
    
    function _getChainHeader(bytes32 blockHash, uint256 blockNumber, uint32 chainID) internal view returns (uint[32] memory) {
        bytes memory chainHeader = abi.encodePacked(
            blockHash,
            uint256(blockNumber),
            uint32(chainID)
        );
        
        bytes32 chHash = keccak256(chainHeader);
        
        uint256[32] memory signingRoot;
        for (uint256 i = 0; i < 32; i++) {
            signingRoot[i] = uint(uint8(bytes1(chHash[i]))) << 248;
        }
        return signingRoot;
    }
    

    function _bytes192tobytes48(bytes memory bpk) internal returns (bytes[4] memory) {
       bytes[4] memory res;
       for(uint256 i = 0; i < 48; i++) {
           res[0][i] = bpk[i];
           res[1][i] = bpk[i+48];
           res[2][i] = bpk[i+92];
           res[3][i] = bpk[i+240];
       }
       return res;
    }
    
    function _bytes96tobytes48(bytes memory bpk) internal returns (bytes[2] memory) {
       bytes[2] memory gxy;
       for(uint256 i = 0; i < 48; i++) {
           gxy[0][i] = bpk[i];
           gxy[1][i] = bpk[i+48];
       }
       return gxy;
    }
    
    function _bytes48(bytes memory b) internal returns (bytes1[48] memory) {
        bytes1[48] memory res;
        for(uint i = 0; i < 48; i++) {
           res[i] = b[i];
        }
        return res;
    }
    
    function _bytes48toslices(bytes[2] memory gxy) internal returns (uint[7][2] memory) {
       uint[7][2] memory slices;
       for(uint256 i = 0; i < 2; i++) {
           bytes1[48] memory coord = _bytes48(gxy[i]);
           for(uint256 j = 0; j < 7; j++) {
               bytes1[48] memory slice = coord >> ((6-j) * 55);
               slices[j][i] = uint256(slice) & ((1 << 55) - 1);
           }
       }
       return slices;
    }

function _uint2array(uint base, uint slices, uint x) internal returns (uint[] memory) {
	uint mod = 1;
	for (uint idx = 0; idx < base; idx++) {
		mod = mod * 2;
	}
	uint[slices] memory ret;
	uint x_temp = x;
	for (uint idx = 0; idx < slices; idx++) {
		ret[idx]= x_temp % mod;
		x_temp /= mod;
	}
	return ret;
}    
    event Here(uint256[3]);
    
    function verify(
      EvidenceVerifier.Evidence memory _evidence,
      bytes calldata blsPubKey,
      uint256 committeeSize
    ) external returns (bool) {
        address verifierAddress = verifiers[_computeRouteIndex(committeeSize)];
       
        require(verifierAddress != address(0), "SlashingSingleVerifierTriage: Verifier address not set for committee size specified.");
        
        Verifier verifier = Verifier(verifierAddress);
        proofParams memory params = abi.decode(_evidence.sigProof,(proofParams));
        
        uint[75] memory input;
        input[0] = 1;

       //convert bytes (len 96) to bytes[2] (len 48)
       bytes[2] memory gxy = _bytes96tobytes48(blsPubKey);
       uint[7][2] memory slices = _bytes48toslices(gxy);
       
       uint inc = 1;
       for(uint i = 0; i < 7; i++) {
         for(uint j = 0; j < 2; j++) {
           input[inc] = slices[i][j];
           inc++;
         }
       }
       
       bytes[4] memory sig_slices = _bytes192tobytes48(_evidence.blockSignature);
       for(uint si = 0; si < 4; si++){
         uint[7][2] memory slice = _bytes48toslices(sig_slices[si]);
         for(uint i = 0; i < 7; i++) {
           for(uint j = 0; j < 2; j++) {
             input[inc] = slices[i][j];
             inc++;
           }
         }
       }

        uint256[32] memory signingRoot = _getChainHeader(_evidence.blockHash,_evidence.blockNumber,_evidence.chainID);
        for(uint256 i = 43; i < 75; i++) {
            input[i] = signingRoot[i-43];
        }
        
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

