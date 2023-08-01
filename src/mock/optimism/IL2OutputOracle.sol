// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE
// SPDX-License-Identifier: BUSL-1.1

// solhint-disable-next-line compiler-version
pragma solidity ^0.8.12;

import {Types} from "./Types.sol";

interface IL2OutputOracle {

    function getL2OutputAfter(uint256 _l2BlockNumber)
        external
        view
        returns (Types.OutputProposal memory);
        
    function proposeL2Output(
        bytes32 _outputRoot,
        uint256 _l2BlockNumber,
        bytes32 _l1BlockHash,
        uint256 _l1BlockNumber
    ) external payable;

/*
    function forceL2Output(
        bytes32 k,
        bytes32 v,
    ) external;
*/
    function nextBlockNumber() external view returns (uint256);
    function latestBlockNumber() external view returns (uint256);
}
