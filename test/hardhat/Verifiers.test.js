const { expect } = require("chai");
const { ethers } = require("hardhat");
const fs = require("fs");
const shared = require("./shared");
const bls = require("@noble/bls12-381");
let { PointG1, PointG2 } = require("./zk-utils-index.js");

const verSigABI = ["uint[2]", "uint[2][2]", "uint[2]"];

const verAggABI = ["uint[2]", "uint[2][2]", "uint[2]"];

const chainHeaderABI = ["bytes32", "uint256", "uint32"];

async function getJSON(path) {
  txt = await fs.readFileSync(path);
  json = await JSON.parse(txt);
  return json;
}

// describe('Lagrange Verifiers', function () {
//   const evidence = {
//     operator: '0x5d51B4c1fb0c67d0e1274EC96c1B895F45505a3D',
//     blockHash:
//       '0xd31e8eeac337ce066c9b6fedd907c4e0e0ac2fdd61078c61e8f0df9af0481896',
//     correctBlockHash:
//       '0xd31e8eeac337ce066c9b6fedd907c4e0e0ac2fdd61078c61e8f0df9af0481896',
//     currentCommitteeRoot:
//       '0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514',
//     correctCurrentCommitteeRoot:
//       '0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514',
//     nextCommitteeRoot:
//       '0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514',
//     correctNextCommitteeRoot:
//       '0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514',
//     blockNumber: 28809913,
//     l1BlockNumber: 0,
//     blockSignature: '0x00',
//     commitSignature: '0x00',
//     chainID: 421613,
//     sigProof: '0x00',
//     aggProof: '0x00',
//   };

//   const evidence256 = {
//     operator: '0x8495E007fA46ef6328dB1E55121729B504B9c97D',
//     blockHash:
//       '0x934e0918c1c79abdb8cafd75549f63f305e147ab22feebb464b73a21ff0ce0ab',
//     correctBlockHash:
//       '0x934e0918c1c79abdb8cafd75549f63f305e147ab22feebb464b73a21ff0ce0ab',
//     currentCommitteeRoot:
//       '0x246cfc16271ed6cdc211e0502afa19c73d2fff009a744d16d0106b7f83a8d288',
//     correctCurrentCommitteeRoot:
//       '0x246cfc16271ed6cdc211e0502afa19c73d2fff009a744d16d0106b7f83a8d288',
//     nextCommitteeRoot:
//       '0x246cfc16271ed6cdc211e0502afa19c73d2fff009a744d16d0106b7f83a8d288',
//     correctNextCommitteeRoot:
//       '0x246cfc16271ed6cdc211e0502afa19c73d2fff009a744d16d0106b7f83a8d288',
//     blockNumber: 26138881,
//     l1BlockNumber: 10050864,
//     blockSignature: '0x00',
//     commitSignature: '0x00',
//     chainID: 5001,
//     attestBlockHeader: '0x00',
//     sigProof: '0x00',
//     aggProof: '0x00',
//   };

//   let admin;

//   before(async function () {
//     [admin] = await ethers.getSigners();
//   });

//   beforeEach(async function () {
//     console.log('Deploying empty contract...');

//     const EmptyContractFactory =
//       await ethers.getContractFactory('EmptyContract');
//     const emptyContract = await EmptyContractFactory.deploy();
//     await emptyContract.deployed();

//     console.log('Deploying proxy...');

//     const ProxyAdminFactory = await ethers.getContractFactory(
//       'lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol:ProxyAdmin',
//     );
//     const proxyAdmin = await ProxyAdminFactory.deploy();
//     await proxyAdmin.deployed();

//     console.log('Deploying transparent proxy...');

//     const TransparentUpgradeableProxyFactory = await ethers.getContractFactory(
//       'lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy',
//     );
//     tsProxy = await TransparentUpgradeableProxyFactory.deploy(
//       emptyContract.address,
//       proxyAdmin.address,
//       '0x',
//     );
//     await tsProxy.deployed();

//     evProxy = await TransparentUpgradeableProxyFactory.deploy(
//       emptyContract.address,
//       proxyAdmin.address,
//       '0x',
//     );
//     await evProxy.deployed();

