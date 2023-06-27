// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../library/HermezHelpers.sol";

import "../interfaces/ILagrangeCommittee.sol";

import "../library/EvidenceVerifier.sol";

contract LagrangeCommittee is Initializable, OwnableUpgradeable, HermezHelpers, ILagrangeCommittee {

    /// Leaf in Lagrange State Committee Trie
    struct CommitteeLeaf {
        address	addr;
        uint256	stake;
        bytes blsPubKey;
    }

    struct CommitteeDef {
        uint256 startBlock;
        uint256 duration;
        uint256 freezeDuration;
    }
    
    struct CommitteeData {
        uint256 root;
        uint256 height;
        uint256 totalVotingPower;
    }

    mapping(address => bool) sequencers;

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

    mapping(address => OperatorStatus) public operators;

    // Event fired on initialization of a new committee
    event InitCommittee(
        uint256 chainID,
        uint256 duration,
        uint256 freezeDuration
    );

    // Fired on successful rotation of committee
    event UpdateCommittee(
        uint256 chainID,
        bytes32 current
    );
     
    function getServeUntilBlock(address operator) public returns (uint32) {
        return operators[operator].serveUntilBlock;
    }

    function setSlashed(address operator, bool slashed) public onlySequencer {
        operators[operator].slashed = slashed;
    }

    function getSlashed(address operator) public returns (bool) {
        return operators[operator].slashed;
    }
    
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

    // Constructor: Accepts poseidon contracts for 2, 3, and 4 elements
    constructor(
      address _poseidon1Elements,
      address _poseidon2Elements,
      address _poseidon3Elements,
      address _poseidon4Elements,
      address _poseidon5Elements,
      address _poseidon6Elements
    ) initializer {
        _initializeHelpers(
            _poseidon1Elements,
            _poseidon2Elements,
            _poseidon3Elements,
            _poseidon4Elements,
            _poseidon5Elements,
            _poseidon6Elements
        );
        __Ownable_init();
    }
        
    // Initialize new committee.
    function _initCommittee(uint256 chainID, uint256 _duration, uint256 freezeDuration) internal onlySequencer {
        require(CommitteeParams[chainID].startBlock == 0, "Committee has already been initialized.");

        CommitteeParams[chainID] = CommitteeDef(block.number, _duration, freezeDuration);
        Committees[chainID][0] = CommitteeData(0,0,0);

        CommitteeMapKeys[chainID] = new uint256[](0);
        CommitteeMapLength[chainID] = 0;
        CommitteeLeaves[chainID] = new uint256[](0);

        emit InitCommittee(chainID, _duration, freezeDuration);
    }
    
    // Remove address from committee map for chainID, update keys and length/height
    function _removeCommitteeAddr(uint256 chainID, address addr) internal onlySequencer {
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
	        CommitteeMap[chainID][_if] = CommitteeLeaf(address(0),0,"");
	        
	        CommitteeMapKeys[chainID][i] = CommitteeMapKeys[chainID][CommitteeMapKeys[chainID].length - 1];
	        CommitteeMapKeys[chainID].pop;
                CommitteeMapLength[chainID]--;
	    }
	}
    }
        
    // Wrapper functions for poseidon-hashing elements
    function hash1Elements(uint256 a) public view returns (uint256) {
        return _hash1Elements([a]);
    }
    function hash2Elements(uint256 a, uint256 b) public view returns (uint256) {
        return _hash2Elements([a,b]);
    }
    function hash3Elements(uint256 a, uint256 b, uint256 c) public view returns (uint256) {
        return _hash3Elements([a,b,c]);
    }
    function hash4Elements(uint256 a, uint256 b, uint256 c, uint256 d) public view returns (uint256) {
        return _hash4Elements([a,b,c,d]);
    }
    function hash5Elements(uint256[5] memory e) public view returns (uint256) {
        return _hash5Elements(e);
    }
    function hash6Elements(uint256[6] memory e) public view returns (uint256) {
        return _hash6Elements(e);
    }

    // Return Poseidon Hash of Committee Leaf
    /*
    function getLeafHash(CommitteeLeaf memory cleaf) public view returns (uint256) {
        return _hash3Elements([
            uint256(uint160(cleaf.addr)),
            uint256(cleaf.stake),
            uint256(keccak256(cleaf.blsPubKey))
        ]);
    }
    */
    // Add address to committee (NEXT_2) trie
    function _committeeAdd(uint256 chainID, address addr, uint256 stake, bytes memory _blsPubKey) internal onlySequencer {
        require(CommitteeParams[chainID].startBlock > 0, "A committee for this chain ID has not been initialized.");
                
        CommitteeLeaf memory cleaf = CommitteeLeaf(addr,stake,_blsPubKey);
        uint256 lhash = getLeafHash(cleaf);
        CommitteeMap[chainID][lhash] = cleaf;
        CommitteeMapKeys[chainID].push(lhash);
        CommitteeMapLength[chainID]++;
        CommitteeLeaves[chainID].push(lhash);
    }

    // Returns chain's committee root at a given block.
    function getCommittee(uint256 chainID, uint256 epochNumber) public returns (uint256) {
        return Committees[chainID][epochNumber].root;
    }
    
    // Computes and returns "next" committee root.
    function getNext1CommitteeRoot(uint256 chainID) public view returns (uint256) {
        if(CommitteeLeaves[chainID].length == 0) {
            return hash2Elements(uint256(0),uint256(0));
        } else if(CommitteeLeaves[chainID].length == 1) {
            return CommitteeLeaves[chainID][0];
        }

	// Calculate limit
	uint256 _lim = 2;
	while (_lim < CommitteeLeaves[chainID].length) {
	    _lim *= 2;
	}

        // First pass: compute committee nodes in memory from leaves
        uint256[] memory CommitteeNodes = new uint256[](_lim/2);
        uint256 left = 0;
        uint256 right = 0;
	for(uint256 i = 0; i < _lim; i += 2) {
	    if(i < CommitteeLeaves[chainID].length) {
	        left = CommitteeLeaves[chainID][i];
	    } else {
	        left = 0;
	    }
	    if(i + 1 < CommitteeLeaves[chainID].length) {
	        right = CommitteeLeaves[chainID][i];
	    } else {
	        right = 0;
	    }
	    CommitteeNodes[i/2] = hash2Elements(left, right);
	}
        
        // Second pass: compute committee nodes in memory from nodes
        _lim = _lim/2;
        while(_lim > 0) {
            uint256[] memory NLCommitteeNodes = new uint256[](_lim/2);
	    for(uint256 i = 0; i < _lim; i += 2) {
	        NLCommitteeNodes[i/2] = hash2Elements(
	            CommitteeNodes[i],
	            CommitteeNodes[i + 1]
	        );
	    }
	    CommitteeNodes = NLCommitteeNodes;
            _lim = _lim / 2;
        }
        return CommitteeNodes[0];
    }
    
    // Recalculates committee root (next_2)
    function _compCommitteeRoot(uint256 chainID) internal /* TODO onlySequencer? */ {
        uint256 nextRoot = getNext1CommitteeRoot(chainID);
        uint256 epochNumber = getEpochNumber(chainID, block.number);
        
        // Update roots
        Committees[chainID][epochNumber + COMMITTEE_NEXT_1].height = CommitteeMapLength[chainID];
        Committees[chainID][epochNumber + COMMITTEE_NEXT_1].root = nextRoot;
        Committees[chainID][epochNumber + COMMITTEE_NEXT_1].totalVotingPower = _getTotalVotingPower(chainID);
    }    
    
    // Initializes a new committee, and optionally associates addresses with it.
    function registerChain(
        uint256 chainID,
        address[] calldata stakedAddrs,
        uint256 epochPeriod,
        uint256 freezeDuration
    ) public onlyOwner {
        _initCommittee(chainID, epochPeriod, freezeDuration);
        for (uint256 i = 0; i < stakedAddrs.length; i++) {
            _addAddr(chainID, stakedAddrs[i]);
        }
        _compCommitteeRoot(chainID);
    }

    // Adds address stake data and flags it for committee addition
    function add(uint256 chainID, bytes memory blsPubKey, uint256 stake, uint32 serveUntilBlock) public onlySequencer {
        addedAddrs[chainID].push(msg.sender);
        addr2bls[msg.sender] = blsPubKey;
        operators[msg.sender] = OperatorStatus(stake,serveUntilBlock,false);
    }

    // Internal.  "Flags" address to be added to a chain's committee.
    function _addAddr(uint256 chainID, address addr) internal onlySequencer {
        // protect against redundancy
        for (uint256 i = 0; i < addedAddrs[chainID].length; i++) {
            if(addedAddrs[chainID][i] == addr) return;
        }
        addedAddrs[chainID].push(addr);
    }

    // "Flags" address to be removed from chain's committee.
    function remove(uint256 chainID, address addr) public onlySequencer {
        removedAddrs[chainID].push(addr);
    }

    // If applicable, updates committee based on staking, unstaking, and slashing.
    function update(uint256 chainID) public onlySequencer {
        uint256 epochNumber = getEpochNumber(chainID, block.number);
        uint256 epochEnd = epochNumber + CommitteeParams[chainID].duration;
        uint256 freezeDuration = CommitteeParams[chainID].freezeDuration;
        require(block.number > epochEnd - freezeDuration, "Block number is prior to committee freeze window.");
        // TODO store updated_number
        for (uint256 i = 0; i < addedAddrs[chainID].length; i++) {
            _committeeAdd(chainID, addedAddrs[chainID][i], 0 /* TODO */, addr2bls[msg.sender]);
        }
        for (uint256 i = 0; i < removedAddrs[chainID].length; i++) {
            _removeCommitteeAddr(chainID, removedAddrs[chainID][i]);
        }
        delete addedAddrs[chainID];
        delete removedAddrs[chainID];
        _compCommitteeRoot(chainID);
        
        emit UpdateCommittee(
            chainID,
            bytes32(Committees[chainID][epochNumber+COMMITTEE_NEXT_1].root)
        );
    }

    // Computes epoch number for a chain's committee at a given block
    function getEpochNumber(uint256 chainID, uint256 blockNumber) public view returns (uint256) {
        uint256 startBlockNumber = CommitteeParams[chainID].startBlock;
        uint256 epochPeriod = CommitteeParams[chainID].duration;
        uint256 epochNumber = (blockNumber - startBlockNumber) / epochPeriod;
        return epochNumber;
    }

    // Returns cumulative strategy shares for opted in addresses
    function _getTotalVotingPower(uint256 chainID) internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < CommitteeMapLength[chainID]; i++) {
            total += CommitteeMap[chainID][CommitteeMapKeys[chainID][i]].stake;
        }
        return total;
    }
