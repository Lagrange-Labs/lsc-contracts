// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {ISlashingSingleVerifierTriage} from "../interfaces/ISlashingSingleVerifierTriage.sol";
import {ISlashingSingleVerifier} from "../interfaces/ISlashingSingleVerifier.sol";
import {EvidenceVerifier} from "./EvidenceVerifier.sol";

contract SlashingSingleVerifierTriage is ISlashingSingleVerifierTriage, Initializable, OwnableUpgradeable {
    mapping(uint256 => address) public verifiers;

    constructor() {}

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    struct proofParams {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
        uint256[47] input;
    }

    function setRoute(uint256 routeIndex, address verifierAddress) external onlyOwner {
        verifiers[routeIndex] = verifierAddress;
    }

    function _getChainHeader(bytes32 blockHash, uint256 blockNumber, uint32 chainID)
        internal
        view
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

    function _bytes96tobytes48(bytes memory bpk) public view returns (bytes[2] memory) {
        require(bpk.length == 96, "BLS public key must be provided in a form that is 96 bytes.");
        bytes[2] memory gxy = [new bytes(48), new bytes(48)];
        for (uint256 i = 0; i < 48; i++) {
            gxy[0][i] = bpk[i];
            gxy[1][i] = bpk[i + 48];
        }
        return [abi.encodePacked(gxy[0]), abi.encodePacked(gxy[1])];
    }

    function _bytes48toslices(bytes memory b48) internal view returns (uint256[7] memory) {
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

    function _bytes192tobytes48(bytes memory bpk) internal view returns (bytes[4] memory) {
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

    function _getBLSPubKeySlices(bytes calldata blsPubKey) internal view returns (uint256[7][2] memory) {
        //convert bls pubkey bytes (len 96) to bytes[2] (len 48)
        bytes[2] memory gxy = _bytes96tobytes48(blsPubKey);
        //conver to slices
        uint256[7][2] memory slices = [_bytes48toslices(gxy[0]), _bytes48toslices(gxy[1])];
        return slices;
    }

    function verify(EvidenceVerifier.Evidence memory _evidence, bytes calldata blsPubKey, uint256 committeeSize)
        external
        view
        returns (bool)
    {
        address verifierAddress = verifiers[_computeRouteIndex(committeeSize)];
        require(
            verifierAddress != address(0),
            "SlashingSingleVerifierTriage: Verifier address not set for committee size specified."
        );

        ISlashingSingleVerifier verifier = ISlashingSingleVerifier(verifierAddress);
        proofParams memory params = abi.decode(_evidence.sigProof, (proofParams));

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

    function _computeRouteIndex(uint256 committeeSize) internal pure returns (uint256) {
        uint256 routeIndex = 1;
        while (routeIndex < committeeSize) {
            routeIndex = routeIndex * 2;
        }
        return routeIndex;
    }
}
