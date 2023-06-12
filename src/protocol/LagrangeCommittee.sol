// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../library/HermezHelpers.sol";

import "../interfaces/ILagrangeCommittee.sol";

import "../library/LibLagrangeCommittee.sol";

contract LagrangeCommittee is Initializable, OwnableUpgradeable, HermezHelpers, ILagrangeCommittee {
    mapping(address => bool) sequencers;
    
    function addSequencer(address seqAddr) public onlyOwner {
        sequencers[seqAddr] = true;
    }
    
    modifier onlySequencer() {
        require(sequencers[msg.sender] == true, "Only sequencer nodes can call this function.");
        _;
    }
    
    function owner() public view override(OwnableUpgradeable) returns (address) {
    	return OwnableUpgradeable.owner();
    }

    struct CommitteeDef {
        uint256 startBlock;
        uint256 duration;
        uint256 freezeDuration;
    }
    
    struct CommitteeData {
        uint256 root;
        uint256 height;
    }
 
    // Active Committee
    uint256 public constant COMMITTEE_CURRENT = 0;
    // Frozen Committee - Next "Current" Committee
    uint256 public constant COMMITTEE_NEXT_1 = 1;
    // Flux Committee - Changes dynamically prior to freeze as "Next" committee
    uint256 public constant COMMITTEE_NEXT_2 = 2;
    
    // ChainID => Address
    mapping(uint256 => address[]) addedAddrs;
    mapping(uint256 => address[]) removedAddrs;
    
    // ChainID => Committee
    mapping(uint256 => CommitteeDef) CommitteeParams;
    // ChainID => Epoch => CommitteeData
    mapping(uint256 => mapping(uint256 => CommitteeData)) Committees;
    
    /* Live Committee Data */
    // ChainID => Committee Map Length
    mapping(uint256 => uint256) public CommitteeMapLength;
    // ChainID => Committee Leaf Hash
    mapping(uint256 => uint256[]) public CommitteeMapKeys;
    // ChainID => Committee Leaf Hash => Committee Leaf
    mapping(uint256 => mapping(uint256 => CommitteeLeaf)) public CommitteeMap;
    // ChainID => Merkle Nodes
    mapping(uint256 => uint256[]) public CommitteeLeaves;
    
    // Address => BLSPubKey
    mapping(address => bytes) public addr2bls;

    // Wrapper function for committeeStartBlock - returns start block based on ChainID    
    function getCommitteeStart(uint256 chainID) public view returns (uint256) {
    	return CommitteeParams[chainID].startBlock;
    }

    // Wrapper function for COMMITTEE_DURATION - returns duration in blocks based on ChainID    
    function getCommitteeDuration(uint256 chainID) public view returns (uint256) {
    	return CommitteeParams[chainID].duration;
    }
    
    // Constructor: Accepts poseidon contracts for 2, 3, and 4 elements
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
        __Ownable_init();
    }
    
    // Event fired on initialization of a new committee
    event InitCommittee(
        uint256 chainID,
        uint256 duration,
        uint256 freezeDuration
    );
    
    // Initialize new committee.
    function initCommittee(uint256 chainID, uint256 _duration, uint256 freezeDuration) public onlySequencer {
        require(getCommitteeStart(chainID) == 0, "Committee has already been initialized.");

        CommitteeParams[chainID] = CommitteeDef(block.number, _duration, freezeDuration);
        Committees[chainID][0] = CommitteeData(0,0);

        CommitteeMapKeys[chainID] = new uint256[](0);
        CommitteeMapLength[chainID] = 0;
        CommitteeLeaves[chainID] = new uint256[](0);

        emit InitCommittee(chainID, _duration, freezeDuration);
    }

    /// Leaf in Lagrange State Committee Trie
    struct CommitteeLeaf {
        address	addr;
        uint256	stake;
        bytes blsPubKey;
    }
    
    // Constructs and returns new CommitteeLeaf instance
    function newCommitteeLeaf(address addr, uint256 stake, bytes memory blsPubKey) internal returns (CommitteeLeaf memory) {
        return CommitteeLeaf(addr,stake,blsPubKey);
    }
    
    // Remove address from committee map for chainID, update keys and length/height
    function removeCommitteeAddr(uint256 chainID, address addr) internal onlySequencer {
        /*
        address addr = msg.sender;
        */
        /*
        if(addr != msg.sender) {
            require(addr == owner(),"Only the contract owner can remove other addresses from committee.");
        }
        */
        for (uint256 i = 0; i < CommitteeMapKeys[chainID].length; i++) {
	    uint256 _i = CommitteeMapKeys[chainID][i];
	    uint256 _if = CommitteeMapKeys[chainID][CommitteeMapKeys[chainID].length - 1];
	    if (CommitteeMap[chainID][_i].addr == addr) {
	        CommitteeMap[chainID][_i] = CommitteeMap[chainID][_if];
	        CommitteeMap[chainID][_if] = newCommitteeLeaf(address(0),0,"");
	        
	        CommitteeMapKeys[chainID][i] = CommitteeMapKeys[chainID][CommitteeMapKeys[chainID].length - 1];
	        CommitteeMapKeys[chainID].pop;
                CommitteeMapLength[chainID]--;
	    }
	}
    }
    
    // Fired on successful rotation of committee
    event UpdateCommittee(
        uint256 chainID,
        bytes32 current
    );
    
    // Wrapper functions for poseidon-hashing elements
    function hash2Elements(uint256 a, uint256 b) public view returns (uint256) {
        return _hash2Elements([a,b]);
    }

    // Return Poseidon Hash of Committee Leaf
    function getLeafHash(CommitteeLeaf memory cleaf) public view returns (uint256) {
        return hash2Elements(
            uint256(uint160(cleaf.addr)),
            hash2Elements(
                uint256(cleaf.stake),
                uint256(keccak256(cleaf.blsPubKey))
            )
        );
    }
    
    // Add address to committee (NEXT_2) trie
    function committeeAdd(uint256 chainID, address addr, uint256 stake, bytes memory _blsPubKey) public onlySequencer {
        require(getCommitteeStart(chainID) > 0, "A committee for this chain ID has not been initialized.");
                
        CommitteeLeaf memory cleaf = newCommitteeLeaf(addr,stake,_blsPubKey);
        uint256 lhash = getLeafHash(cleaf);
        CommitteeMap[chainID][lhash] = cleaf;
        CommitteeMapKeys[chainID].push(lhash);
        CommitteeMapLength[chainID]++;
        CommitteeLeaves[chainID].push(lhash);
    }
    
    // Returns current committee root for chainID at given epoch
    function getCommitteeRoot(uint256 chainID, uint256 epochNumber) public returns (bytes32) {
        return bytes32(getCommittee(chainID, epochNumber));
    }

    function getCommittee(uint256 chainID, uint256 epochNumber) public returns (uint256) {
        return Committees[chainID][epochNumber].root;
    }

    // Returns next_1 committee root for chainID at given epoch
    function getNextCommitteeRoot(uint256 chainID, uint256 epochNumber) public returns (bytes32) {
        return bytes32(getCommittee(chainID, epochNumber + COMMITTEE_NEXT_1));
    }
    
    function getNext1CommitteeRoot(uint256 chainID) public view returns (uint256) {
        if(CommitteeLeaves[chainID].length == 0) {
            return hash2Elements(uint256(0),uint256(0));
        } else if(CommitteeLeaves[chainID].length == 1) {
            return CommitteeLeaves[chainID][0];
        }
        
        // First pass: compute committee nodes in memory from leaves
        uint256 _len = CommitteeLeaves[chainID].length;
        uint256[] memory CommitteeNodes = new uint256[](_len/2);
        uint256 _start = 0;
	for(uint256 i = 0; i < _len - 1; i += 2) {
	    CommitteeNodes[i/2] = hash2Elements(
	        CommitteeLeaves[chainID][_start + i],
	        CommitteeLeaves[chainID][_start + i + 1]
	    );
	}
        
        // Second pass: compute committee nodes in memory from nodes
        _len = _len/2;
        while(_len > 0) {
            uint256[] memory NLCommitteeNodes = new uint256[](_len/2);
	    for(uint256 i = 0; i < _len - 1; i += 2) {
	        NLCommitteeNodes[i/2] = hash2Elements(
	            CommitteeNodes[_start + i],
	            CommitteeNodes[_start + i + 1]
	        );
	    }
	    CommitteeNodes = NLCommitteeNodes;
            _start = 0;
            _len = _len / 2;
        }
        return CommitteeNodes[CommitteeNodes.length - 1];
    }
    
    // Recalculates committee root (next_2)
    function compCommitteeRoot(uint256 chainID) internal {
        uint256 nextRoot = getNext1CommitteeRoot(chainID);
        uint256 epochNumber = getEpochNumber(chainID, block.number);
        
        // Update roots
        Committees[chainID][epochNumber + COMMITTEE_NEXT_1].root = nextRoot;
    }    

    // Verify that comparisonNumber (block number) is in raw block header (rlpData) and raw block header matches comparisonBlockHash.  ChainID provides for network segmentation.
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

    function registerChain(
        uint256 chainID,
        address[] memory /* TODO calldata? */ stakedAddrs,
        uint256 epochPeriod,
        uint256 freezeDuration
    ) public {
        initCommittee(chainID, epochPeriod, freezeDuration);
        for (uint256 i = 0; i < stakedAddrs.length; i++) {
            // TODO protect against redundancy
            addAddr(chainID, stakedAddrs[i]);
        }
    }
    
    function BLSAssoc(bytes memory blsPubKey) public {
        addr2bls[msg.sender] = blsPubKey;
    }
    
    function add(uint256 chainID) public {
        addedAddrs[chainID].push(msg.sender);
    }

    function addAddr(uint256 chainID, address addr) public onlySequencer {
        addedAddrs[chainID].push(addr);
    }

    function remove(uint256 chainID, address addr) public onlySequencer {
        removedAddrs[chainID].push(addr);
    }

    function update(uint256 chainID) external onlySequencer {
        uint256 epochNumber = getEpochNumber(chainID, block.number);
        uint256 epochEnd = epochNumber + CommitteeParams[chainID].duration;
        uint256 freezeDuration = CommitteeParams[chainID].freezeDuration;
        require(block.number > epochEnd - freezeDuration, "Block number is prior to committee freeze window.");
        // TODO store updated_number
        for (uint256 i = 0; i < addedAddrs[chainID].length; i++) {
            committeeAdd(chainID, addedAddrs[chainID][i], 0 /* TODO */, addr2bls[msg.sender]);
        }
        for (uint256 i = 0; i < removedAddrs[chainID].length; i++) {
            removeCommitteeAddr(chainID, removedAddrs[chainID][i]);
        }
        delete addedAddrs[chainID];
        delete removedAddrs[chainID];
        compCommitteeRoot(chainID);
        
        emit UpdateCommittee(
            chainID,
            bytes32(getNextCommitteeRoot(chainID,block.number))
        );
    }
    
    function getEpochNumber(uint256 chainID, uint256 blockNumber) public view returns (uint256) {
        uint256 startBlockNumber = CommitteeParams[chainID].startBlock;
        uint256 epochPeriod = CommitteeParams[chainID].duration;
        uint256 epochNumber = (blockNumber - startBlockNumber) / epochPeriod;
        return epochNumber;
    }
}
