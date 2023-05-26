// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILagrangeCommittee {

    function committeeAdd(uint256 chainID, uint256 stake, bytes memory _blsPubKey) external;
    
    function removeCommitteeAddr(uint256 chainID) external;
    
    function getCommitteeStart(uint256 chainID) external returns (uint256);

    function getCommitteeDuration(uint256 chainID) external returns (uint256);
    
    function verifyBlockNumber(uint comparisonNumber, bytes memory rlpData, bytes32 comparisonBlockHash, uint256 chainID) external view returns (bool);

    function getCommitteeRoot(uint256 chainID, uint256 _epoch) external view returns (bytes32);

    function getNextCommitteeRoot(uint256 chainID, uint256 _epoch) external view returns (bytes32);
}