//     console.log('Deploying verifier contracts...');
//     const verSigFactory = await ethers.getContractFactory('Verifier');
//     const verAggFactory = await ethers.getContractFactory('Verifier_16');
//     const verAgg32Factory = await ethers.getContractFactory('Verifier_32');
//     const verAgg64Factory = await ethers.getContractFactory('Verifier_64');
//     const verAgg256Factory = await ethers.getContractFactory('Verifier_256');

//     const verSig = await verSigFactory.deploy();
//     const verAgg = await verAggFactory.deploy();
//     const verAgg32 = await verAgg32Factory.deploy();
//     const verAgg64 = await verAgg64Factory.deploy();
//     const verAgg256 = await verAgg256Factory.deploy();

//     console.log('Deploying verifier triage contracts...');

//     const evidenceVerifierFactory =
//       await ethers.getContractFactory('EvidenceVerifier');
//     const evidenceVerifier = await evidenceVerifierFactory.deploy();

//     console.log('Upgrading proxy...');

//     await proxyAdmin.upgradeAndCall(
//       evProxy.address,
//       evidenceVerifier.address,
//       evidenceVerifier.interface.encodeFunctionData('initialize', [
//         admin.address,
//       ]),
//     );

//     console.log('aggregate verifier:', verAgg.address);

//     console.log('Linking verifier triage contracts to verifier contracts...');

//     evProxy = await ethers.getContractAt('EvidenceVerifier', evProxy.address);
//     await evProxy.setSingleVerifier(verSig.address);
//     await evProxy.setAggregateVerifierRoute(16, verAgg.address);
//     await evProxy.setAggregateVerifierRoute(32, verAgg32.address);
//     await evProxy.setAggregateVerifierRoute(64, verAgg64.address);
//     await evProxy.setAggregateVerifierRoute(256, verAgg256.address);

//     shared.SAV = verAgg;
//     shared.SAV32 = verAgg32;
//     shared.SAV64 = verAgg64;
//     shared.SAV256 = verAgg256;
//     shared.SAVTimp = evidenceVerifier;
//     shared.SAVT = evProxy;
//   });

//   it('slashing_single verifier', async function () {
//     const verSig = shared.SSV;
//     pub = await getJSON('test/hardhat/slashing_single/public.json');
//     proof = await getJSON('test/hardhat/slashing_single/proof.json');
//     pubNumeric = Object.values(pub).map(ethers.BigNumber.from);

//     a = [
//       ethers.BigNumber.from(proof.pi_a[0]),
//       ethers.BigNumber.from(proof.pi_a[1]),
//     ];
//     b = [
//       [
//         ethers.BigNumber.from(proof.pi_b[0][1]),
//         ethers.BigNumber.from(proof.pi_b[0][0]),
//       ],
//       [
//         ethers.BigNumber.from(proof.pi_b[1][1]),
//         ethers.BigNumber.from(proof.pi_b[1][0]),
//       ],
//     ];
//     c = [
//       ethers.BigNumber.from(proof.pi_c[0]),
//       ethers.BigNumber.from(proof.pi_c[1]),
//     ];
//     input = pubNumeric;
//     input[0] = '1';

//     res = await verSig.verifyProof(a, b, c, input);
//     expect(res).to.equal(false);
//   });
//   it('slashing_aggregate_16 verifier', async function () {
//     const verAgg = shared.SAV;
//     pub = await getJSON('test/hardhat/slashing_aggregate_16/public.json');
//     proof = await getJSON('test/hardhat/slashing_aggregate_16/proof.json');
//     pubNumeric = Object.values(pub).map(ethers.BigNumber.from);

//     a = [
//       ethers.BigNumber.from(proof.pi_a[0]),
//       ethers.BigNumber.from(proof.pi_a[1]),
//     ];
//     b = [
//       [
//         ethers.BigNumber.from(proof.pi_b[0][1]),
//         ethers.BigNumber.from(proof.pi_b[0][0]),
//       ],
//       [
//         ethers.BigNumber.from(proof.pi_b[1][1]),
//         ethers.BigNumber.from(proof.pi_b[1][0]),
//       ],
//     ];
//     c = [
//       ethers.BigNumber.from(proof.pi_c[0]),
//       ethers.BigNumber.from(proof.pi_c[1]),
//     ];
//     input = pubNumeric;

