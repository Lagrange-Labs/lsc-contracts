// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.12;

/**
 * @dev Interface poseidon hash function 2 elements
 */
contract PoseidonUnit2 {
    function poseidon(uint256[2] memory) public pure returns (uint256) {}
}

/**
 * @dev Interface poseidon hash function 5 elements
 */
contract PoseidonUnit5 {
    function poseidon(uint256[5] memory) public pure returns (uint256) {}
}

/**
 * @dev Interface poseidon hash function 6 elements
 */
contract PoseidonUnit6 {
    function poseidon(uint256[6] memory) public pure returns (uint256) {}
}

/**
 * @dev Rollup helper functions
 */
contract HermezHelpers {
    PoseidonUnit2 _insPoseidonUnit2;
    PoseidonUnit5 _insPoseidonUnit5;
    PoseidonUnit6 _insPoseidonUnit6;

    /**
     * @dev Load poseidon smart contract
     * @param _poseidon2Elements Poseidon contract address for 2 elements
     * @param _poseidon5Elements Poseidon contract address for 5 elements
     * @param _poseidon6Elements Poseidon contract address for 6 elements
     */
    function _initializeHelpers(address _poseidon2Elements, address _poseidon5Elements, address _poseidon6Elements)
        internal
    {
        _insPoseidonUnit2 = PoseidonUnit2(_poseidon2Elements);
        _insPoseidonUnit5 = PoseidonUnit5(_poseidon5Elements);
        _insPoseidonUnit6 = PoseidonUnit6(_poseidon6Elements);
    }

    /**
     * @dev Hash poseidon for 2 elements
     * @param inputs Poseidon input array of 2 elements
     * @return Poseidon hash
     */
    function _hash2Elements(uint256[2] memory inputs) internal view returns (uint256) {
        return _insPoseidonUnit2.poseidon(inputs);
    }

    /**
     * @dev Hash poseidon for 5 elements
     * @param inputs Poseidon input array of 5 elements
     * @return Poseidon hash
     */
    function _hash5Elements(uint256[5] memory inputs) internal view returns (uint256) {
        return _insPoseidonUnit5.poseidon(inputs);
    }

    /**
     * @dev Hash poseidon for 6 elements
     * @param inputs Poseidon input array of 6 elements
     * @return Poseidon hash
     */
    function _hash6Elements(uint256[6] memory inputs) internal view returns (uint256) {
        return _insPoseidonUnit6.poseidon(inputs);
    }
}
