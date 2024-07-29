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
      '0x4e4a16bac3e3ee1b925250d535379644549e33c6e46c5d40bb61b52fd5e72c96',
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
      '5776186022737184614391362786682580621419758127537303241337839443334973970418',
      '2744744017684473642194176167060200346629039365709813815550228082825932652104',
    ],
  },
  {
    digestHash:
      '0xbc2d1185ef1cc0fdfdefabbb721ac4f0ddc059cf08ead195663389af2cc389ee',
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
      '18978082362300059298287924452548558004116553214379056059592121203146094567511',
      '19030487727920750904771102218954468860107061593119994857664184824552005509676',
    ],
  },
  {
    digestHash:
      '0xa9368d5c1b9dd7e793ee83bbd59f88eff09d0a95559153d152172dcb2775316c',
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
      '21807935969842043360541020041545859837772019020021620016170613971439160729069',
      '2482139805159937999311630433165605005936102291379726181496675385581363262371',
    ],
  },
  {
    digestHash:
      '0xfa6234adace897f5e306d2e5e1c2244aa5ab67af0a31303e41cd1582065b1e13',
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
      '16731830232714604034351300594183135022358223592259127932640328311402613129924',
      '3563942005757600244078482277722443677691366697661182455788027605796666529191',
    ],
  },
  {
    digestHash:
      '0x40e98a8fa7d0e205c34e7c16a8dceacb35ceb0ee777bd5f934f2f779a090a82d',
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
      '1297260710459929613034983671817253952815584303013115325600604623500728136952',
      '4398706686185223755781076337069759086592000436222632742283592363709893973614',
    ],
  },
  {
    digestHash:
      '0xe102e539ec3e92445722b1dec5ab02110e7ccbea473c09a5b4f890e4882a3bdd',
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
      '10254842034346209147467567495983558754217528249564796066140727777022021011366',
      '6989876636260273146384011591389504594905745637802717226021332973328603938745',
    ],
  },
  {
    digestHash:
      '0xbba987546d36c26e50587e576efc64bff69fe93fc05ef26a8dfa5d78a7f73ea9',
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
      '2598683542168342736149475971983454350370307664715677641477656650285250082213',
      '3903657562707074715452676879825770042157418553574791373784584278424431937315',
    ],
  },
  {
    digestHash:
      '0x8ee6976f22ca755f339fdde7cfcfd64eec84f28846bfa57959d6b167270f4361',
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
      '21095716315267084360439826249686945350336296909441216783777227419871299251984',
      '1522807042407870109193157316629649550287234725360510239010812131312113488545',
    ],
  },
  {
    digestHash:
      '0xd88e0d51e78878be760384d3ab5b801636168c9ea06c27661e8bb639bbef283f',
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
      '4579570844736636742051907878780627953467862908490051800290325405226532746800',
      '5515005136922024447309656290895656436917270957962990782440283889743762480682',
    ],
  },
  {
    digestHash:
      '0xb318dafb494815261044e8f658835a45dba638a6e072821a9e152959f8b7eda4',
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
      '1306144792468306378056933154780484797724454618252661250828857187975931573838',
      '18410817925286728194488046665652308168963086164530196514458695038305771337734',
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
