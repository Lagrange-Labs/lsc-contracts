// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILagrangeCommittee {

    function committeeAdd(uint256 chainID, address addr, uint256 stake, bytes memory _blsPubKey) external;
    
    function setOperatorStatus(uint256 stake, uint32 serveUntilBlock, bool slashed) external;

    function getServeUntilBlock(address operator) external returns (uint32);

    function setSlashed(address operator, bool slashed) external;

    function getSlashed(address operator) external returns (bool);
        
    //function removeCommitteeAddr(uint256 chainID) external;

    function getCommitteeStart(uint256 chainID) external returns (uint256);

    function getCommitteeDuration(uint256 chainID) external returns (uint256);
    
    function verifyBlockNumber(uint comparisonNumber, bytes memory rlpData, bytes32 comparisonBlockHash, uint256 chainID) external view returns (bool);

    function getCommitteeRoot(uint256 chainID, uint256 _epoch) external returns (bytes32);

    function getNextCommitteeRoot(uint256 chainID, uint256 _epoch) external returns (bytes32);

    function add(uint256 chainID) external;
    
    function addAddr(uint256 chainID, address addr) external;

    function remove(uint256 chainID, address addr) external;

    function update(uint256 chainID) external;

    function BLSAssoc(bytes memory blsPubKey) external;

    function addSequencer(address seqAddr) external;
}

