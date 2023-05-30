// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../library/HermezHelpers.sol";

import "../interfaces/ILagrangeCommittee.sol";

import "../library/LibLagrangeCommittee.sol";

contract LagrangeCommittee is Initializable, OwnableUpgradeable, HermezHelpers, ILagrangeCommittee {
    
    function owner() public view override(OwnableUpgradeable) returns (address) {
    	return super.owner();
    }
 
    uint256 public constant COMMITTEE_CURRENT = 0;
    uint256 public constant COMMITTEE_NEXT_1 = 1;
    uint256 public constant COMMITTEE_NEXT_2 = 2;


    mapping(uint256 => uint256) public COMMITTEE_START;
    mapping(uint256 => uint256) public COMMITTEE_DURATION;
    
    function getCommitteeStart(uint256 chainID) external view returns (uint256) {
    	return COMMITTEE_START[chainID];
    }

    function getCommitteeDuration(uint256 chainID) external view returns (uint256) {
    	return COMMITTEE_DURATION[chainID];
    }
    
    constructor(
      address _poseidon2Elements,
      address _poseidon3Elements,
      address _poseidon4Elements
    ) initializer {
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
    mapping(uint256 => uint256[]) public CommitteeLeaves;
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
        uint256 next2
    );

    function rotateCommittee(uint256 chainID) external {
        require(block.number > COMMITTEE_START[chainID] + COMMITTEE_DURATION[chainID], "Block number does not exceed end block of current committee");
        
        COMMITTEE_START[chainID] = block.number;
        
        CommitteeRoot[chainID][COMMITTEE_CURRENT] = CommitteeRoot[chainID][COMMITTEE_NEXT_1];
        CommitteeRoot[chainID][COMMITTEE_NEXT_1] = CommitteeRoot[chainID][COMMITTEE_NEXT_2];
        
        epoch2committee[chainID][EpochNumber[chainID] + COMMITTEE_NEXT_2] = CommitteeRoot[chainID][COMMITTEE_NEXT_2];
        
        CommitteeRoot[chainID][COMMITTEE_NEXT_2] = uint256(0);
        
        EpochNumber[chainID]++;
        
        emit RotateCommittee(
            chainID,
            CommitteeRoot[chainID][COMMITTEE_CURRENT],
            CommitteeRoot[chainID][COMMITTEE_NEXT_1],
            CommitteeRoot[chainID][COMMITTEE_NEXT_2]
        );
    }
    
    function committeeAdd(uint256 chainID, uint256 stake, bytes memory _blsPubKey) external {
        address addr = msg.sender;
        
        // TODO this should only happen during initialization
        CommitteeLeaves[chainID] = new uint256[](0);
        CommitteeRoot[chainID][COMMITTEE_NEXT_2] = uint256(0);
        
        CommitteeLeaf memory cleaf = CommitteeLeaf(addr,stake,_blsPubKey);
        uint256 lhash = _hash2Elements([uint256(uint160(cleaf.addr)), uint256(cleaf.stake)]);
        CommitteeMap[chainID][lhash] = cleaf;
        CommitteeMapKeys[chainID].push(lhash);
        CommitteeMapLength[chainID]++;
        CommitteeLeaves[chainID].push(lhash);
        compCommitteeRoot(chainID);
    }
    
    function getCommitteeRoot(uint256 chainID, uint256 _epoch) external view returns (bytes32) {
        return bytes32(epoch2committee[chainID][_epoch]);
    }

    function getNextCommitteeRoot(uint256 chainID, uint256 _epoch) external view returns (bytes32) {
        return bytes32(epoch2committee[chainID][_epoch+1]);
    }
    
    function compCommitteeRoot(uint256 chainID) internal {
        if(CommitteeLeaves[chainID].length == 0) {
            CommitteeRoot[chainID][COMMITTEE_NEXT_2] = _hash2Elements([uint256(0),uint256(0)]);
            return;
        } else if(CommitteeLeaves[chainID].length == 1) {
            CommitteeRoot[chainID][COMMITTEE_NEXT_2] = CommitteeLeaves[chainID][0];
            return;
        }
        
        // First pass: compute committee nodes in memory from leaves
        uint256 _len = CommitteeLeaves[chainID].length;
        uint256[] memory CommitteeNodes = new uint256[](_len/2);
        uint256 _start = 0;
	for(uint256 i = 0; i < _len - 1; i += 2) {
	    CommitteeNodes[i/2] = _hash2Elements([
	        CommitteeLeaves[chainID][_start + i],
	        CommitteeLeaves[chainID][_start + i + 1]
	    ]);
	}
        
        // Second pass: compute committee nodes in memory from nodes
        _len = _len/2;
        while(_len > 0) {
            uint256[] memory NLCommitteeNodes = new uint256[](_len/2);
	    for(uint256 i = 0; i < _len - 1; i += 2) {
	        NLCommitteeNodes[i/2] = _hash2Elements([
	            CommitteeNodes[_start + i],
	            CommitteeNodes[_start + i + 1]
	        ]);
	    }
	    CommitteeNodes = NLCommitteeNodes;
            _start = 0;
            _len = _len / 2;
        }
        
        // Update roots
        CommitteeRoot[chainID][COMMITTEE_NEXT_2] = CommitteeNodes[CommitteeNodes.length - 1];
    }    

    function verifyBlockNumber(uint comparisonNumber, bytes memory rlpData, bytes32 comparisonBlockHash, uint256 chainID) external view returns (bool) {
        return LibLagrangeCommittee.verifyBlockNumber(comparisonNumber, rlpData, comparisonBlockHash, chainID);
    }
    
/*
    //IRollupCore	public ArbRollupCore;
    IOutbox	public ArbOutbox;
    
    function verifyArbBlockNumber(uint comparisonNumber, bytes memory rlpData, bytes32 comparisonBlockHash, uint256 chainID) external view returns (bool) {
        RLPReader.RLPItem[] memory decoded = checkAndDecodeRLP(rlpData, comparisonBlockHash);
        RLPReader.RLPItem memory extraDataItem = decoded[BLOCK_HEADER_EXTRADATA_INDEX];
        RLPReader.RLPItem memory blockNumberItem = decoded[BLOCK_HEADER_NUMBER_INDEX];
        bytes32 extraData = bytes32(extraDataItem.toUintStrict()); //TODO Maybe toUint() - please test this specifically with several cases.
        bytes32 l2Hash = ArbOutbox.roots[extraData];
        if (l2Hash == bytes32(0)) {
            // No such confirmed node... TODO determine how these should be handled
            return false;
        }
        uint number = blockNumberItem.toUint();
        
        bool hashCheck = l2hash == comparisonBlockHash;
        bool numberCheck = number == comparisonNumber;
        bool res = hashCheck && numberCheck;
        return res;
    }
    
    IICanonicalTransactionChain public Optimism;
    
    function verifyOptBlockNumber(uint comparisonNumber, bytes32 comparisonBatchRoot, uint256 chainID) external view returns (bool) {
        // BlockHash does not seem to be available, but root and number can be verified onchain.
//        uint number = 
        bool res = false;
        return res;
    }
*/
}
