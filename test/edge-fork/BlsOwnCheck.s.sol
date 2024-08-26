pragma solidity ^0.8.20;

import "../../script/foundry/update/BaseScript.s.sol";
import "../foundry/CommitteeTree.t.sol";
import "../foundry/helpers/BLSProofHelper.sol";

contract BlsOwnCheckTest is BaseScript {
    uint256 constant PRIVATE_KEY_8 = 0x00000000000000000000000000000000000000000000000000000000499602d2 + 8;
    uint256 constant PRIVATE_KEY_9 = 0x00000000000000000000000000000000000000000000000000000000499602d2 + 9;

    function run() public {
        _readContracts();

        _redeployService();
        _redeployCommittee();

        uint32 CHAIN_ID = lagrangeCommittee.chainIDs(0);
        address operator = lagrangeCommittee.committeeAddrs(CHAIN_ID, 0);

        console.log(CHAIN_ID, operator);

        uint256[2][] memory orgBlsKeys = lagrangeCommittee.getBlsPubKeys(operator);

        vm.startPrank(operator);
        {
            uint256[] memory _additionalBlsPrivateKeys = new uint256[](1);
            _additionalBlsPrivateKeys[0] = PRIVATE_KEY_9;
            uint256[2][] memory _additionalBlsPubKeys = BLSProofHelper.calcG1PubKeys(_additionalBlsPrivateKeys);

            IBLSKeyChecker.BLSKeyWithProof memory blsKeyWithProof =
                _calcProofForBLSKeys(operator, _additionalBlsPrivateKeys, "salt", block.timestamp + 60);
            lagrangeService.addBlsPubKeys(blsKeyWithProof);

            uint256[2][] memory newBlsKeys = lagrangeCommittee.getBlsPubKeys(operator);

            require(newBlsKeys.length == orgBlsKeys.length + 1);
            require(newBlsKeys[newBlsKeys.length - 1][0] == _additionalBlsPubKeys[0][0]);
            require(newBlsKeys[newBlsKeys.length - 1][1] == _additionalBlsPubKeys[0][1]);
            orgBlsKeys = newBlsKeys;
        }

        {
            uint256[] memory _newBlsPrivateKeys = new uint256[](1);
            _newBlsPrivateKeys[0] = PRIVATE_KEY_8;
            uint256[2][] memory _newBlsPubKeys = BLSProofHelper.calcG1PubKeys(_newBlsPrivateKeys);

            IBLSKeyChecker.BLSKeyWithProof memory blsKeyWithProof =
                _calcProofForBLSKeys(operator, _newBlsPrivateKeys, "salt2", block.timestamp + 60);
            lagrangeService.updateBlsPubKey(0, blsKeyWithProof);

            uint256[2][] memory newBlsKeys = lagrangeCommittee.getBlsPubKeys(operator);

            require(newBlsKeys.length == orgBlsKeys.length);
            require(newBlsKeys[0][0] == _newBlsPubKeys[0][0]);
            require(newBlsKeys[0][1] == _newBlsPubKeys[0][1]);
            orgBlsKeys = newBlsKeys;
        }

        {
            uint32[] memory _indicesToRemove;
            _indicesToRemove = new uint32[](1);
            _indicesToRemove[0] = 0;

            lagrangeService.removeBlsPubKeys(_indicesToRemove);

            uint256[2][] memory newBlsKeys = lagrangeCommittee.getBlsPubKeys(operator);

            require(newBlsKeys.length == orgBlsKeys.length - 1);
            require(newBlsKeys[0][0] == orgBlsKeys[1][0]);
            require(newBlsKeys[0][1] == orgBlsKeys[1][1]);
            orgBlsKeys = newBlsKeys;
        }

        vm.stopPrank();
    }

    function _calcProofForBLSKeys(address operator, uint256[] memory privateKeys, bytes32 salt, uint256 expiry)
        internal
        view
        virtual
        returns (IBLSKeyChecker.BLSKeyWithProof memory keyWithProof)
    {
        keyWithProof.blsG1PublicKeys = BLSProofHelper.calcG1PubKeys(privateKeys);
        if (privateKeys.length == 1 && privateKeys[0] == PRIVATE_KEY_8) {
            keyWithProof.aggG2PublicKey[0][1] =
                10964149981093673192878105862123136095629476340728221926737174498877223969648;
            keyWithProof.aggG2PublicKey[0][0] =
                15310411369620863421292035563000579947440359652734678186174074640222704784730;
            keyWithProof.aggG2PublicKey[1][1] =
                14394448488692205245100592077579864928867873913469847595739357980967122954289;
            keyWithProof.aggG2PublicKey[1][0] =
                12973493539966959469484148839766384057653485995822838495480890958868429837596;
        } else if (privateKeys.length == 1 && privateKeys[0] == PRIVATE_KEY_9) {
            keyWithProof.aggG2PublicKey[0][1] =
                443893656036388665233236242117188127065868835282453062133808678040015042429;
            keyWithProof.aggG2PublicKey[0][0] =
                7331548207031936603400747370621041517640282419366011168050780132447131164785;
            keyWithProof.aggG2PublicKey[1][1] =
                20990309432715278611468563170296783892531003311534251198264328329085429717735;
            keyWithProof.aggG2PublicKey[1][0] =
                19527508948082192170493175951834638819044026564976650183799921676597235202371;
        }
        keyWithProof.expiry = expiry;
        keyWithProof.salt = salt;
        bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);
        keyWithProof.signature = BLSProofHelper.generateBLSSignature(privateKeys, digestHash);
    }
}
