// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILagrangeCommittee {
    struct OperatorStatus {
        uint256 amount;
        uint32 serveUntilBlock;
        bool slashed;
    }

    function getServeUntilBlock(address operator) external returns (uint32);
    
    function setSlashed(address operator, bool slashed) external;
    
    function getSlashed(address operator) external returns (bool);
    
    //function removeCommitteeAddr(uint256 chainID) external;

    function getCommittee(uint256 chainID, uint256 epochNumber) external returns (uint256);

    function add(uint256 chainID, bytes memory blsPubKey, uint256 stake, uint32 serveUntilBlock) external;
    
    function remove(uint256 chainID, address addr) external;

    function update(uint256 chainID) external;

    function addSequencer(address seqAddr) external;
}

