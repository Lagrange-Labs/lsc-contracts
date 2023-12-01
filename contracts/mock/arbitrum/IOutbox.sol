// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE
// SPDX-License-Identifier: BUSL-1.1

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.12;

interface IOutbox {
    function roots(bytes32) external view returns (bytes32); // maps root hashes => L2 block hash
    function updateSendRoot(bytes32 root, bytes32 l2BlockHash) external;
}
