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
    '0x8495E007fA46ef6328dB1E55121729B504B9c97D', //operator
    '0xd4b08242e184ec7ce185b6c4f6dfd8b4776324bdc9dc5ddc505387dc02a7bd5b', //blockhash
    '0xd4b08242e184ec7ce185b6c4f6dfd8b4776324bdc9dc5ddc505387dc02a7bd5b', //correctblockhash
    '0x246cfc16271ed6cdc211e0502afa19c73d2fff009a744d16d0106b7f83a8d288', //currentCommitteeRoot
    '0x246cfc16271ed6cdc211e0502afa19c73d2fff009a744d16d0106b7f83a8d288', //correctCurrentCommitteeRoot
    '0x246cfc16271ed6cdc211e0502afa19c73d2fff009a744d16d0106b7f83a8d288', //nextCommitteeRoot
    '0x246cfc16271ed6cdc211e0502afa19c73d2fff009a744d16d0106b7f83a8d288', //correctNextCommitteeRoot
    '0x' + BigInt('0x1051f54').toString(16), //blockNumber
    '0x' + BigInt('0x0').toString(16), //epochBlockNumber
    '0x075f5ec21e913a3859149db05db009fb07a90a5f892c1aa29e0ab203c19ee2d5e8b1cb77edccfe677b68a8360a7879e90689902657fc60647dbbe68a576ed87477526b04d7deb962dc8f6f642d43beb3cd67acf589023bae744cfee70cd132681154189dc6069f496be1275e4b278a4ebe3ffa16a0c95750ef764b69f41fdbf27cb7e93952ea0239079834c61c9cf7f908c808507211dff1d09edd9384b2e36e20922126f26afe40cfbdce89ae5ed34402b590e5148c8a9cd582ebe8e7c7c730', //blockSignature
    '0x997ae075bec7d4ad12b16c64a31b0298f16f3d6fee8ec1bd044805e77631c64c7d2990d7d590aac58217dc6064ce0e459649a91a6b82f3e95c4d0f31bb44b7c21b', //commitSignature
    '0x1389', //chainID
    '0x00', //attestedBlockHeader
    '0x29b4f56033e8a52758c57ca6ec6fb519012fbcc0c903fc53f6ccd941d6d43d680175d37c8d7c77eed026b592ba1e149eb3c72c9c1b82f6de7293f870acb3ed1111c95bb2ab43430c2f28deb24c585a5861521dee3d1c61a9af19e934825d6c9a26e170c277d63114368629a45f6c3e40497ea07504f5c90aa4b1d38c31ee05de2128e00fe77305d7ac398182ebeaad1ce7fab9b845765c76dbf51276b8beeaca23a515caae65f683c02e5463f1003e54f03f2ead6a6abeb43e01ab68e328a6a22899ae9f436e71d5334c081130c4239666abef6f0e0f52b139c9658b3e77314a284967ca58aa407d2da64c8b161d2b869582bac8824659c3c9cc0e5549398225', //sigProof
    '0x283ae1db45b61c3aea606c6b8c732ffd560aa1f62d7e4dfe08f8d4e18687d61c215dec845a26c201c0cd32678087d9b5863ed4043b63b8610de2b95fd0e3dbde06ca2d53aef3736458f37ec421812bca51084b49872efb0ecb56907a2d653cf62a00485f5134e43432b81184af97d281eb56511c63d5b62ea9f459271de642322f307fd486387defabc821b7780fae4d024c3425aeb74e2552588e5c27ba6bac1013a69160a94572b3ea2983c92e1f3bb04c7d0502f59825776821cf3bdbf92b1d107f451c7e3773d309d5a659b4220a0ce1469b260a0013da4485c9ec4681e318917d4eb20a3a128aaf19f699c1ba59bb95d93be080ff8968c168fb3766020f', //aggProof
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
      'lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy',
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
    const evidence = await getSampleEvidence();
    try {
      await lagrangeService.uploadEvidence(evidence);
      expect('should have failed').to.be.false;
    } catch (error) {
      console.log(error);
      let revertReason = '';
      if (error.message) {
        const messageMatch = error.message.match(
          /reverted with reason string '([^']+)'/,
        );
        revertReason = messageMatch ? messageMatch[1] : '';
      }
      expect(revertReason).to.include('The operator is not registered');
    }
  });
});
