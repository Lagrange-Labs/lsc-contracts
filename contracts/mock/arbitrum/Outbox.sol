// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE
// SPDX-License-Identifier: BUSL-1.1

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.20;

import "./IOutbox.sol";

/// @dev this error is thrown since certain functions are only expected to be used in simulations, not in actual txs
error SimulationOnlyEntrypoint();

contract Outbox is IOutbox {
    mapping(bytes32 => bytes32) public roots; // maps root hashes => L2 block hash

    function updateSendRoot(bytes32 root, bytes32 l2BlockHash) public {
        roots[root] = l2BlockHash;
    }
}