//     res = await verAgg.verifyProof(a, b, c, input);
//     expect(res).to.equal(true);
//   });
//   it('slashing_aggregate_256 verifier', async function () {
//     const verAgg256 = shared.SAV256;
//     pub = await getJSON('test/hardhat/slashing_aggregate_256/public.json');
//     proof = await getJSON('test/hardhat/slashing_aggregate_256/proof.json');
//     pubNumeric = Object.values(pub).map(ethers.BigNumber.from);

//     a = [
//       ethers.BigNumber.from(proof.pi_a[0]),
//       ethers.BigNumber.from(proof.pi_a[1]),
//     ];
//     b = [
//       [
//         ethers.BigNumber.from(proof.pi_b[0][1]),
//         ethers.BigNumber.from(proof.pi_b[0][0]),
//       ],
//       [
//         ethers.BigNumber.from(proof.pi_b[1][1]),
//         ethers.BigNumber.from(proof.pi_b[1][0]),
//       ],
//     ];
//     c = [
//       ethers.BigNumber.from(proof.pi_c[0]),
//       ethers.BigNumber.from(proof.pi_c[1]),
//     ];
//     input = pubNumeric;

//     res = await verAgg256.verifyProof(a, b, c, input);
//     expect(res).to.equal(true);
//   });
//   it('slashing_single triage', async function () {
//     const ev = shared.SAVT;
//     // load relevant contracts from shared
//     // retrieve input and public statement
//     pub = await getJSON('test/hardhat/slashing_single/public.json');
//     proof = await getJSON('test/hardhat/slashing_single/proof.json');

//     a = [
//       ethers.BigNumber.from(proof.pi_a[0]),
//       ethers.BigNumber.from(proof.pi_a[1]),
//     ];
//     b = [
//       [
//         ethers.BigNumber.from(proof.pi_b[0][1]),
//         ethers.BigNumber.from(proof.pi_b[0][0]),
//       ],
//       [
//         ethers.BigNumber.from(proof.pi_b[1][1]),
//         ethers.BigNumber.from(proof.pi_b[1][0]),
//       ],
//     ];
//     c = [
//       ethers.BigNumber.from(proof.pi_c[0]),
//       ethers.BigNumber.from(proof.pi_c[1]),
//     ];
//     const encoded = await ethers.utils.defaultAbiCoder.encode(verSigABI, [
//       a,
//       b,
//       c,
//     ]);
//     // use bls keypair, derived from query layer
//     blsPriv =
//       '0x20caccb5199dc5a02ff5d9bdced31c4f091ffc18a6752776a687bc6a5ad0a2f3';
//     blsPub =
//       '0xa2b7785a08a66bd749a24c6d9d04e8638abbe0d94b0b694a679068227044df02c89056d00d36dfbb7516a78d41979a0a';
//     // derive chainheader from in-contract event emission
//     chainHeaderPreimage = await ethers.utils.solidityPack(chainHeaderABI, [
//       '0x934e0918c1c79abdb8cafd75549f63f305e147ab22feebb464b73a21ff0ce0ab',
//       26138881,
//       5001,
//     ]);
//     console.log('preimage:', chainHeaderPreimage);
//     chainHeader = await ethers.utils.keccak256(chainHeaderPreimage);
//     console.log('hash:', chainHeader);
//     // derive signingRoot from chainHeader and cur/next committee roots, poseidon hash
//     signingRoot =
//       chainHeader +
//       '246cfc16271ed6cdc211e0502afa19c73d2fff009a744d16d0106b7f83a8d288' +
//       '246cfc16271ed6cdc211e0502afa19c73d2fff009a744d16d0106b7f83a8d288';

