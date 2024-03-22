// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {ISlashingAggregateVerifier} from "../interfaces/ISlashingAggregateVerifier.sol";
import {ISlashingSingleVerifier} from "../interfaces/ISlashingSingleVerifier.sol";
import {ILagrangeCommittee} from "../interfaces/ILagrangeCommittee.sol";
import {IStakeManager} from "../interfaces/IStakeManager.sol";
import {IEvidenceVerifier, Evidence, ProofParams} from "../interfaces/IEvidenceVerifier.sol";

contract EvidenceVerifier is Initializable, OwnableUpgradeable, IEvidenceVerifier {
    uint256 public constant CHAIN_ID_MAINNET = 1;
    uint256 public constant CHAIN_ID_OPTIMISM_BEDROCK = 420;
    uint256 public constant CHAIN_ID_BASE = 84531;
    uint256 public constant CHAIN_ID_ARBITRUM_NITRO = 421613;

    ILagrangeCommittee public immutable committee;
    IStakeManager public immutable stakeManager;
    // aggregate signature verifiers Triage
    mapping(uint256 => ISlashingAggregateVerifier) public aggVerifiers;
    // single signature verifier
    ISlashingSingleVerifier public singleVerifier;

    event OperatorSlashed(address operator);

    event UploadEvidence(
        address operator,
        bytes32 blockHash,
        bytes32 currentCommitteeRoot,
        bytes32 nextCommitteeRoot,
        uint256 blockNumber,
        uint256 epochNumber,
        bytes blockSignature,
        bytes commitSignature,
        uint32 chainID
    );

    constructor(ILagrangeCommittee _committee, IStakeManager _stakeManager) {
        committee = _committee;
        stakeManager = _stakeManager;
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    function setAggregateVerifierRoute(uint256 routeIndex, address _verifierAddress) external onlyOwner {
        aggVerifiers[routeIndex] = ISlashingAggregateVerifier(_verifierAddress);
    }

    function setSingleVerifier(address _verifierAddress) external onlyOwner {
        singleVerifier = ISlashingSingleVerifier(_verifierAddress);
    }

    /// upload the evidence to punish the operator.
    function uploadEvidence(Evidence calldata evidence) external {
        // check the operator is registered or not
        // TODO

        // check the operator is slashed or not

        require(checkCommitSignature(evidence), "The commit signature is not correct");

        if (!_checkBlockSignature(evidence)) {
            _freezeOperator(evidence.operator);
        }

        if (evidence.correctBlockHash == evidence.blockHash) {
            _freezeOperator(evidence.operator);
        }

        if (
            !_checkCommitteeRoots(
                evidence.correctCurrentCommitteeRoot,
                evidence.currentCommitteeRoot,
                evidence.correctNextCommitteeRoot,
                evidence.nextCommitteeRoot,
                evidence.l1BlockNumber,
                evidence.chainID
            )
        ) {
            _freezeOperator(evidence.operator);
        }

        // TODO what is this for (no condition)?

        emit UploadEvidence(
            evidence.operator,
            evidence.blockHash,
            evidence.currentCommitteeRoot,
            evidence.nextCommitteeRoot,
            evidence.blockNumber,
            evidence.l1BlockNumber,
            evidence.blockSignature,
            evidence.commitSignature,
            evidence.chainID
        );
    }

    /// Slash the given operator
    function _freezeOperator(address operator) internal {
        stakeManager.freezeOperator(operator);
        emit OperatorSlashed(operator);
    }

    function _checkBlockSignature(Evidence memory _evidence) internal returns (bool) {
        // establish that proofs are valid
        (ILagrangeCommittee.CommitteeData memory cdata,) =
            committee.getCommittee(_evidence.chainID, _evidence.l1BlockNumber);

        require(_verifyAggregateSignature(_evidence, cdata.leafCount), "Aggregate proof verification failed");

        uint256[2] memory blsPubKey = committee.getBlsPubKeys(_evidence.operator)[0];
        bool sigVerify = _verifySingleSignature(_evidence, blsPubKey);

        return (sigVerify);
    }

    // Slashing condition.  Returns veriifcation of chain's current committee root at a given block.
    function _checkCommitteeRoots(
        bytes32 correctCurrentCommitteeRoot,
        bytes32 currentCommitteeRoot,
        bytes32 correctNextCommitteeRoot,
        bytes32 nextCommitteeRoot,
        uint256 blockNumber,
        uint32 chainID
    ) internal returns (bool) {
        (ILagrangeCommittee.CommitteeData memory currentCommittee, bytes32 nextRoot) =
            committee.getCommittee(chainID, blockNumber);
        require(correctCurrentCommitteeRoot == currentCommittee.root, "Reference current committee roots do not match.");
        require(correctNextCommitteeRoot == nextRoot, "Reference next committee roots do not match.");

        return (currentCommitteeRoot == correctCurrentCommitteeRoot) && (nextCommitteeRoot == correctNextCommitteeRoot);
    }

    function toUint(bytes memory src) internal pure returns (uint256) {
        uint256 value;
        for (uint256 i = 0; i < src.length; i++) {
            value = value * 256 + uint256(uint8(src[i]));
        }
        return value;
    }

    // check the evidence identity and the ECDSA signature
    function checkCommitSignature(Evidence calldata evidence) public pure returns (bool) {
        bytes32 commitHash = getCommitHash(evidence);
        address recoveredAddress = ECDSA.recover(commitHash, evidence.commitSignature);
        return recoveredAddress == evidence.operator;
    }

    // get the hash of the commit request
    function getCommitHash(Evidence calldata evidence) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                evidence.blockHash,
                evidence.currentCommitteeRoot,
                evidence.nextCommitteeRoot,
                evidence.blockNumber,
                evidence.l1BlockNumber,
                evidence.blockSignature,
                evidence.chainID
            )
        );
    }

    function _getChainHeader(bytes32 blockHash, uint256 blockNumber, uint32 chainID) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(blockHash, uint256(blockNumber), uint32(chainID)));
    }

    function _computeRouteIndex(uint256 committeeSize) internal pure returns (uint256) {
        uint256 routeIndex = 1;
        while (routeIndex < committeeSize) {
            routeIndex = routeIndex * 2;
        }
        return routeIndex;
    }

    function _bytes96tobytes48(bytes memory bpk) public pure returns (bytes[2] memory) {
        require(bpk.length == 96, "BLS public key must be provided in a form that is 96 bytes.");
        bytes[2] memory gxy = [new bytes(48), new bytes(48)];
        for (uint256 i = 0; i < 48; i++) {
            gxy[0][i] = bpk[i];
            gxy[1][i] = bpk[i + 48];
        }
        return [abi.encodePacked(gxy[0]), abi.encodePacked(gxy[1])];
    }

    function _bytes48toslices(bytes memory b48) internal pure returns (uint256[7] memory) {
        // validate length
        require(b48.length == 48, "Input should be 48 bytes.");
        // resultant slices
        uint256[7] memory res;
        // first 32-byte word (truncate to 16 bytes)
        uint256 buffer1;
        // second 32-byte word
        uint256 buffer2;
        // for cycling from first to second word
        uint256 activeBuffer;
        // load words
        assembly {
            // 32b
            buffer1 := mload(add(b48, 0x20))
            // 16b
            buffer2 := mload(add(b48, 0x30))
        }
        buffer1 = buffer1 >> 128;
        // define slice
        uint56 slice;
        // set active buffer to second buffer
        activeBuffer = buffer2;
        for (uint256 i = 0; i < 7; i++) {
            if (i == 6) {
                slice = (uint56(activeBuffer));
            } else {
                // assign slice, derived from active buffer's last 55 bits
                slice = (uint56(activeBuffer) << 1) >> 1;
                // shift second buffer right by 55 bits
                buffer2 = buffer2 >> 55;
                // replace new leading zeros in second buffer with last 55 bits of first buffer
                buffer2 = (uint256(uint56(buffer1)) << 201) + buffer2;
                // refresh active buffer
                activeBuffer = buffer2;
                // shift first buffer right by 55 bits
                buffer1 = buffer1 >> 55;
            }
            // add to slices
            res[i] = uint256(slice);
        }
        return res;
    }

    function _bytes192tobytes48(bytes memory bpk) internal pure returns (bytes[4] memory) {
        require(bpk.length == 192, "Block signature must be in a form of length 192 bytes.");
        bytes[4] memory res = [new bytes(48), new bytes(48), new bytes(48), new bytes(48)];
        for (uint256 i = 0; i < 48; i++) {
            res[0][i] = bpk[i];
            res[1][i] = bpk[i + 48];
            res[2][i] = bpk[i + 96];
            res[3][i] = bpk[i + 144];
        }
        return res;
    }

    function _getBLSPubKeySlices(uint256[2] memory blsPubKey) internal pure returns (uint256[7][2] memory) {
        //convert bls pubkey bytes (len 96) to bytes[2] (len 48)
        bytes[2] memory gxy = _bytes96tobytes48(abi.encodePacked(blsPubKey[0], blsPubKey[1]));
        //conver to slices
        uint256[7][2] memory slices = [_bytes48toslices(gxy[0]), _bytes48toslices(gxy[1])];
        return slices;
    }

    function _verifySingleSignature(Evidence memory _evidence, uint256[2] memory blsPubKey)
        internal
        view
        returns (bool)
    {
        ProofParams memory params = abi.decode(_evidence.sigProof, (ProofParams));

        uint256[47] memory input;
        input[0] = 1;

        uint256[7][2] memory slices = _getBLSPubKeySlices(blsPubKey);

        // add to input
        uint256 inc = 1;
        for (uint256 i = 0; i < 2; i++) {
            for (uint256 j = 0; j < 7; j++) {
                input[inc] = slices[i][j];
                inc++;
            }
        }

        bytes[4] memory sig_slices = _bytes192tobytes48(_evidence.blockSignature);
        for (uint256 si = 0; si < 4; si++) {
            uint256[7] memory slice = _bytes48toslices(sig_slices[si]);
            for (uint256 i = 0; i < 7; i++) {
                input[inc] = slice[i];
                inc++;
            }
        }

        input[43] = uint256(_evidence.currentCommitteeRoot);
        input[44] = uint256(_evidence.nextCommitteeRoot);

        input[45] = uint256(_getChainHeader(_evidence.blockHash, _evidence.blockNumber, _evidence.chainID));

        bool result = singleVerifier.verifyProof(params.a, params.b, params.c, input);

        return result;
    }

    function _verifyAggregateSignature(Evidence memory _evidence, uint256 _committeeSize)
        internal
        view
        returns (bool)
    {
        uint256 routeIndex = _computeRouteIndex(_committeeSize);
        ISlashingAggregateVerifier verifier = aggVerifiers[routeIndex];

        ProofParams memory params = abi.decode(_evidence.aggProof, (ProofParams));

        uint256[5] memory input = [
            1,
            uint256(_evidence.currentCommitteeRoot),
            uint256(_evidence.nextCommitteeRoot),
            uint256(_getChainHeader(_evidence.blockHash, _evidence.blockNumber, _evidence.chainID)),
            0
        ];

        bool result = verifier.verifyProof(params.a, params.b, params.c, input);

        return result;
    }
}
