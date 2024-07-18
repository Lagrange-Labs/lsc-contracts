const ethers = require('ethers');

require('dotenv').config();

const serviceABI =
  require('../out/LagrangeService.sol/LagrangeService.json').abi;
const committeeABI =
  require('../out/LagrangeCommittee.sol/LagrangeCommittee.json').abi;
const avsDirectoryABI =
  require('../out/IAVSDirectory.sol/IAVSDirectory.json').abi;
const deployedAddresses = require('../script/output/deployed_lgr.json');
const m1DeployedAddresses = require('../script/output/M1_deployment_data.json');

const operators = require('../config/operators.json');

const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);

const NUM_ACCOUNTS = parseInt(process.env.NUM_ACCOUNTS || '15');
const REGISTERED_OPERATOR_COUNT = NUM_ACCOUNTS - 5;

const preCalculatedProofHashes = [
  {
    digestHash:
      '0x3dd0a0e993dee4e094cbc96a0427372166130eee59a34433ee0a44acc150c993',
    aggG2PublicKey: [
      [
        '18278389646821250305699901000115272146394424141541828377935595968842598839558',
        '12579183095081433599766482319454236990681757097696886619684754875971808282528',
      ],
      [
        '20239483229501965127848803443842720859367640498407711614275728697924046264052',
        '301058701789884254540007586813170179394916203305451331856781011130144675825',
      ],
    ],
    signature: [
      '4027617315777162095663887723849989832555831040634741195134771024887911929762',
      '21485506325375409658204394114132392265643138867510485615965722739179707950213',
    ],
  },
  {
    digestHash:
      '0xa40c96d3ee41e785150fc065d276667dcefd2a6e22a6ce326ff40cb03cf7a1bd',
    aggG2PublicKey: [
      [
        '11719845012413673801703667786567662213265694676671288352855808932384682431881',
        '6823568383881319519261392741304024190595984631371163418049807563026643400980',
      ],
      [
        '3081452905376440102681653793385791209108350053621988029658296650508784582338',
        '875712813259364385780580626011750444654391868418282961783748360116366069537',
      ],
    ],
    signature: [
      '5663503019140654643289730570008006959416976783771288463613260610949654511575',
      '1980137063427314082101463823110475922276481066995155961345326460562002061356',
    ],
  },
  {
    digestHash:
      '0xc377c5bc3cbfdc9199c23fc24f59b85823ea4698c17c6535b7b177950995e9f2',
    aggG2PublicKey: [
      [
        '19507275371225444019445233081877960404704997393356797728143325061772399976476',
        '475070893533532420712014884828671972949538696482596893590438057561718589170',
      ],
      [
        '8868046512188198398419557220589769308785955674549281474310135929738749828177',
        '420886234749049305841625607615035735861501343506645230874610312342184831165',
      ],
    ],
    signature: [
      '17986436926899125057052015136653539177523462837463697324336802766038012409306',
      '1550620834455706797919054076106760581515033378229249961441916500733869159744',
    ],
  },
  {
    digestHash:
      '0xb76630a5bd025cb9d2014e4014b5b2af29e838c04330246b7b22c374e7fcc6b9',
    aggG2PublicKey: [
      [
        '11109463383715458240664741650918099975849758278445994708048641968680706511355',
        '12008407931379194185911026077874094449936223826749559708327679321600484423090',
      ],
      [
        '6602525143408714129029973362291889392386107781885595063853043826245846429343',
        '21291856834995308934258468397503222741315670719619471617212692412136537782237',
      ],
    ],
    signature: [
      '18530384847727027282699078730762610555690525795907686180632753884431265253998',
      '2788603202388760128716483546307277941022419241068819853335363175032747728755',
    ],
  },
  {
    digestHash:
      '0xaf3f20791965c5942c891038e307c3f2b9c3bf66c642a602479b78e28b83ecb0',
    aggG2PublicKey: [
      [
        '20049517053808342645106409346886532414402923729571269478545153326077254852758',
        '16637000600429576289199176677854110041770372522651654636117206624140894936326',
      ],
      [
        '7931094752013541321559279278684470554865639568467244859359262592043342414853',
        '11329647147725378369252072304963615161727424371724217539183652992499112702725',
      ],
    ],
    signature: [
      '8962251778324846025136368053888608077665035139668860292014417825379091759660',
      '18961516006810408229589367095384637299856124314850633494340718936441891364941',
    ],
  },
  {
    digestHash:
      '0x423694de60ba3cb17f2f8936ed129381b0b4ace959e134c0188fdca806e5127c',
    aggG2PublicKey: [
      [
        '16364955548359037732967290789495758904415571905944457529533343755765055479260',
        '21250997378529433309340214001723853630819246858092196730665530151656798036416',
      ],
      [
        '14857850352446278682062547738018922032691334581432852319803313494979559037190',
        '17699850262963019306103688730097257124272195633347728431794406891132933735609',
      ],
    ],
    signature: [
      '3072342957878060224023604216789804430532687437296111012349690717707653296191',
      '7439378212357271834061109223960899011508208797779845729852518798520189648586',
    ],
  },
  {
    digestHash:
      '0x33f140aa4aef31d61c4655adb98c19fa17054cd0f439d7f9ccd11f76c09901f5',
    aggG2PublicKey: [
      [
        '19106999197839746026879081489652536470520182100589471478485604517947235695507',
        '8439322804272709701029755432073738623826649688854922175870380736863056489123',
      ],
      [
        '16293239184803271038570032818652661643990321682546200658990422537570731005882',
        '14991123907036909007453648001348768558470933594823789366537925858755595116713',
      ],
    ],
    signature: [
      '13631847904738613733416501856393293210767120422221512639596030414707934283725',
      '9108815545523938999292837242382339046013804316202817995557962987987282571286',
    ],
  },
  {
    digestHash:
      '0x55f12b44e5a16f7c08f9ce91d58d16a3101cc023a7654fb297a314ec14c0d594',
    aggG2PublicKey: [
      [
        '10964149981093673192878105862123136095629476340728221926737174498877223969648',
        '15310411369620863421292035563000579947440359652734678186174074640222704784730',
      ],
      [
        '14394448488692205245100592077579864928867873913469847595739357980967122954289',
        '12973493539966959469484148839766384057653485995822838495480890958868429837596',
      ],
    ],
    signature: [
      '19964311285282707926639356793014661808291848032486893262557403139995438670147',
      '20973190696144771395107466269325093321832382809388298456172225600575861867358',
    ],
  },
  {
    digestHash:
      '0x668f9f2003d79d5c9a4c8145d20013c0fb0a02687c1e6bf8617507b557606057',
    aggG2PublicKey: [
      [
        '443893656036388665233236242117188127065868835282453062133808678040015042429',
        '7331548207031936603400747370621041517640282419366011168050780132447131164785',
      ],
      [
        '20990309432715278611468563170296783892531003311534251198264328329085429717735',
        '19527508948082192170493175951834638819044026564976650183799921676597235202371',
      ],
    ],
    signature: [
      '16271044706921159035533676455525136037660071155580117146078582014831070107450',
      '17957794275919311931198822444629638952948506374513446530055402790351473313873',
    ],
  },
  {
    digestHash:
      '0xcf12cdf22df859323298c4b22a6aeadb50bf6147165986428a9fdb14113dd515',
    aggG2PublicKey: [
      [
        '4890506482923786599569700830167959444180769098681357099112133009542545887444',
        '11825261625679047237440697905015481839791205959279400784332086489473736078128',
      ],
      [
        '13842187764997607089802819067749287648911556700691654766053570930409077059065',
        '559501346307597358306005794386061567116703940240828021190684518976035514213',
      ],
    ],
    signature: [
      '14392158529315341913045625025701483615778214153321449327845890004563147173273',
      '20559286483682337373323631105617938379576019762932980171990243397353162260058',
    ],
  },
];