//     srHash = await poseidon
//       .hashBytes(Uint8Array.from(Buffer.from(signingRoot.slice(2), 'hex')))
//       .toString(16);
//     if (srHash.length % 2 == 1) {
//       srHash = '0' + srHash;
//     }
//     console.log(
//       'signingRoot:',
//       signingRoot,
//       'hash:',
//       ethers.BigNumber.from('0x' + srHash),
//     );
//     // sign signingroot
//     message = new Uint8Array(Buffer.from(srHash, 'hex'));
//     signature =
//       '0xb2c79492ed6623145547aa2392d8dfa0fbce491e8f28463ca13176ea702da026254ac9949b19a0afc4c328a123a3965010e5823cf113fa943b8df96edca17d8b7e05b2ed22b099c74ae25c59f527f58a4a3da44ee32727547c9a1d6ffe065ef7';
//     console.log('aggsig___:', signature);
//     coords = await bls.PointG2.fromHex(signature.slice(2));
//     console.log(coords);

//     affine = [
//       coords.toAffine()[0].c0.value.toString(16).padStart(96, '0'),
//       coords.toAffine()[0].c1.value.toString(16).padStart(96, '0'),
//       coords.toAffine()[1].c0.value.toString(16).padStart(96, '0'),
//       coords.toAffine()[1].c1.value.toString(16).padStart(96, '0'),
//     ];
//     csig = '0x' + affine.join('');
//     console.log('signature:', csig);

//     const pubKey = await bls.PointG1.fromHex(blsPub.slice(2));
//     const Gx = await pubKey.toAffine()[0].value.toString(16).padStart(96, '0');
//     const Gy = await pubKey.toAffine()[1].value.toString(16).padStart(96, '0');
//     const newPubKey = '0x' + Gx + Gy;

//     evidence256.sigProof = encoded;
//     evidence256.aggProof = encoded;
//     evidence256.blockSignature = csig;
//     evidence256.commitSignature = csig;

//     res = await ev.getCommitHash(evidence256);
//     console.log('commite hash: ', res);

//     console.log('Submitting evidence..');
//     tx = await ev.verifySingleSignature(evidence256, newPubKey);

//     expect(tx).to.equal(false);
//   });

//   it('encoding single slashing proof', async function () {
//     proof = await getJSON('test/hardhat/slashing_single/proof.json');

//     a = [
//       ethers.BigNumber.from(proof.pi_a[0]),
//       ethers.BigNumber.from(proof.pi_a[1]),
//     ];
//     b = [
//       [
//         ethers.BigNumber.from(proof.pi_b[0][1]),
//         ethers.BigNumber.from(proof.pi_b[0][0]),
//       ],
//       [
//         ethers.BigNumber.from(proof.pi_b[1][1]),
//         ethers.BigNumber.from(proof.pi_b[1][0]),
//       ],
//     ];
//     c = [
//       ethers.BigNumber.from(proof.pi_c[0]),
//       ethers.BigNumber.from(proof.pi_c[1]),
//     ];

//     const encoded = await ethers.utils.defaultAbiCoder.encode(verSigABI, [
//       a,
//       b,
//       c,
//     ]);
//     // sigProof is the encoded single slashing proof which changes upon every circuit run for the same block.
//     // The following is the sigProof generated for the proof.json file used in this test.
//     const sigProof =
//       '0x152d8a13a6a4a4023327ba9b68beb79cd7dcbf1b90eeddfa58a786ced1fca3980ac69e7f319f67a8bfb1e4500721192f22c594a162eaac0b0b71e83e8fed5ede2fa5988202dec5d9eff9d2dba69e0a8646d6e1f9da2e2cceec0ba13d29e6f889062071e05e21120c505d80f0e1f7374c0e262f97f87832cf08b7d734e68c790912c9d43e81ec81bbfd6757751bda7868c0418e9d3a7719dedc2016497a32e61b2c9718f224ae20ce9cd4ccc53ef343632e3b203c51e8ed1c41e67c35b6d4e9ea12ab5d66f0c1491b6b851136f29705e9c93d5eeba35a88a7fbbd994e6aa798ad0d2b60fd68cc4c6172d0c902a3e594426409fd3f17f0977da484fad41e130193';
//     expect(encoded).to.equal(sigProof);
//   });

//   it('slashing_aggregate_16 triage', async function () {
//     const triAgg = shared.SAVT;

//     pub = await getJSON('test/hardhat/slashing_aggregate_16/public.json');
//     proof = await getJSON('test/hardhat/slashing_aggregate_16/proof.json');

