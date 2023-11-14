// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {OptimismVerifier} from "./OptimismVerifier.sol";
import {ArbitrumVerifier} from "./ArbitrumVerifier.sol";
import {ISlashingAggregateVerifierTriage} from "../interfaces/ISlashingAggregateVerifierTriage.sol";
import {ISlashingSingleVerifier} from "../interfaces/ISlashingSingleVerifier.sol";
import {Common} from "./Common.sol";

contract EvidenceVerifier is Common {
    // Evidence is the data structure to store the slashing evidence.
    struct Evidence {
        address operator;
        bytes32 blockHash;
        bytes32 correctBlockHash;
        bytes32 currentCommitteeRoot;
        bytes32 correctCurrentCommitteeRoot;
        bytes32 nextCommitteeRoot;
        bytes32 correctNextCommitteeRoot;
        uint256 blockNumber;
        uint256 epochBlockNumber;
        bytes blockSignature; // 96-byte
        bytes commitSignature; // 65-byte
        uint32 chainID;
        bytes attestBlockHeader;
        //bytes checkpointBlockHeader;
        bytes sigProof;
        bytes aggProof;
    }

    struct proofParamsSingle {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
        uint256[47] input;
    }

    ISlashingSingleVerifier public verifier;

    uint256 public constant CHAIN_ID_MAINNET = 1;
    uint256 public constant CHAIN_ID_OPTIMISM_BEDROCK = 420;
    uint256 public constant CHAIN_ID_BASE = 84531;
    uint256 public constant CHAIN_ID_ARBITRUM_NITRO = 421613;

    OptimismVerifier OptVerify;
    ArbitrumVerifier ArbVerify;

    constructor(address verifierAddress) {
        verifier = ISlashingSingleVerifier(verifierAddress);
    }

    function setArbAddr(ArbitrumVerifier _arb) public {
        ArbVerify = _arb;
    }

    function setOptAddr(OptimismVerifier _opt) public {
        OptVerify = _opt;
    }

    function getArbAddr() public view returns (address /*onlyOwner*/ ) {
        return address(ArbVerify);
    }

    function getOptAddr() public view returns (address /*onlyOwner*/ ) {
        return address(OptVerify);
    }

    function calculateBlockHash(bytes memory rlpData) public pure returns (bytes32) {
        return keccak256(rlpData);
    }

    // Verify that comparisonNumber (block number) is in raw block header (rlpData) and raw block header matches comparisonBlockHash.  ChainID provides for network segmentation.
    function verifyBlockNumber(
        uint256 comparisonNumber,
        bytes memory rlpData,
        bytes32 comparisonBlockHash,
        uint256 chainID
    ) public pure returns (bool) {
        bool res = _verifyBlockNumber(comparisonNumber, rlpData, comparisonBlockHash, chainID);
        if (chainID == CHAIN_ID_ARBITRUM_NITRO) {
            //            (success, checkpoint) = verifyArbBlock();
        } else if (chainID == CHAIN_ID_OPTIMISM_BEDROCK) {
            //            (success, checkpoint) = verifyOptBlock();
        }
        return res;
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
                evidence.epochBlockNumber,
                evidence.blockSignature,
                evidence.chainID
            )
        );
    }

    function _getChainHeader(bytes32 blockHash, uint256 blockNumber, uint32 chainID)
        internal
        pure
        returns (uint256, uint256)
    {
        uint256 _chainHeader1;
        uint256 _chainHeader2;

        bytes memory chainHeader = abi.encodePacked(blockHash, uint256(blockNumber), uint32(chainID));

        bytes32 chHash = keccak256(chainHeader);
        bytes16 ch1 = bytes16(chHash);
        bytes16 ch2 = bytes16(chHash << 128);

        bytes32 _ch1 = bytes32(ch1) >> 128;
        bytes32 _ch2 = bytes32(ch2) >> 128;

        _chainHeader1 = uint256(_ch1);
        _chainHeader2 = uint256(_ch2);

        return (_chainHeader1, _chainHeader2);
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

    function _getBLSPubKeySlices(bytes calldata blsPubKey) internal pure returns (uint256[7][2] memory) {
        //convert bls pubkey bytes (len 96) to bytes[2] (len 48)
        bytes[2] memory gxy = _bytes96tobytes48(blsPubKey);
        //conver to slices
        uint256[7][2] memory slices = [_bytes48toslices(gxy[0]), _bytes48toslices(gxy[1])];
        return slices;
    }

    function verifySingle(EvidenceVerifier.Evidence memory _evidence, bytes calldata blsPubKey)
        external
        view
        returns (bool)
    {
        proofParamsSingle memory params = abi.decode(_evidence.sigProof, (proofParamsSingle));

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

        (input[45], input[46]) = _getChainHeader(_evidence.blockHash, _evidence.blockNumber, _evidence.chainID);

        bool result = verifier.verifyProof(params.a, params.b, params.c, input);

        return result;
    }
}
