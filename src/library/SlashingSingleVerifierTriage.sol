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

    function _bytes96tobytes48(bytes memory bpk) public returns (bytes[2] memory) {
       require(bpk.length == 96, "BLS public key must be provided in a form that is 96 bytes.");
       bytes[2] memory gxy = [new bytes(48), new bytes(48)];
       for(uint256 i = 0; i < 48; i++) {
           gxy[0][i] = bpk[i];
           gxy[1][i] = bpk[i+48];
       }
       return [abi.encodePacked(gxy[0]), abi.encodePacked(gxy[1])];
    }
    
    function _bytes48toslices(bytes memory b48) internal returns (uint[7] memory) {
        // validate length
        require(b48.length == 48, "Input should be 48 bytes.");
        // resultant slices
        uint[7] memory res;
        // first 32-byte word
        uint256 buffer1;
        // second 32-byte word / remainder
        uint128 buffer2;
        // for cycling from first to second word
        uint56 activeBuffer;
        // load words
        assembly {
            buffer1 := mload(add(b48,0x20))
            buffer2 := mload(add(b48,0x40))
        }
        // define slice
        uint56 slice;
        // set active buffer to first buffer, retire first buffer
        activeBuffer = uint56(buffer1);
        buffer1 = 0;
        for (uint i = 0; i < 7; i++) {
            // assign slice (as active buffer truncated to 56 bits and shifted left for 55-bits with leading zero)
            if (i == 6) {
                slice = activeBuffer >> 2;
            } else {
                slice = activeBuffer >> 1;
                // shift active buffer right by 55 bits
                buffer1 << 55;
                activeBuffer = uint56(buffer1);
                // replace new trailing zeros in first buffer with first 55 bits of second buffer
                activeBuffer += uint56(buffer2 >> 1);
                // shift second buffer right by 55 bits
                buffer2 << 55;
            }
            // add to slices
            res[i] = uint256(slice >> 200);
        }
        return res;
    }

    function _bytes192tobytes48(bytes memory bpk) internal returns (bytes[4] memory) {
       require(bpk.length==192);
       bytes[4] memory res = [new bytes(48), new bytes(48), new bytes(48), new bytes(48)];
       for(uint256 i = 0; i < 48; i++) {
           res[0][i] = bpk[i];
           res[1][i] = bpk[i+48];
           res[2][i] = bpk[i+92];
           res[3][i] = bpk[i+140];
       }
       return res;
    }
    
    function _getBLSPubKeySlices(bytes calldata blsPubKey) internal returns (uint[7][2] memory) {
       //convert bls pubkey bytes (len 96) to bytes[2] (len 48)
       bytes[2] memory gxy = _bytes96tobytes48(blsPubKey);
       //conver to slices
       uint[7][2] memory slices = [_bytes48toslices(gxy[0]),_bytes48toslices(gxy[1])];
       return slices;
    }
    
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

       uint[7][2] memory slices = _getBLSPubKeySlices(blsPubKey);

       // add to input
       uint inc = 1;
       for(uint i = 0; i < 7; i++) {
         for(uint j = 0; j < 2; j++) {
           input[inc] = slices[j][i];
           inc++;
         }
       }
       
       bytes[4] memory sig_slices = _bytes192tobytes48(_evidence.blockSignature);
       for(uint si = 0; si < 4; si++){
           uint[7] memory slice = _bytes48toslices(sig_slices[si]);
           for(uint i = 0; i < 7; i++) {
             input[inc] = slice[i];
             inc++;
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

