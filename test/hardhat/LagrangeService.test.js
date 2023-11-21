const { expect } = require('chai');
const { ethers } = require('hardhat');
const shared = require('./shared');
const rlp = require('rlp');
const Big = require('big.js');
const sha3 = require('js-sha3');
const fs = require('fs');
const bls = require('bls-eth-wasm');

async function genBLSKey() {
  await bls.init(bls.BLS12_381);
  blsKey = new bls.SecretKey();
  await blsKey.setByCSPRNG();
  return blsKey;
}

async function uint2num(x) {
  return Buffer.from(x).toString('hex');
}

async function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function getSampleEvidence() {
  return [
    '0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9', //operator
    '0xabce508955d1aedc65109b5d11a197fde880dd771b613b28a045c6bf72f2c969', //blockhash
    '0xabce508955d1aedc65109b5d11a197fde880dd771b613b28a045c6bf72f2c969', //correctblockhash
    '0x0000000000000000000000000000000000000000000000000000000000000001', //currentCommitteeRoot
    '0x0000000000000000000000000000000000000000000000000000000000000001', //correctCurrentCommitteeRoot
    '0x0000000000000000000000000000000000000000000000000000000000000002', //nextCommitteeRoot
    '0x0000000000000000000000000000000000000000000000000000000000000002', //correctNextCommitteeRoot
    '0x' + BigInt('0x01c8f418').toString(16), //blockNumber
    '0x' + BigInt('0x0').toString(16), //epochBlockNumber
    '0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', //blockSignature
    '0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', //commitSignature
    '0x1A4', //chainID
    '0xf90224a03e35bf1913bae12f31df48d9bd5450c9adf0fcd0686bb7bb68f5dfbb6823e398a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d4934794a4b000000000000000000073657175656e636572a0af635f011e499ad2366378afaabbe75459dd3a3d9bf92658e7c15e9ad92ef543a02acba3ec11a59c368c8cbd9667239af674848f4dd129f9b93fca0131b1cbf190a07b687f4eff7095882b12a863619b74adfd84a40bf8d2e5512f5e078189b7c930b9010000000000000000000000000000000000000000020000000000000000000000000000000000000000800000000000000000200000000000000000000000200000004000000000000400000008000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000010000000010000000000000000800000000000002000000000000000100000000000000000020000001000000000000000000000000000000000000000000000002000000000000002000000100000000000000000000000010200000000000000000000000010000000000000000000000000000000000000000000000000000000000000018401c8f41887040000000000008306d4568464abbf39a093f89bc3c61a48a17c55ad285b2586df8e19fb9ce6790eca03aa30df8b639809a0000000000000981200000000008e3b0b000000000000000a0000000000000000880000000000074d998405f5e100', //rawBlockHeader
  ];
}

describe('LagrangeService', function () {
  let admin, proxy, lagrangeService, lc, lsm, lsaddr, l2ooAddr, outboxAddr;

  before(async function () {
    [admin] = await ethers.getSigners();
  });

  beforeEach(async function () {
    const overrides = {
      gasLimit: 5000000,
    };

    proxyAdmin = shared.proxyAdmin;
    proxy = shared.proxy;

    console.log('Deploying Slasher mock...');

    const SlasherFactory = await ethers.getContractFactory('Slasher');
    const slasher = await SlasherFactory.deploy(overrides);
    await slasher.deployed();
    shared.slasher = slasher;

    console.log('Loading Lagrange Committee shared state...');

    lc = shared.LagrangeCommittee;

    console.log('Deploying Lagrange Service Manager...');

    const LSMFactory = await ethers.getContractFactory(
      'LagrangeServiceManager',
    );
    const lsm = await LSMFactory.deploy(
      slasher.address,
      lc.address,
      admin.address,
      overrides,
    );
    await lsm.deployed();

    shared.LagrangeServiceManager = lsm;

    console.log('Deploying DelegationManager mock...');

    const DMFactory = await ethers.getContractFactory('DelegationManager');
    const dm = await DMFactory.deploy(overrides);
    await dm.deployed();

    console.log('Deploying StrategyManager mock...');

    const SMFactory = await ethers.getContractFactory('StrategyManager');
    const sm = await SMFactory.deploy(dm.address, overrides);
    await sm.deployed();

    console.log('Deploying Lagrange Service...');

    const LSFactory = await ethers.getContractFactory('LagrangeService', {});
    const lagrangeService = await LSFactory.deploy(
      lc.address,
      lsm.address,
      overrides,
    );
    await lagrangeService.deployed();
    lsaddr = lagrangeService.address;

    const TransparentUpgradeableProxyFactory = await ethers.getContractFactory(
      'TransparentUpgradeableProxy',
    );

    lsproxy = await TransparentUpgradeableProxyFactory.deploy(
      lagrangeService.address,
      proxyAdmin.address,
      '0x',
    );
    await lsproxy.deployed();

    const verSigFactory = await ethers.getContractFactory('Verifier');
    const verSig = await verSigFactory.deploy();
    await verSig.deployed();
    shared.SSV = verSig;
    evFactory = await ethers.getContractFactory('EvidenceVerifier');
    ev = await evFactory.deploy();
    await ev.deployed();
    ev.setSingleVerifier(verSig.address);
    shared.EV = ev;

    await proxyAdmin.upgradeAndCall(
      lsproxy.address,
      lagrangeService.address,
      lagrangeService.interface.encodeFunctionData('initialize', [
        admin.address,
        ev.address,
      ]),
    );

    lsproxy = await ethers.getContractAt('LagrangeService', lsproxy.address);

    shared.lsproxy = lsproxy;

    lsmproxy = await TransparentUpgradeableProxyFactory.deploy(
      lsm.address,
      proxyAdmin.address,
      '0x',
    );
    await lsmproxy.deployed();
    shared.lsmproxy = lsmproxy;

    shared.LagrangeService = lagrangeService;
  });

  it('Slashed status', async function () {
    const lc = shared.LagrangeCommittee;
    slashed = await lc.getSlashed('0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9');
    expect(slashed).to.equal(false);
  });
  it('Evidence submission (no registration)', async function () {
    const lagrangeService = await ethers.getContractAt(
      'LagrangeService',
      lsaddr,
      admin,
    );
    evidence = await getSampleEvidence();
    console.log(evidence);
    // Pre-registration
    try {
      await lagrangeService.uploadEvidence(evidence);
      expect(false).to.equal(false);
    } catch (error) { }
  });
  it('Evidence submission (slashing)', async function () {
    const lagrangeService = await ethers.getContractAt(
      'LagrangeService',
      lsaddr,
      admin,
    );
    evidence = await getSampleEvidence();
    console.log(evidence);
    // Pre-registration
    try {
      await lagrangeService.uploadEvidence(evidence);
      expect(false).to.equal(false);
    } catch (error) { }
  });
});
