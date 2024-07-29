// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {EmptyContract} from "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";

import "../../contracts/protocol/LagrangeService.sol";
import "../../contracts/protocol/LagrangeCommittee.sol";
import "../../contracts/protocol/EvidenceVerifier.sol";
import "../../contracts/protocol/VoteWeigher.sol";
import "../../contracts/library/StakeManager.sol";

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

    mapping(bytes32 => IBLSKeyChecker.BLSKeyWithProof[]) private knownBlsGroups;
    mapping(uint256 => uint256[6]) private knownBlsPubKeys; // G1 : [0, 1] , G2(single aggr): [2, 3, 4, 5]

    function setUp() public virtual {
        adminPrivateKey = 1234567890;
        avsDirectory = IAVSDirectory(new AVSDirectoryMock());

        _deployLagrangeContracts();
        _registerChain();
        _prepareKnownBlsPubKeys();
        _prepareKnownBlsGroups();
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

    function _prepareKnownBlsPubKeys() internal {
        knownBlsPubKeys[1] = [
            20545566521870365205556113210563293367690778742407920553261414530195018910715,
            3810931577929286987941494315798961488626940522750116988265143865141196490387,
            18278389646821250305699901000115272146394424141541828377935595968842598839558,
            12579183095081433599766482319454236990681757097696886619684754875971808282528,
            20239483229501965127848803443842720859367640498407711614275728697924046264052,
            301058701789884254540007586813170179394916203305451331856781011130144675825
        ];
        knownBlsPubKeys[2] = [
            6188567693588639773359247442075250301875946893450591291984608313433056322940,
            12540808364665293681985345794763782578142148289057530577303063823278783323510,
            11719845012413673801703667786567662213265694676671288352855808932384682431881,
            6823568383881319519261392741304024190595984631371163418049807563026643400980,
            3081452905376440102681653793385791209108350053621988029658296650508784582338,
            875712813259364385780580626011750444654391868418282961783748360116366069537
        ];
        knownBlsPubKeys[3] = [
            19632462091539683515207234491244840740704719850251373559915157344280436112073,
            20684419267947419311323804514096337398560736866816496884208124258769697726071,
            19507275371225444019445233081877960404704997393356797728143325061772399976476,
            475070893533532420712014884828671972949538696482596893590438057561718589170,
            8868046512188198398419557220589769308785955674549281474310135929738749828177,
            420886234749049305841625607615035735861501343506645230874610312342184831165
        ];
        knownBlsPubKeys[4] = [
            17507772055066822922814238173045648924735192169947039583908116371612152730666,
            16872848925725941819437582517491476766890448580122069482753949040290944662424,
            11109463383715458240664741650918099975849758278445994708048641968680706511355,
            12008407931379194185911026077874094449936223826749559708327679321600484423090,
            6602525143408714129029973362291889392386107781885595063853043826245846429343,
            21291856834995308934258468397503222741315670719619471617212692412136537782237
        ];
        knownBlsPubKeys[5] = [
            21826169014968926087335024789186599358273352772244336699214854996117180217400,
            13325171345406194627160763490056610897175496813572850375683755102072239590350,
            20049517053808342645106409346886532414402923729571269478545153326077254852758,
            16637000600429576289199176677854110041770372522651654636117206624140894936326,
            7931094752013541321559279278684470554865639568467244859359262592043342414853,
            11329647147725378369252072304963615161727424371724217539183652992499112702725
        ];
        knownBlsPubKeys[6] = [
            17511030193755723353892118611886304525823464349858389058323320206539611325190,
            1133299527419113806650837894444218003915200061826097239802054114943539291676,
            16364955548359037732967290789495758904415571905944457529533343755765055479260,
            21250997378529433309340214001723853630819246858092196730665530151656798036416,
            14857850352446278682062547738018922032691334581432852319803313494979559037190,
            17699850262963019306103688730097257124272195633347728431794406891132933735609
        ];
        knownBlsPubKeys[7] = [
            1891949825440423232321920360641950879475934871400863560535934738281152751162,
            9494292238460217734060104969843431670659268688709808726898660252751840229247,
            19106999197839746026879081489652536470520182100589471478485604517947235695507,
            8439322804272709701029755432073738623826649688854922175870380736863056489123,
            16293239184803271038570032818652661643990321682546200658990422537570731005882,
            14991123907036909007453648001348768558470933594823789366537925858755595116713
        ];
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
        knownBlsPubKeys[10] = [
            8391537282600150072567609115086398798965774691481441754000227287326108765943,
            5520507092504038151824502794946258986194079899860183182921066337464424559283,
            4890506482923786599569700830167959444180769098681357099112133009542545887444,
            11825261625679047237440697905015481839791205959279400784332086489473736078128,
            13842187764997607089802819067749287648911556700691654766053570930409077059065,
            559501346307597358306005794386061567116703940240828021190684518976035514213
        ];
    }

    function _prepareKnownBlsGroups() internal virtual {
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x052b91ad9732D1bcE0dDAe15a4545e5c65D02443);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(1);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(1);
            keyWithProof.signature[0] = 17199323088193543277570612595864217798951261672450339001232167639422567643196;
            keyWithProof.signature[1] = 751021425588827292293422272884311683549297802474520465645717732738184046597;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x052b91ad9732D1bcE0dDAe15a4545e5c65D02443);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(2);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(2);
            keyWithProof.signature[0] = 4759468427417331338096225590380196861678766840686044783598908858507611445709;
            keyWithProof.signature[1] = 13931293079705789625040656990745107362878261090324869611419352282504788250056;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x8041C9A96585053DB2d7214B5dE56828645B8E62);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(2);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(2);
            keyWithProof.signature[0] = 34756791824567266224631101671618994159070928354445946482456048048663464705;
            keyWithProof.signature[1] = 1601580614586775708524683893294250696718035210409284992523863733431967325648;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x052b91ad9732D1bcE0dDAe15a4545e5c65D02443);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](2);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(2);
            keyWithProof.blsG1PublicKeys[1] = _readKnownBlsPubKey(3);
            keyWithProof.aggG2PublicKey[0][1] =
                1436130010253058561349149611592986290934628865731875470070282695245872240666;
            keyWithProof.aggG2PublicKey[0][0] =
                7578502386265024235754802017104054800698406382804724741015093778654852635282;
            keyWithProof.aggG2PublicKey[1][1] =
                5114341255269544452401726150392607561398256980868448135390245953108770572183;
            keyWithProof.aggG2PublicKey[1][0] =
                18171377127265906515233897598526544722054598806864022415405699900398453279838;
            keyWithProof.signature[0] = 17471920020921840372105598221319870168547950373398063923459571760436410230798;
            keyWithProof.signature[1] = 19939600192967785038303848210689779685435727604062122663968539782023194319470;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0xC2926a19a56c60f93247DA20864C165152e39C4d);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(3);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(3);
            keyWithProof.signature[0] = 2291005243417438893967732986249445863411105391310016687360657486426096419113;
            keyWithProof.signature[1] = 18952248983847686580077537003629398190955694737122412471680561329538688076671;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x8041C9A96585053DB2d7214B5dE56828645B8E62);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](3);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(2);
            keyWithProof.blsG1PublicKeys[1] = _readKnownBlsPubKey(3);
            keyWithProof.blsG1PublicKeys[2] = _readKnownBlsPubKey(4);
            keyWithProof.aggG2PublicKey[0][1] =
                14020416375286999806182823015391471396267118147177798912637729098797615698034;
            keyWithProof.aggG2PublicKey[0][0] =
                17675257955736224395756686823565200807024378550714926944512831770660957350662;
            keyWithProof.aggG2PublicKey[1][1] =
                10498025079967091468307570108978201557199116610816331093720310741816111715287;
            keyWithProof.aggG2PublicKey[1][0] =
                21390814521535213786481949944100584184214797449493352815966669025419414797309;
            keyWithProof.signature[0] = 2232337070325038939571091215503373503547576046854023576969710416490694218898;
            keyWithProof.signature[1] = 2470870487762863266204504008493981661690003053148728946480380112989365089729;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0xC2926a19a56c60f93247DA20864C165152e39C4d);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](4);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(5);
            keyWithProof.blsG1PublicKeys[1] = _readKnownBlsPubKey(6);
            keyWithProof.blsG1PublicKeys[2] = _readKnownBlsPubKey(7);
            keyWithProof.blsG1PublicKeys[3] = _readKnownBlsPubKey(8);
            keyWithProof.aggG2PublicKey[0][1] =
                1149916458657944912061164325406778726656111742779587960535580564729709165122;
            keyWithProof.aggG2PublicKey[0][0] =
                18873711714202196964289589515681140807643041155889655824025149306090934601992;
            keyWithProof.aggG2PublicKey[1][1] =
                3266387748569560375102829718109257620384034916503067447479562991241789932484;
            keyWithProof.aggG2PublicKey[1][0] =
                20590321380350934733756372600333434645461469888436858902424026979565468990377;
            keyWithProof.signature[0] = 15003521860711327604903817927542065291928952056143293566020166592774104999095;
            keyWithProof.signature[1] = 17230799891150258922114407084138307132012056704572378936341016601953585933296;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x147C043A2f969781442fDa98661D6B84b77A1CB6);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(9);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(9);
            keyWithProof.signature[0] = 11999720334652961929599239580926165326277199102912324903875403322407774464045;
            keyWithProof.signature[1] = 21243335116071870591184494667727965687217795729651470837412773640658259999522;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x052b91ad9732D1bcE0dDAe15a4545e5c65D02443);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt2");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(1);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(1);
            keyWithProof.signature[0] = 6546048281658092535472524194690529189929273073109838951297622257276250699174;
            keyWithProof.signature[1] = 2589516717571906356768328595933269365221677842550872443687481171703894873071;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x052b91ad9732D1bcE0dDAe15a4545e5c65D02443);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt2");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](2);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(2);
            keyWithProof.blsG1PublicKeys[1] = _readKnownBlsPubKey(3);
            keyWithProof.aggG2PublicKey[0][1] =
                1436130010253058561349149611592986290934628865731875470070282695245872240666;
            keyWithProof.aggG2PublicKey[0][0] =
                7578502386265024235754802017104054800698406382804724741015093778654852635282;
            keyWithProof.aggG2PublicKey[1][1] =
                5114341255269544452401726150392607561398256980868448135390245953108770572183;
            keyWithProof.aggG2PublicKey[1][0] =
                18171377127265906515233897598526544722054598806864022415405699900398453279838;
            keyWithProof.signature[0] = 18771223214263168200874805772456659662326057533111504007635880454664774619022;
            keyWithProof.signature[1] = 420128961880144106570903807741887686602725222096870825736032548115169453829;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x052b91ad9732D1bcE0dDAe15a4545e5c65D02443);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt3");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(4);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(4);
            keyWithProof.signature[0] = 12070371711782210845261182502617632511341360494663936531646455265481202582185;
            keyWithProof.signature[1] = 18608981529213253945356874854141442507552751495512868060579362350651863452517;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x052b91ad9732D1bcE0dDAe15a4545e5c65D02443);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt4");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(5);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(5);
            keyWithProof.signature[0] = 13190061694265114853477081052211974977471493407405560124492494892525459969236;
            keyWithProof.signature[1] = 1817612747541536182800916734059401348384289141737080575794412881457814353738;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x052b91ad9732D1bcE0dDAe15a4545e5c65D02443);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt5");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(1);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(1);
            keyWithProof.signature[0] = 18088757116333031743561228955923820105792433215185834009546977764941668292111;
            keyWithProof.signature[1] = 10247285105154724741403702230575029756978976024516135828556117835183535554783;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x052b91ad9732D1bcE0dDAe15a4545e5c65D02443);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt2");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(10);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(10);
            keyWithProof.signature[0] = 6528237737576124853407923681252091992608895325718817781423711636456836633482;
            keyWithProof.signature[1] = 11067448007236948072589757344660150293341509091837476264529661198148745626589;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        uint256 chainidBackup = block.chainid;
        vm.chainId(17000); // holesky testnet
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x052b91ad9732D1bcE0dDAe15a4545e5c65D02443);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(1);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(1);
            keyWithProof.signature[0] = 13384982300195833786393862711791993643893041917398535780019509163977157041805;
            keyWithProof.signature[1] = 4485415040370633274895162286481060683649470976343674095840042787838459601582;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0x8041C9A96585053DB2d7214B5dE56828645B8E62);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(2);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(2);
            keyWithProof.signature[0] = 7905117338368741607975776461314350521925295659936656125027854581539393103153;
            keyWithProof.signature[1] = 15172225709461105373688028418238185171647195204499791842615380032364123249125;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0xC2926a19a56c60f93247DA20864C165152e39C4d);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(3);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(3);
            keyWithProof.signature[0] = 18098217780758214072779954553262241757478883700246442430770270226922435199767;
            keyWithProof.signature[1] = 5037419497513441000228611829098584761568360394951628035925414013924693583676;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        vm.chainId(chainidBackup);
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
        uint256[2][] memory blsPubKeys,
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
        lagrangeService.register(operator, _calcProofForBLSKeys(operator, blsPubKeys), operatorSignature);

        lagrangeCommittee.getEpochNumber(chainID, block.number);
        lagrangeCommittee.isLocked(chainID);

        lagrangeService.subscribe(chainID);

        vm.stopPrank();
    }

    function _calcProofForBLSKeys(address operator, uint256[2][] memory blsPubKeys, bytes32 salt)
        internal
        view
        virtual
        returns (IBLSKeyChecker.BLSKeyWithProof memory)
    {
        uint256 expiry = block.timestamp + 1000;
        bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

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

        console.log("----------------------------------------", operator, expiry);
        console.logBytes32(digestHash);
        for (uint256 i = 0; i < blsPubKeys.length; i++) {
            console.log(blsPubKeys[i][0], blsPubKeys[i][1]);
        }
        require(false, "can't find");
    }

    function _calcProofForBLSKeys(address operator, uint256[2][] memory blsPubKeys)
        internal
        view
        returns (IBLSKeyChecker.BLSKeyWithProof memory keyWithProof)
    {
        return _calcProofForBLSKeys(operator, blsPubKeys, bytes32("salt"));
    }

    function _calcProofForBLSKey(address operator, uint256[2] memory blsPubKey)
        internal
        view
        returns (IBLSKeyChecker.BLSKeyWithProof memory keyWithProof)
    {
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0] = blsPubKey;
        return _calcProofForBLSKeys(operator, blsPubKeys);
    }

    function _calcProofForBLSKey(address operator, uint256[2] memory blsPubKey, bytes32 salt)
        internal
        view
        returns (IBLSKeyChecker.BLSKeyWithProof memory keyWithProof)
    {
        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0] = blsPubKey;
        return _calcProofForBLSKeys(operator, blsPubKeys, salt);
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
