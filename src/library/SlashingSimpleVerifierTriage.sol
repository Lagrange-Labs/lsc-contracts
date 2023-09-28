// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

contract SlashingSimpleVerifierTriage is ISlashingSimpleVerifierTriage {
    
    mapping(uint256 => address) public verifiers;
    
    function setRoute(uint256 routeIndex, address verifierAddress) external {
        verifiers[routeIndex] = verifierAddress;
    }
    
    function verify(bytes calldata proof, uint256 committeeSize) external override returns (bool,uint[75]) {
        uint256 routeIndex = computeRouteIndex(committeeSize);
        address verifierAddress = verifiers[routeIndex];
        
        require(verifierAddress != address(0), "SlashingSimpleVerifierTriage: Verifier address not set for committee size specified.");
        
        bytes memory callData = abi.encodeWithSignature("verifyProofWithInput(bytes)", proof);
        (bool success, bytes memory result) = verifierAddress.call(callData);
        
        require(success, "SlashingSimpleVerifierTriage: verifyProofWithInput() call failed.");
        
        return abi.decode(result, (bool,uint[75]));
    }
    
    function computeRouteIndex(uint256 committeeSize) public pure returns (uint256) {
        uint256 routeIndex = 16;
        while (routeIndex < committeeSize) {
            routeIndex = routeIndex * 2;
        }
        return routeIndex;
    }
}

