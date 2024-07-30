// SPDX-License-Identifier: BUSL-1.1

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.20;

contract BatchStorageMock {
    function getL2StoredBlockNumber() public view returns (uint256) {
        return block.number - 64;
    }
}
