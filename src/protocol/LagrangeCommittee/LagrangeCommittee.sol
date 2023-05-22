// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../../hermez/HermezHelpers.sol";

import "../../interfaces/LagrangeCommittee/ILagrangeCommittee.sol";

import "solidity-rlp/contracts/Helper.sol";

contract LagrangeCommittee is Initializable, OwnableUpgradeable, HermezHelpers, ILagrangeCommittee {
    
    function owner() public view override(OwnableUpgradeable) returns (address) {
    	return super.owner();
    }
 
    uint256 public constant COMMITTEE_CURRENT = 0;
    uint256 public constant COMMITTEE_NEXT_1 = 1;
    uint256 public constant COMMITTEE_NEXT_2 = 2;
    uint256 public constant COMMITTEE_NEXT_3 = 3;


    mapping(uint256 => uint256) public COMMITTEE_START;
    mapping(uint256 => uint256) public COMMITTEE_DURATION;
    
    function getCommitteeStart(uint256 chainID) external view returns (uint256) {
    	return COMMITTEE_START[chainID];
    }

    function getCommitteeDuration(uint256 chainID) external view returns (uint256) {
    	return COMMITTEE_DURATION[chainID];
    }
    
    function initialize(
      address _poseidon2Elements,
      address _poseidon3Elements,
      address _poseidon4Elements
    ) initializer public {
        _initializeHelpers(
            _poseidon2Elements,
            _poseidon3Elements,
            _poseidon4Elements
        );
    }

    event InitCommittee(
        uint256 chainID,
        uint256 duration
    );

    function initCommittee(uint256 _chainID, uint256 _duration) public {
        require(COMMITTEE_START[_chainID] == 0, "Committee has already been initialized.");
        
        COMMITTEE_START[_chainID] = block.number;
        COMMITTEE_DURATION[_chainID] = _duration;
        
        EpochNumber[_chainID] = 0;
        
        emit InitCommittee(_chainID, _duration);
    }

    /// Committee Implementation
    struct CommitteeLeaf {
        address	addr;
        uint256	stake;
        bytes blsPubKey;
    }
    // residual committee prevhash tracking?
    // current, next, next-next tree
    // N3 - flux
    // N2 - frozen proposal
    // N1 - snapshot, proposed committee
    // C - current
    // evidence for l2s may need to include height.  block header, cur c, next c, height - state root contained within block header / block hash
    // cc, nc, block hash, height
    
    // ChainID => Committee Map Length
    mapping(uint256 => uint256) public CommitteeMapLength;
    // ChainID => Committee Leaf Hash
    mapping(uint256 => uint256[]) public CommitteeMapKeys;
    // ChainID => Committee Leaf Hash => Committee Leaf
    mapping(uint256 => mapping(uint256 => CommitteeLeaf)) public CommitteeMap;
    // ChainID => Merkle Nodes
    mapping(uint256 => uint256[]) public CommitteeNodes;
    // ChainID => Committee Index (Current, Next, ...) => Committee Root
    mapping(uint256 => mapping(uint256 => uint256)) public CommitteeRoot;

    function removeCommitteeAddr(uint256 chainID) external {
        address addr = msg.sender;
        for (uint256 i = 0; i < CommitteeMapKeys[chainID].length; i++) {
	    uint256 _i = CommitteeMapKeys[chainID][i];
	    uint256 _if = CommitteeMapKeys[chainID][CommitteeMapKeys[chainID].length - 1];
	    if (CommitteeMap[chainID][_i].addr == addr) {
	        CommitteeMap[chainID][_i] = CommitteeMap[chainID][_if];
	        CommitteeMap[chainID][_if] = CommitteeLeaf(address(0),0,"");
	        
	        CommitteeMapKeys[chainID][i] = CommitteeMapKeys[chainID][CommitteeMapKeys[chainID].length - 1];
	        CommitteeMapKeys[chainID].pop;
                CommitteeMapLength[chainID]--;
	    }
	}
    }
    
    mapping(uint256 => uint256) public EpochNumber;
    mapping(uint256 => mapping(uint256 => uint256)) public epoch2committee;

    event RotateCommittee(
        uint256 chainID,
        uint256 current,
        uint256 next1,
        uint256 next2,
        uint256 next3
    );

    function rotateCommittee(uint256 chainID) external {
        require(block.number > COMMITTEE_START[chainID] + COMMITTEE_DURATION[chainID], "Block number does not exceed end block of current committee");
        
        COMMITTEE_START[chainID] = block.number;
        
        CommitteeRoot[chainID][COMMITTEE_CURRENT] = CommitteeRoot[chainID][COMMITTEE_NEXT_1];
        CommitteeRoot[chainID][COMMITTEE_NEXT_1] = CommitteeRoot[chainID][COMMITTEE_NEXT_2];
        CommitteeRoot[chainID][COMMITTEE_NEXT_2] = CommitteeRoot[chainID][COMMITTEE_NEXT_3];
        
        epoch2committee[chainID][EpochNumber[chainID] + COMMITTEE_NEXT_2] = CommitteeRoot[chainID][COMMITTEE_NEXT_2];
        
        CommitteeRoot[chainID][COMMITTEE_NEXT_3] = uint256(0);
        
        EpochNumber[chainID]++;
        
        emit RotateCommittee(
            chainID,
            CommitteeRoot[chainID][COMMITTEE_CURRENT],
            CommitteeRoot[chainID][COMMITTEE_NEXT_1],
            CommitteeRoot[chainID][COMMITTEE_NEXT_2],
            CommitteeRoot[chainID][COMMITTEE_NEXT_3]
        );
    }
    
    function committeeAdd(uint256 chainID, uint256 stake, bytes memory _blsPubKey) external {
        address addr = msg.sender;
        
        CommitteeNodes[chainID] = new uint256[](0);
        CommitteeRoot[chainID][COMMITTEE_NEXT_3] = uint256(0);
        
        CommitteeLeaf memory cleaf = CommitteeLeaf(addr,stake,_blsPubKey);
        uint256 lhash = _hash2Elements([uint256(uint160(cleaf.addr)), uint256(cleaf.stake)]);
        CommitteeMap[chainID][lhash] = cleaf;
        CommitteeMapKeys[chainID].push(lhash);
        CommitteeMapLength[chainID]++;
        CommitteeNodes[chainID].push(lhash);
        compCommitteeRoot(chainID);
    }
    
    function getCommitteeRoot(uint256 chainID, uint256 _epoch) public view returns (uint256) {
        return epoch2committee[chainID][_epoch];
    }

    function getNextCommitteeRoot(uint256 chainID, uint256 _epoch) public view returns (uint256) {
        return epoch2committee[chainID][_epoch+1];
    }
    
    function compCommitteeRoot(uint256 chainID) internal {
        if(CommitteeNodes[chainID].length == 0) {
            CommitteeRoot[chainID][COMMITTEE_NEXT_3] = _hash2Elements([uint256(0),uint256(0)]);
            return;
        } else if(CommitteeNodes[chainID].length == 1) {
            CommitteeRoot[chainID][COMMITTEE_NEXT_3] = CommitteeNodes[chainID][0];
            return;
        }
        uint256 _len = CommitteeNodes[chainID].length;
        uint256 _start = 0;
        while(_len > 0) {
            for(uint256 i = 0; i < _len - 1; i += 2) {
                CommitteeNodes[chainID].push(_hash2Elements([
                        CommitteeNodes[chainID][_start + i],
                        CommitteeNodes[chainID][_start + i + 1]
                    ])
                );
            }
            _start += _len;
            _len = _len / 2;
        }
        CommitteeRoot[chainID][COMMITTEE_NEXT_3] = CommitteeNodes[chainID][CommitteeNodes[chainID].length - 1];
    }    

    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;
    using RLPReader for bytes;
    
    function calculateBlockHash(bytes memory rlpData) public pure returns (bytes32) {
        return keccak256(rlpData);
    }

    function checkAndDecodeRLP(bytes memory rlpData, bytes32 comparisonBlockHash) public view returns (RLPReader.RLPItem[] memory) {
        bytes32 blockHash = keccak256(rlpData);
        require(blockHash == comparisonBlockHash, "Hash of RLP data diverges from comparison block hash");
        RLPReader.RLPItem[] memory decoded = rlpData.toRlpItem().toList();
	return decoded;
    }
    
    uint public constant BLOCK_HEADER_NUMBER_INDEX = 8;

    function verifyBlockNumber(uint comparisonNumber, bytes memory rlpData, bytes32 comparisonBlockHash, uint256 chainID) external view returns (bool) {
        RLPReader.RLPItem[] memory decoded = checkAndDecodeRLP(rlpData, comparisonBlockHash);
        RLPReader.RLPItem memory blockNumberItem = decoded[BLOCK_HEADER_NUMBER_INDEX];
        uint number = blockNumberItem.toUint();
        bool res = number == comparisonNumber;
        return res;
    }

    function toUint(bytes memory src) internal pure returns (uint) {
        uint value;
        for (uint i = 0; i < src.length; i++) {
            value = value * 256 + uint(uint8(src[i]));
        }
        return value;
    }
}
