// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

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
            keyWithProof.signature[0] = 15921140252975377423994196099001272773284939434965566079471588880280786420677;
            keyWithProof.signature[1] = 7332784689683052555864284122213275566890163145140074068086313511863203727694;
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
            keyWithProof.signature[0] = 19795328608502458562515598110459675652016548373721017447668129866961817110318;
            keyWithProof.signature[1] = 10256498968130419831503675412302049575196783250451056335358876552078425160998;
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
            keyWithProof.signature[0] = 15575751001865467640019584774310153796650213096552608892735562486644842181725;
            keyWithProof.signature[1] = 6044316828442607059249448078621067025573636648109861092894886010418287166198;
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
            keyWithProof.signature[0] = 6170367078810497485999830899778843210644556456614930176262867102271115625756;
            keyWithProof.signature[1] = 13466672684255091281925999915998956781018002884888917231327288088687425188766;
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
            keyWithProof.signature[0] = 9638620410705059766600007244635247155503475228465321585770248681660498694789;
            keyWithProof.signature[1] = 11043471024492783409224449533192995294553640308083488815324717239561400693369;
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
            keyWithProof.signature[0] = 408108792277085165492799598455267538822176867543195473463955563047270669758;
            keyWithProof.signature[1] = 13158963018952089623410459356532485505923012670797089597669035203655512456266;
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
            keyWithProof.signature[0] = 18705490630560712939412903454952715701964277146886414667889363282056902966691;
            keyWithProof.signature[1] = 14280133365446777403501268114433161798314533971755502359054273841634742349195;
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
            keyWithProof.signature[0] = 8104028208194733071334647004111998550876885377720109175958316017645038879152;
            keyWithProof.signature[1] = 7278749530659924555957809914959057961307047000429758584992752589691267913933;
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
            keyWithProof.signature[0] = 18485284664738509299123082502625855940992586986027894540210244624797546397798;
            keyWithProof.signature[1] = 7616645516452768803488436668555585042895469399650805331623421410227064934303;
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
            keyWithProof.signature[0] = 7859718125025868566092966453887393331758574058339056018235230601468015099448;
            keyWithProof.signature[1] = 18272770206386315484619361082555265676642516846213057593643502273569335928678;
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
            keyWithProof.signature[0] = 4474789933137347268577559361321453855149317435072158471711883976671292242869;
            keyWithProof.signature[1] = 13007964118424605626004265987006332577892056100634924406299375779760416910532;
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
            keyWithProof.signature[0] = 3863966552807087244124686721137633044623638001986388009598743523342101143647;
            keyWithProof.signature[1] = 6754575140317751452126855663965030148719601334922429367034455206963720892638;
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
            keyWithProof.signature[0] = 13758505917978100488948519312597996356767498113711898940538249488718994070156;
            keyWithProof.signature[1] = 10405382952539000309278262410280670994052372040902676863038413277430025689798;
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
            keyWithProof.signature[0] = 10862883858769163293865832400633302416625503890029252720695098721183181537880;
            keyWithProof.signature[1] = 280493063917217164368954138635461191777155944930732092323356548285123446725;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0xA00DaC36c34AAf7DC950d8E7156Be495191d4234);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(9);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(9);
            keyWithProof.signature[0] = 2276678920098080295068589088903944219814959727842730093475790154726422614061;
            keyWithProof.signature[1] = 8995201132505520068782331803461571318208346808437345829021042209201344932608;
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
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(9);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(9);
            keyWithProof.signature[0] = 19508295020599638427100600663969775876870979462931170555434086705099263830129;
            keyWithProof.signature[1] = 6951371751295157900703707928823400929597287868939849078154329268622763259158;
            knownBlsGroups[digestHash].push(keyWithProof);
        }
        {
            IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;

            address operator = address(0xA00DaC36c34AAf7DC950d8E7156Be495191d4234);
            uint256 expiry = 1001;
            bytes32 salt = bytes32("salt2");
            bytes32 digestHash = lagrangeCommittee.calculateKeyWithProofHash(operator, salt, expiry);

            keyWithProof.blsG1PublicKeys = new uint256[2][](1);
            keyWithProof.salt = salt;
            keyWithProof.expiry = expiry;
            keyWithProof.blsG1PublicKeys[0] = _readKnownBlsPubKey(10);
            keyWithProof.aggG2PublicKey = _readKnownBlsSingleAggr(10);
            keyWithProof.signature[0] = 7946246266992163154158282254721787931529417396576328342380027526316953544216;
            keyWithProof.signature[1] = 15312372502133639686079754063849653468329115035357668783766402382480746239792;
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
            keyWithProof.signature[0] = 15201994907539692674107666331634333008756164361909920971773367020525528340479;
            keyWithProof.signature[1] = 13688585501184562715730707034037980037139184727262010866108196080050015430207;
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
            keyWithProof.signature[0] = 19628052726218325638218496100093743262125390907473748470116309891767230712226;
            keyWithProof.signature[1] = 14127978985937000612006817629873663031355929020166982594326235545781546136578;
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
            keyWithProof.signature[0] = 11621517380234521252543958464039728344030821240651194216053650240488502362391;
            keyWithProof.signature[1] = 2338750728089039691549341717254094992964740576676546845715148029430819222337;
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