//     a = [
//       ethers.BigNumber.from(proof.pi_a[0]),
//       ethers.BigNumber.from(proof.pi_a[1]),
//     ];
//     b = [
//       [
//         ethers.BigNumber.from(proof.pi_b[0][1]),
//         ethers.BigNumber.from(proof.pi_b[0][0]),
//       ],
//       [
//         ethers.BigNumber.from(proof.pi_b[1][1]),
//         ethers.BigNumber.from(proof.pi_b[1][0]),
//       ],
//     ];
//     c = [
//       ethers.BigNumber.from(proof.pi_c[0]),
//       ethers.BigNumber.from(proof.pi_c[1]),
//     ];

//     const encoded = ethers.utils.defaultAbiCoder.encode(verAggABI, [a, b, c]);
//     evidence.aggProof = encoded;

//     tx = await triAgg.verifyAggregateSignature(
//       evidence,
//       9, //committeeSize
//     );
//     console.log(tx);
//     expect(tx).to.equal(true);
//   });

//   it('slashing_aggregate_256 triage', async function () {
//     const triAgg = shared.SAVT;

//     pub = await getJSON('test/hardhat/slashing_aggregate_256/public.json');
//     proof = await getJSON('test/hardhat/slashing_aggregate_256/proof.json');

//     a = [
//       ethers.BigNumber.from(proof.pi_a[0]),
//       ethers.BigNumber.from(proof.pi_a[1]),
//     ];
//     b = [
//       [
//         ethers.BigNumber.from(proof.pi_b[0][1]),
//         ethers.BigNumber.from(proof.pi_b[0][0]),
//       ],
//       [
//         ethers.BigNumber.from(proof.pi_b[1][1]),
//         ethers.BigNumber.from(proof.pi_b[1][0]),
//       ],
//     ];
//     c = [
//       ethers.BigNumber.from(proof.pi_c[0]),
//       ethers.BigNumber.from(proof.pi_c[1]),
//     ];

//     const encoded = ethers.utils.defaultAbiCoder.encode(verAggABI, [a, b, c]);
//     evidence256.aggProof = encoded;

//     tx = await triAgg.verifyAggregateSignature(
//       evidence256,
//       150, //committeeSize
//     );
//     console.log(tx);
//     expect(tx).to.equal(true);
//   });

//   it('encoding aggregate slashing proof 256', async function () {
//     proof = await getJSON('test/hardhat/slashing_aggregate_256/proof.json');

//     a = [
//       ethers.BigNumber.from(proof.pi_a[0]),
//       ethers.BigNumber.from(proof.pi_a[1]),
//     ];
//     b = [
//       [
//         ethers.BigNumber.from(proof.pi_b[0][1]),
//         ethers.BigNumber.from(proof.pi_b[0][0]),
//       ],
//       [
//         ethers.BigNumber.from(proof.pi_b[1][1]),
//         ethers.BigNumber.from(proof.pi_b[1][0]),
//       ],
//     ];
//     c = [
//       ethers.BigNumber.from(proof.pi_c[0]),
//       ethers.BigNumber.from(proof.pi_c[1]),
//     ];

//     const encoded = ethers.utils.defaultAbiCoder.encode(verAggABI, [a, b, c]);
//     // aggProof is the encoded aggregated proof for committee size 256 which changes upon every circuit run for the same block.
//     // The following is the aggProof generated for the proof.json file used in this test.
//     const aggProof =
//       '0x2d52a126704d88b3d2c988907276ee5c5eee904ea399a60f79a281c8610327d80e703096feb4974edd3c47f576c918262297aa8d8e759d4689ae6dea85ef5df02a3de101bba862a0e620045373463ed5bb5ff361fd91e1a44d78d63bbf6b6095093b9d0de0d3c8060a3e6cae6fa6b1e0be8d4eaffdd5459de21ba80d9feb9dd2008b2ed2da4caaa4e94e738b63a75e7c705f4fce7561ed514e1ba183e2373c160f4cb44832965336ea82da6c704e45abea37b3294bd7f3d8ae5eed37f912ed0a0faca2a9793dd60e09d344122c8a9da04b7574cda39be390ea34b84d6ce6f3be1188dd5591df11990f9dfec9e7b8f8b9d320bf70533fc9d726916b41bda9875d';
//     expect(encoded).to.equal(aggProof);
//   });
// });