const convertBLSPubKey = (oldPubKey) => {
  const Gx = BigInt(oldPubKey.slice(0, 66));
  const Gy = BigInt('0x' + oldPubKey.slice(66));
  return [Gx, Gy];
};

(async () => {
  const owallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const ocontract = new ethers.Contract(
    deployedAddresses.addresses.lagrangeService,
    serviceABI,
    owallet,
  );

  const avsDirectory = new ethers.Contract(
    m1DeployedAddresses.addresses.avsDirectory,
    avsDirectoryABI,
    owallet,
  );

  const tx = await ocontract.addOperatorsToWhitelist(
    operators[0].operators.slice(0, REGISTERED_OPERATOR_COUNT + 3),
  );
  console.log(
    `Starting to add operator to whitelist for address: ${operators[0].operators} tx hash: ${tx.hash}`,
  );
  const receipt = await tx.wait();
  console.log(
    `Add Operator Transaction was mined in block ${receipt.blockNumber} gas consumed: ${receipt.gasUsed}`,
  );

  const committee = new ethers.Contract(
    deployedAddresses.addresses.lagrangeCommittee,
    committeeABI,
    owallet,
  );

  const chainParams = [];
  for (let i = 0; i < operators.length; i++) {
    chainParams.push(await committee.committeeParams(operators[i].chain_id));
  }
  console.log('Chain Params', chainParams);

  await Promise.all(
    operators[0].operators.map(async (operator, index) => {
      if (index >= REGISTERED_OPERATOR_COUNT) {
        return;
      }
      const privKey = operators[0].ecdsa_priv_keys[index];
      const wallet = new ethers.Wallet(privKey, provider);
      const contract = new ethers.Contract(
        deployedAddresses.addresses.lagrangeService,
        serviceABI,
        wallet,
      );

      const timestamp = Math.floor(new Date().getTime() / 1000);

      const salt =
        '0x0000000000000000000000000000000000000000000000000000000000000011'; //
      const expiry = timestamp + 60; // 1 minutes from now
      const avs = deployedAddresses.addresses.lagrangeService; //

      const digestHash =
        await avsDirectory.calculateOperatorAVSRegistrationDigestHash(
          operator, // address operator,
          avs, // address avs, // This address should be smart contract address who calls AVSDirectory.registerOperatorToAVS
          salt, // bytes32 approverSalt,
          expiry, // uint256 expiry
        );
      const signingKey = new ethers.utils.SigningKey(privKey);
      const signature = signingKey.signDigest(digestHash).compact;

      const proofExpiry = 2000000000; // big enough
      const proofSalt = salt; // use same salt with above
      const proofDigestHash = await committee.calculateKeyWithProofHash(
        operators[0].operators[index],
        proofSalt,
        proofExpiry,
      );
      const blsG1PublicKeys = [
        convertBLSPubKey(operators[0].bls_pub_keys[index]),
      ];
      if (proofDigestHash !== preCalculatedProofHashes[index].digestHash) {
        console.log(
          'Digest hash mismatch',
          index,
          proofDigestHash,
          preCalculatedProofHashes[index].digestHash,
        );
        throw new Error('Digest hash mismatch');
      }
      const aggG2PublicKey = preCalculatedProofHashes[index].aggG2PublicKey.map(
        (arr) => arr.map((x) => BigInt(x)).reverse(),
      );
      const proofSignature = preCalculatedProofHashes[index].signature.map(
        (x) => BigInt(x),
      );
      const tx = await contract.register(
        operators[0].operators[index],
        {
          blsG1PublicKeys,
          aggG2PublicKey,
          signature: proofSignature,
          salt: proofSalt,
          expiry: proofExpiry,
        },
        { signature, salt, expiry },
      );
      console.log(
        `Starting to register operator for address: ${operator} tx hash: ${tx.hash}`,
      );
      const receipt = await tx.wait();
      console.log(
        `Register Transaction was mined in block ${receipt.blockNumber} gas consumed: ${receipt.gasUsed}`,
      );
    }),
  );

  for (let k = 0; k < operators.length; k++) {
    const chain = operators[k];
    for (let index = 0; index < REGISTERED_OPERATOR_COUNT; index++) {
      const address = chain.operators[index];
      const privKey = operators[0].ecdsa_priv_keys[index];
      const wallet = new ethers.Wallet(privKey, provider);
      const contract = new ethers.Contract(
        deployedAddresses.addresses.lagrangeService,
        serviceABI,
        wallet,
      );

      while (true) {
        const blockNumber = await provider.getBlockNumber();
        const isLocked = await committee.isLocked(chain.chain_id);
        console.log(
          `Block Number: ${blockNumber} isLocked: ${isLocked[1].toNumber()} Freeze Duration: ${chainParams[
            k
          ].freezeDuration.toNumber()}`,
        );
        if (
          blockNumber <
          isLocked[1].toNumber() - chainParams[k].freezeDuration.toNumber() - 2
        ) {
          break;
        }

        await new Promise((resolve) => setTimeout(resolve, 500));
      }

      const tx = await contract.subscribe(chain.chain_id);
      console.log(
        `Starting to subscribe operator for address: ${address} tx hash: ${tx.hash}`,
      );
      const receipt = await tx.wait();
      console.log(
        `Subscribe Transaction was mined in block ${receipt.blockNumber} gas consumed: ${receipt.gasUsed}`,
      );
    }
  }
})();
