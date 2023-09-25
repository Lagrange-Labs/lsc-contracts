// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Common} from "./Common.sol";
import {IRecursiveHeaderVerifier} from "../interfaces/IRecursiveHeaderVerifier.sol";
import {IMantleVerifier} from "../interfaces/IMantleVerifier.sol";
import {IStateCommitmentChain} from "../mock/mantle/IStateCommitmentChain.sol";
import {IChainStorageContainer} from "../mock/mantle/IChainStorageContainer.sol";
import {Lib_MerkleTree} from "../mock/mantle/Lib_MerkleTree.sol";
import "solidity-rlp/contracts/Helper.sol";

contract MantleVerifier is Common, IMantleVerifier {

    IRollup public Rollup;
    AssertionMap public Assertions;

    constructor(IRollup _rollup, AssertionMap _assertions) {
        Rollup = _rollup;
        Assertions = _assertions;
    }

    struct AssertionSummary {
        uint256 assertionID;
        bytes32 root;
	uint256 l2blocknum;
    }
    
    function verifyMntBlock(
        bytes calldata rlpData,
        bytes32 attestHash,
        bytes calldata checkpointRLP,
        bytes calldata headerProof,
        bytes calldata extraData, // bytes32+uint256
        IRecursiveHeaderVerifier RHVerify
    ) public view returns (bool) {
        // 0. Construct proofs offchain
        
        // 1. Parse RLP
        RLPReader.RLPItem[] memory decoded = checkAndDecodeRLP(
            checkpointRLP,
            keccak256(checkpointRLP)
        );
	
        RLPReader.RLPItem memory blockStateRootItem = decoded[
            Common.BLOCK_HEADER_STATEROOT_INDEX
        ];
        bytes32 stateRoot = bytes32(blockStateRootItem.toUint());

        RLPReader.RLPItem memory blockNumberItem = decoded[
            Common.BLOCK_HEADER_NUMBER_INDEX
        ];
        uint256 blockNumber = uint256(blockStateRootItem.toUint());

        // 2. Verify assertion summary and checkpoint RLP against mantle contracts
	AssertionSummary memory proof = abi.decode(extradata,(AssertionSummary));
	Assertion memory mntAssertion = Assertions.assertions(proof.assertionID); // are only confirmed assertions present beyond a particular window?  TODO
	require(assertion.inboxSize == proof.l2blocknum, "MantleVerifier: L2 block number doesn't match");
	require(assertion.stateHash == proof.root, "MantleVerifier: State root doesn't match");
	require(stateRoot == proof.root, "MantleVerifier: State root doesn't match");
	require(blockNumber == proof.l2blocknum, "MantleVerifier: L2 block number doesn't match");
	
        // 4. Recursively verify attested hash in checkpoint block header
        bytes32 l2hash = keccak256(checkpointRLP);
        return RHVerify.verifyProof(rlpData, headerProof, l2hash);
    }
}
