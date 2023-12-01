// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IVoteWeigher} from "../interfaces/IVoteWeigher.sol";

contract VoteWeigherMock is IVoteWeigher {
    address public serviceManager;

    constructor(address _serviceManager) {
        serviceManager = _serviceManager;
    }

    function weightOfOperator(uint8, /*quorumNumber*/ address /*operator*/ ) external pure override returns (uint96) {
        return uint96(100000000);
    }
}
