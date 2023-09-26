// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

contract BatchStorageMock {
    function getL2StoredBlockNumber() public view returns (uint256) {
        return block.number - 64;
    }
}
