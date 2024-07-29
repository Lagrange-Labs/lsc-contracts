pragma solidity ^0.8.20;

// import "../../contracts/protocol/LagrangeService.sol";
// import "../../contracts/protocol/LagrangeCommittee.sol";
// import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";

import "../../script/update/BaseScript.s.sol";
import "../foundry/CommitteeTree.t.sol";

contract BlsOwnCheckTest is BaseScript {
    uint256 constant INFINIT_EXPIRY = 2000000000; // big enough

    mapping(bytes32 => IBLSKeyChecker.BLSKeyWithProof[]) knownBlsGroups;
    mapping(uint256 => uint256[6]) knownBlsPubKeys; // G1 : [0, 1] , G2(single aggr): [2, 3, 4, 5]
    address operator;
    uint32 CHAIN_ID;

    function run() public {
        _readContracts();

        _redeployService();
        _redeployCommittee();

        CHAIN_ID = lagrangeCommittee.chainIDs(0);
        operator = lagrangeCommittee.committeeAddrs(CHAIN_ID, 0);

        console.log(CHAIN_ID, operator);

        _prepareKnownBlsPubKeys();
        _prepareKnownBlsGroups();

        uint256[2][] memory orgBlsKeys = lagrangeCommittee.getBlsPubKeys(operator);

        vm.startPrank(operator);
        {
            uint256[2][] memory _additionalBlsPubKeys;
            _additionalBlsPubKeys = new uint256[2][](1);
            _additionalBlsPubKeys[0] = _readKnownBlsPubKey(9);

            IBLSKeyChecker.BLSKeyWithProof memory blsKeyWithProof =
                _calcProofForBLSKeys(operator, _additionalBlsPubKeys, "salt");
            lagrangeService.addBlsPubKeys(blsKeyWithProof);

            uint256[2][] memory newBlsKeys = lagrangeCommittee.getBlsPubKeys(operator);

            require(newBlsKeys.length == orgBlsKeys.length + 1);
            require(newBlsKeys[newBlsKeys.length - 1][0] == _additionalBlsPubKeys[0][0]);
            require(newBlsKeys[newBlsKeys.length - 1][1] == _additionalBlsPubKeys[0][1]);
            orgBlsKeys = newBlsKeys;
        }

        {
            uint256[2][] memory _newBlsPubKeys;
            _newBlsPubKeys = new uint256[2][](1);
            _newBlsPubKeys[0] = _readKnownBlsPubKey(8);

            IBLSKeyChecker.BLSKeyWithProof memory blsKeyWithProof =
                _calcProofForBLSKeys(operator, _newBlsPubKeys, "salt2");
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

    function _calcProofForBLSKeys(address _operator, uint256[2][] memory blsPubKeys, bytes32 salt)
        internal
        view
        virtual
        returns (IBLSKeyChecker.BLSKeyWithProof memory)
    {
        uint256 expiry = INFINIT_EXPIRY;
        bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(_operator, salt, expiry);

        for (uint256 k = 0; k < knownBlsGroups[digestHash].length; k++) {
            IBLSKeyChecker.BLSKeyWithProof storage keyWithProof = knownBlsGroups[digestHash][k];
            bool isSame = (keyWithProof.blsG1PublicKeys.length == blsPubKeys.length);

            for (uint256 i = 0; isSame && i < blsPubKeys.length; i++) {
                if (
                    keyWithProof.blsG1PublicKeys[i][0] != blsPubKeys[i][0]
                        || keyWithProof.blsG1PublicKeys[i][1] != blsPubKeys[i][1]
                ) {
                    isSame = false;
                    break;
                }
            }
            if (isSame) return keyWithProof;
        }

        console.log("----------------------------------------", _operator, expiry);
        console.logBytes32(digestHash);
        for (uint256 i = 0; i < blsPubKeys.length; i++) {
            console.log(blsPubKeys[i][0], blsPubKeys[i][1]);
        }
        require(false, "can't find");
    }

    function _prepareKnownBlsGroups() internal {
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            uint256 expiry = INFINIT_EXPIRY;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(9);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(9);
            if (block.chainid == 1) {
                keyWithProof.signature[0] =
                    16458927945364609100986276489687387516983344345381377578603091739021325701245;
                keyWithProof.signature[1] = 2494865180421118536293006014844598530799941176860286438602136457667064693064;
            } else if (block.chainid == 17000) {
                keyWithProof.signature[0] =
                    12177630601377768923725246412316644381777869038991487711748873528354205745878;
                keyWithProof.signature[1] =
                    16929053967035884932763402841157818357303872878434481012504452427790470078833;
            } else if (block.chainid == 11155111) {
                keyWithProof.signature[0] = 373877177936854032274227681363988134563275671598873283132083642758264062704;
                keyWithProof.signature[1] = 5582686790557201775385876629227053905295410899649960961066750713169351966784;
            }
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            uint256 expiry = INFINIT_EXPIRY;
            bytes32 salt = bytes32("salt2");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(8);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(8);
            if (block.chainid == 1) {
                keyWithProof.signature[0] =
                    13058311494488960738111177424271071540127905090670659823753508399017234350558;
                keyWithProof.signature[1] = 4983235965989700133880435282756013368937702805655298219492708872516315130486;
            } else if (block.chainid == 17000) {
                keyWithProof.signature[0] = 3330895628585681901961698303045282321528400568314149038416056162017663456766;
                keyWithProof.signature[1] = 6649078428698974327334713917032450501021792380707305006850349757054498958744;
            } else if (block.chainid == 11155111) {
                keyWithProof.signature[0] =
                    15580838774887600145420062761788318694103449923541934888453159955651361954378;
                keyWithProof.signature[1] = 8126223485552349200598828485515762047095593620210495509232671746514124430722;
            }
            knownBlsGroups[digestHash].push(keyWithProof);
        }
    }

    function _prepareKnownBlsPubKeys() internal {
        knownBlsPubKeys[8] = [
            7488930134124895260685527725261875091726218045265180598093526507102032884422,
            13935449650956411173566373722771762898327303510193151371511747394187935479114,
            10964149981093673192878105862123136095629476340728221926737174498877223969648,
            15310411369620863421292035563000579947440359652734678186174074640222704784730,
            14394448488692205245100592077579864928867873913469847595739357980967122954289,
            12973493539966959469484148839766384057653485995822838495480890958868429837596
        ];
        knownBlsPubKeys[9] = [
            5104320107249705116790025856072838933076898621083759786608232868510481586984,
            6736476236230418307417063814685629604769333753712855869529041990943955891580,
            443893656036388665233236242117188127065868835282453062133808678040015042429,
            7331548207031936603400747370621041517640282419366011168050780132447131164785,
            20990309432715278611468563170296783892531003311534251198264328329085429717735,
            19527508948082192170493175951834638819044026564976650183799921676597235202371
        ];
    }

    function _readKnownBlsPubKey(uint256 keyId) internal view returns (uint256[2] memory blsPubKey) {
        blsPubKey[0] = knownBlsPubKeys[keyId][0];
        blsPubKey[1] = knownBlsPubKeys[keyId][1];
    }

    function _readKnownBlsSingleAggr(uint256 keyId) internal view returns (uint256[2][2] memory aggG2PublicKey) {
        aggG2PublicKey[0][1] = knownBlsPubKeys[keyId][2];
        aggG2PublicKey[0][0] = knownBlsPubKeys[keyId][3];
        aggG2PublicKey[1][1] = knownBlsPubKeys[keyId][4];
        aggG2PublicKey[1][0] = knownBlsPubKeys[keyId][5];
    }
}