///////////    
    struct InputsA {
        uint256[6] bk_parts;
    }

    struct InputsB {
        uint256[3] addr_stake_parts;
    }
//    mapping(uint256 => mapping(uint256 => CommitteeLeaf)) public CommitteeMap;
/*
    function getLeafHash(CommitteeLeaf memory cleaf) public view returns (uint256) {
        return _hash3Elements([
            uint256(uint160(cleaf.addr)),
            uint256(cleaf.stake),
            uint256(keccak256(cleaf.blsPubKey))
        ]);
    }
*/

    function getBLSSlices(CommitteeLeaf memory cleaf) public view returns (uint96[8] memory) {
        bytes memory bls_bytes = abi.encodePacked(cleaf.blsPubKey); // TODO update committeeleaf and related variables involving bls to enforce this length.  this variable is optional.
        uint96[8] memory bls_slices;
        
        for (uint i = 0; i < 8; i++) {
            bytes memory bls = new bytes(12);
            for (uint j = 0; j < 12; j++) {
                bls[j] = bls_bytes[(i*12)+j];
            }
            bytes12 bls_chunk = bytes12(bls);
            bls_slices[i] = uint96(bls_chunk);
        }
        return bls_slices;
    }

    function getAddrStakeSlices(CommitteeLeaf memory cleaf) public view returns (uint96[3] memory) {
        bytes memory addr_stake_bytes = abi.encodePacked(cleaf.addr, uint128(cleaf.stake));
        uint96[3] memory addr_stake_slices;
        
        for (uint i = 0; i < 3; i++) {
            bytes memory addr_stake = new bytes(12);
            for (uint j = 0; j < 12; j++) {
                addr_stake[j] = addr_stake_bytes[(i*12)+j];
            }
            bytes12 addr_stake_chunk = bytes12(addr_stake);
            addr_stake_slices[i] = uint96(addr_stake_chunk);
        }
        return addr_stake_slices;
    }

    function getLeafHash(CommitteeLeaf memory cleaf /*uint256 chainID, bytes[96] memory bk, bytes[36] memory addr_stake*/) public view returns (uint256) {
        uint96[8] memory bls_slices = getBLSSlices(cleaf);
        uint96[3] memory addr_stake_slices = getAddrStakeSlices(cleaf);
        
        return hash2Elements(hash6Elements([
            uint256(bls_slices[0]),
            uint256(bls_slices[1]),
            uint256(bls_slices[2]),
            uint256(bls_slices[3]),
            uint256(bls_slices[4]),
            uint256(bls_slices[5])
        ]), hash5Elements([
            uint256(bls_slices[6]),
            uint256(bls_slices[7]),
            uint256(addr_stake_slices[0]),
            uint256(addr_stake_slices[1]),
            uint256(addr_stake_slices[2])
        ]));
    }
}
