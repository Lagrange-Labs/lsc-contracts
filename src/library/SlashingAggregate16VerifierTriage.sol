// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {ISlashingAggregate16VerifierTriage} from "../interfaces/ISlashingAggregate16VerifierTriage.sol";
import {Verifier} from "./slashing_aggregate_16/verifier.sol";

contract SlashingAggregate16VerifierTriage is ISlashingAggregate16VerifierTriage {
    
    mapping(uint256 => address) public verifiers;

    struct proofParams {
        uint[2] a;
        uint[2][2] b;
        uint[2] c;
        uint[6] input;
    }
    
    function setRoute(uint256 routeIndex, address verifierAddress) external {
        verifiers[routeIndex] = verifierAddress;
    }

    function verify(bytes calldata proof, uint256 committeeSize) external override returns (bool,uint[6] memory) {
        uint256 routeIndex = computeRouteIndex(committeeSize);
        address verifierAddress = verifiers[routeIndex];
       
        require(verifierAddress != address(0), "SlashingSingleVerifierTriage: Verifier address not set for committee size specified.");
        
        Verifier verifier = Verifier(verifierAddress);
        proofParams memory params = abi.decode(proof,(proofParams));
        bool result = verifier.verifyProof(params.a, params.b, params.c, params.input);
        
        return (result,params.input);
    }
    
    function computeRouteIndex(uint256 committeeSize) public pure returns (uint256) {
        uint256 routeIndex = 16;
        while (routeIndex < committeeSize) {
            routeIndex = routeIndex * 2;
        }
        return routeIndex;
    }
}

