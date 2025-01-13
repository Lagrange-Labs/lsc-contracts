// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "eigenlayer-middleware/libraries/BN254.sol";

import {EmptyContract} from "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";

import "../../contracts/protocol/LagrangeService.sol";
import "../../contracts/protocol/LagrangeCommittee.sol";
import "../../contracts/protocol/EvidenceVerifier.sol";
import "../../contracts/protocol/VoteWeigher.sol";
import "../../contracts/library/StakeManager.sol";
import "./helpers/BLSProofHelper.sol";

import {WETH9} from "../../contracts/mock/WETH9.sol";
import {AVSDirectoryMock} from "../../contracts/mock/AVSDirectoryMock.sol";

// This contract is used to deploy LagrangeService contract to the testnet
contract LagrangeDeployer is Test {
    LagrangeService public lagrangeService;
    LagrangeService public lagrangeServiceImp;
    LagrangeCommittee public lagrangeCommittee;
    LagrangeCommittee public lagrangeCommitteeImp;
    StakeManager public stakeManager;
    StakeManager public stakeManagerImp;
    EvidenceVerifier public evidenceVerifier;
    EvidenceVerifier public evidenceVerifierImp;
    VoteWeigher public voteWeigher;
    VoteWeigher public voteWeigherImp;
    IAVSDirectory public avsDirectory;

    WETH9 public token;
    ProxyAdmin public proxyAdmin;
    EmptyContract public emptyContract;

    uint32 public constant CHAIN_ID = 1337;
    uint256 public constant START_EPOCH = 30;
    uint256 public constant EPOCH_PERIOD = 70;
    uint256 public constant FREEZE_DURATION = 10;
    uint96 public constant MIN_WEIGHT = 1e6;
    uint96 public constant MAX_WEIGHT = 5e6;

    uint256 internal adminPrivateKey;

    uint256[2][] private knownG1PubKeys;
    IBLSKeyChecker.BLSKeyWithProof[] private knownG2PubKeys; // G1 : [0, 1] , G2(single aggr): [2, 3, 4, 5]

    function setUp() public virtual {
        adminPrivateKey = 1234567890;
        avsDirectory = IAVSDirectory(new AVSDirectoryMock());

        _deployLagrangeContracts();
        _registerChain();
        _prepareKnownPubKeys();
    }

    function testDeploy() public view {
        console.log("LagrangeService: ", address(lagrangeService));
    }

    function _deployLagrangeContracts() internal {
        address sender = vm.addr(adminPrivateKey); // admin
        vm.startPrank(sender);

        // deploy proxy admin for ability to upgrade proxy contracts
        proxyAdmin = new ProxyAdmin();
        token = new WETH9();

        // deploy upgradeable proxy contracts
        emptyContract = new EmptyContract();
        lagrangeCommittee =
            LagrangeCommittee(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        lagrangeService =
            LagrangeService(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        voteWeigher =
            VoteWeigher(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        stakeManager =
            StakeManager(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        evidenceVerifier =
            EvidenceVerifier(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));

        // deploy implementation contracts
        lagrangeCommitteeImp = new LagrangeCommittee(lagrangeService, IVoteWeigher(voteWeigher));
        voteWeigherImp = new VoteWeigher(IStakeManager(stakeManager));
        stakeManagerImp = new StakeManager(address(lagrangeService));
        lagrangeServiceImp =
            new LagrangeService(lagrangeCommittee, stakeManager, address(avsDirectory), IVoteWeigher(voteWeigher));
        evidenceVerifierImp = new EvidenceVerifier(lagrangeCommittee, stakeManager);

        // upgrade proxy contracts
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))),
            address(lagrangeCommitteeImp),
            abi.encodeWithSelector(LagrangeCommittee.initialize.selector, sender)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(voteWeigher))),
            address(voteWeigherImp),
            abi.encodeWithSelector(VoteWeigher.initialize.selector, sender)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeService))),
            address(lagrangeServiceImp),
            abi.encodeWithSelector(LagrangeService.initialize.selector, sender, evidenceVerifier)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(stakeManager))),
            address(stakeManagerImp),
            abi.encodeWithSelector(StakeManager.initialize.selector, sender)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(evidenceVerifier))),
            address(evidenceVerifierImp),
            abi.encodeWithSelector(StakeManager.initialize.selector, sender)
        );

        vm.stopPrank();
    }

    function _prepareKnownPubKeys() internal {
        delete knownG1PubKeys;
        for (uint256 i; i < 10; i++) {
            uint256 privateKey = i + 0x00000000000000000000000000000000000000000000000000000000499602d3; // i + 1234567891
            knownG1PubKeys.push(BLSProofHelper.calcG1PubKey(privateKey));
        }
        delete knownG2PubKeys;
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[0];
            keyWithProof.aggG2PublicKey[0][1] =
                18278389646821250305699901000115272146394424141541828377935595968842598839558;
            keyWithProof.aggG2PublicKey[0][0] =
                12579183095081433599766482319454236990681757097696886619684754875971808282528;
            keyWithProof.aggG2PublicKey[1][1] =
                20239483229501965127848803443842720859367640498407711614275728697924046264052;
            keyWithProof.aggG2PublicKey[1][0] =
                301058701789884254540007586813170179394916203305451331856781011130144675825;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[1];
            keyWithProof.aggG2PublicKey[0][1] =
                11719845012413673801703667786567662213265694676671288352855808932384682431881;
            keyWithProof.aggG2PublicKey[0][0] =
                6823568383881319519261392741304024190595984631371163418049807563026643400980;
            keyWithProof.aggG2PublicKey[1][1] =
                3081452905376440102681653793385791209108350053621988029658296650508784582338;
            keyWithProof.aggG2PublicKey[1][0] =
                875712813259364385780580626011750444654391868418282961783748360116366069537;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[2];
            keyWithProof.aggG2PublicKey[0][1] =
                19507275371225444019445233081877960404704997393356797728143325061772399976476;
            keyWithProof.aggG2PublicKey[0][0] =
                475070893533532420712014884828671972949538696482596893590438057561718589170;
            keyWithProof.aggG2PublicKey[1][1] =
                8868046512188198398419557220589769308785955674549281474310135929738749828177;
            keyWithProof.aggG2PublicKey[1][0] =
                420886234749049305841625607615035735861501343506645230874610312342184831165;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[3];
            keyWithProof.aggG2PublicKey[0][1] =
                11109463383715458240664741650918099975849758278445994708048641968680706511355;
            keyWithProof.aggG2PublicKey[0][0] =
                12008407931379194185911026077874094449936223826749559708327679321600484423090;
            keyWithProof.aggG2PublicKey[1][1] =
                6602525143408714129029973362291889392386107781885595063853043826245846429343;
            keyWithProof.aggG2PublicKey[1][0] =
                21291856834995308934258468397503222741315670719619471617212692412136537782237;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[4];
            keyWithProof.aggG2PublicKey[0][1] =
                20049517053808342645106409346886532414402923729571269478545153326077254852758;
            keyWithProof.aggG2PublicKey[0][0] =
                16637000600429576289199176677854110041770372522651654636117206624140894936326;
            keyWithProof.aggG2PublicKey[1][1] =
                7931094752013541321559279278684470554865639568467244859359262592043342414853;
            keyWithProof.aggG2PublicKey[1][0] =
                11329647147725378369252072304963615161727424371724217539183652992499112702725;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[5];
            keyWithProof.aggG2PublicKey[0][1] =
                16364955548359037732967290789495758904415571905944457529533343755765055479260;
            keyWithProof.aggG2PublicKey[0][0] =
                21250997378529433309340214001723853630819246858092196730665530151656798036416;
            keyWithProof.aggG2PublicKey[1][1] =
                14857850352446278682062547738018922032691334581432852319803313494979559037190;
            keyWithProof.aggG2PublicKey[1][0] =
                17699850262963019306103688730097257124272195633347728431794406891132933735609;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[6];
            keyWithProof.aggG2PublicKey[0][1] =
                19106999197839746026879081489652536470520182100589471478485604517947235695507;
            keyWithProof.aggG2PublicKey[0][0] =
                8439322804272709701029755432073738623826649688854922175870380736863056489123;
            keyWithProof.aggG2PublicKey[1][1] =
                16293239184803271038570032818652661643990321682546200658990422537570731005882;
            keyWithProof.aggG2PublicKey[1][0] =
                14991123907036909007453648001348768558470933594823789366537925858755595116713;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[7];
            keyWithProof.aggG2PublicKey[0][1] =
                10964149981093673192878105862123136095629476340728221926737174498877223969648;
            keyWithProof.aggG2PublicKey[0][0] =
                15310411369620863421292035563000579947440359652734678186174074640222704784730;
            keyWithProof.aggG2PublicKey[1][1] =
                14394448488692205245100592077579864928867873913469847595739357980967122954289;
            keyWithProof.aggG2PublicKey[1][0] =
                12973493539966959469484148839766384057653485995822838495480890958868429837596;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[8];
            keyWithProof.aggG2PublicKey[0][1] =
                443893656036388665233236242117188127065868835282453062133808678040015042429;
            keyWithProof.aggG2PublicKey[0][0] =
                7331548207031936603400747370621041517640282419366011168050780132447131164785;
            keyWithProof.aggG2PublicKey[1][1] =
                20990309432715278611468563170296783892531003311534251198264328329085429717735;
            keyWithProof.aggG2PublicKey[1][0] =
                19527508948082192170493175951834638819044026564976650183799921676597235202371;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[9];
            keyWithProof.aggG2PublicKey[0][1] =
                4890506482923786599569700830167959444180769098681357099112133009542545887444;
            keyWithProof.aggG2PublicKey[0][0] =
                11825261625679047237440697905015481839791205959279400784332086489473736078128;
            keyWithProof.aggG2PublicKey[1][1] =
                13842187764997607089802819067749287648911556700691654766053570930409077059065;
            keyWithProof.aggG2PublicKey[1][0] =
                559501346307597358306005794386061567116703940240828021190684518976035514213;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](2);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[1];
            keyWithProof.blsG1PublicKeys[1] = knownG1PubKeys[2];
            keyWithProof.aggG2PublicKey[0][1] =
                1436130010253058561349149611592986290934628865731875470070282695245872240666;
            keyWithProof.aggG2PublicKey[0][0] =
                7578502386265024235754802017104054800698406382804724741015093778654852635282;
            keyWithProof.aggG2PublicKey[1][1] =
                5114341255269544452401726150392607561398256980868448135390245953108770572183;
            keyWithProof.aggG2PublicKey[1][0] =
                18171377127265906515233897598526544722054598806864022415405699900398453279838;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](3);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[1];
            keyWithProof.blsG1PublicKeys[1] = knownG1PubKeys[2];
            keyWithProof.blsG1PublicKeys[2] = knownG1PubKeys[3];
            keyWithProof.aggG2PublicKey[0][1] =
                14020416375286999806182823015391471396267118147177798912637729098797615698034;
            keyWithProof.aggG2PublicKey[0][0] =
                17675257955736224395756686823565200807024378550714926944512831770660957350662;
            keyWithProof.aggG2PublicKey[1][1] =
                10498025079967091468307570108978201557199116610816331093720310741816111715287;
            keyWithProof.aggG2PublicKey[1][0] =
                21390814521535213786481949944100584184214797449493352815966669025419414797309;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](4);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[4];
            keyWithProof.blsG1PublicKeys[1] = knownG1PubKeys[5];
            keyWithProof.blsG1PublicKeys[2] = knownG1PubKeys[6];
            keyWithProof.blsG1PublicKeys[3] = knownG1PubKeys[7];
            keyWithProof.aggG2PublicKey[0][1] =
                1149916458657944912061164325406778726656111742779587960535580564729709165122;
            keyWithProof.aggG2PublicKey[0][0] =
                18873711714202196964289589515681140807643041155889655824025149306090934601992;
            keyWithProof.aggG2PublicKey[1][1] =
                3266387748569560375102829718109257620384034916503067447479562991241789932484;
            keyWithProof.aggG2PublicKey[1][0] =
                20590321380350934733756372600333434645461469888436858902424026979565468990377;
            knownG2PubKeys.push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
            keyWithProof.blsG1PublicKeys = new uint256[2][](2);
            keyWithProof.blsG1PublicKeys[0] = knownG1PubKeys[1];
            keyWithProof.blsG1PublicKeys[1] = knownG1PubKeys[2];
            keyWithProof.aggG2PublicKey[0][1] =
                1436130010253058561349149611592986290934628865731875470070282695245872240666;
            keyWithProof.aggG2PublicKey[0][0] =
                7578502386265024235754802017104054800698406382804724741015093778654852635282;
            keyWithProof.aggG2PublicKey[1][1] =
                5114341255269544452401726150392607561398256980868448135390245953108770572183;
            keyWithProof.aggG2PublicKey[1][0] =
                18171377127265906515233897598526544722054598806864022415405699900398453279838;
            knownG2PubKeys.push(keyWithProof);
        }
    }

    function _registerChain() internal {
        vm.roll(START_EPOCH);
        vm.startPrank(vm.addr(adminPrivateKey));

        // register chains
        lagrangeCommittee.registerChain(
            CHAIN_ID,
            1,
            EPOCH_PERIOD,
            FREEZE_DURATION,
            0,
            MIN_WEIGHT, // minWeight
            MAX_WEIGHT // maxWeight
        );
        lagrangeCommittee.registerChain(
            CHAIN_ID + 1,
            1,
            EPOCH_PERIOD * 2,
            FREEZE_DURATION * 2,
            0,
            MIN_WEIGHT, // minWeight
            MAX_WEIGHT // maxWeight
        );
        // register token multiplier
        IVoteWeigher.TokenMultiplier[] memory multipliers = new IVoteWeigher.TokenMultiplier[](1);
        multipliers[0] = IVoteWeigher.TokenMultiplier(address(token), 1e9);
        voteWeigher.addQuorumMultiplier(0, multipliers);

        // add tokens to whitelist
        address[] memory tokens = new address[](1);
        tokens[0] = address(token);
        stakeManager.addTokensToWhitelist(tokens);

        vm.stopPrank();
    }

    function _deposit(address operator, uint256 amount) internal {
        vm.startPrank(operator);

        token.deposit{value: amount}();
        token.approve(address(stakeManager), amount);

        // deposit tokens to stake manager
        stakeManager.deposit(IERC20(address(token)), amount);

        vm.stopPrank();
    }

    function _registerOperator(
        address operator,
        uint256 privateKey,
        uint256 amount,
        uint256[] memory blsPrivateKeys,
        uint32 chainID
    ) internal {
        vm.deal(operator, 1e19);
        // add operator to whitelist
        vm.prank(lagrangeService.owner());
        address[] memory operators = new address[](1);
        operators[0] = operator;
        lagrangeService.addOperatorsToWhitelist(operators);

        _deposit(operator, amount);

        vm.startPrank(operator);
        // register operator

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        {
            operatorSignature.expiry = block.timestamp + 60;
            operatorSignature.salt = bytes32(0x0);
            bytes32 digest = avsDirectory.calculateOperatorAVSRegistrationDigestHash(
                operator, address(lagrangeService), operatorSignature.salt, operatorSignature.expiry
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
            operatorSignature.signature = abi.encodePacked(r, s, v);
        }

        (uint256 startBlock,,, uint256 duration, uint256 freezeDuration,,,) = lagrangeCommittee.committeeParams(chainID);
        vm.roll(startBlock + duration - freezeDuration - 1);

        IBLSKeyChecker.BLSKeyWithProof memory proof =
            _calcProofForBLSKeys(operator, blsPrivateKeys, bytes32("salt"), block.timestamp + 60);

        if (blsPrivateKeys.length != 1) {
            vm.expectRevert("Exactly one BLS key is required per operator");
        }

        lagrangeService.register(operator, proof, operatorSignature);

        lagrangeCommittee.getEpochNumber(chainID, block.number);
        lagrangeCommittee.isLocked(chainID);

        lagrangeService.subscribe(chainID);

        vm.stopPrank();
    }

    function _findG2PubKey(uint256[2][] memory blsPubKeys)
        internal
        view
        virtual
        returns (IBLSKeyChecker.BLSKeyWithProof memory keyWithProof)
    {
        for (uint256 k = 0; k < knownG2PubKeys.length; k++) {
            IBLSKeyChecker.BLSKeyWithProof storage g2PubKey = knownG2PubKeys[k];
            bool isSame = (g2PubKey.blsG1PublicKeys.length == blsPubKeys.length);

            for (uint256 i = 0; isSame && i < blsPubKeys.length; i++) {
                if (
                    g2PubKey.blsG1PublicKeys[i][0] != blsPubKeys[i][0]
                        || g2PubKey.blsG1PublicKeys[i][1] != blsPubKeys[i][1]
                ) {
                    isSame = false;
                    break;
                }
            }
            if (isSame) return g2PubKey;
        }

        console.log("----------------------------------------");
        for (uint256 i = 0; i < blsPubKeys.length; i++) {
            console.log(blsPubKeys[i][0], blsPubKeys[i][1]);
        }
        require(false, "can't find");
    }

    function _calcProofForBLSKeys(address operator, uint256[] memory privateKeys, bytes32 salt, uint256 expiry)
        internal
        view
        virtual
        returns (IBLSKeyChecker.BLSKeyWithProof memory keyWithProof)
    {
        keyWithProof = _findG2PubKey(BLSProofHelper.calcG1PubKeys(privateKeys));
        keyWithProof.expiry = expiry;
        keyWithProof.salt = salt;
        bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);
        keyWithProof.signature = BLSProofHelper.generateBLSSignature(privateKeys, digestHash);
    }

    function _calcProofForBLSKey(address operator, uint256 privateKey, bytes32 salt, uint256 expiry)
        internal
        view
        returns (IBLSKeyChecker.BLSKeyWithProof memory keyWithProof)
    {
        uint256[] memory privateKeys = new uint256[](1);
        privateKeys[0] = privateKey;
        return _calcProofForBLSKeys(operator, privateKeys, salt, expiry);
    }

    function _readKnownBlsPubKey(uint256 keyId) internal view returns (uint256[2] memory blsPubKey) {
        uint256 privateKey = _readKnownBlsPrivateKey(keyId);
        return BLSProofHelper.calcG1PubKey(privateKey);
    }

    function _readKnownBlsPrivateKey(uint256 keyId) internal pure returns (uint256 blsPrivateKey) {
        return keyId + 0x00000000000000000000000000000000000000000000000000000000499602d2; // i + 1234567891
    }
}
