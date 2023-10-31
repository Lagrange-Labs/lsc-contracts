// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";
import {ISlashingSingleVerifier} from "../interfaces/ISlashingSingleVerifier.sol";

interface ISlashingSingleVerifierTriage {
    function verify(EvidenceVerifier.Evidence calldata _evidence, bytes memory blsPubKey, uint256 committeeSize)
        external
        returns (bool);
}
