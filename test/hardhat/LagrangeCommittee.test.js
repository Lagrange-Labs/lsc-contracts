const { expect } = require('chai');
const { ethers } = require('hardhat');
const { bn254 } = require('@noble/curves/bn254');
const shared = require('./shared');

const serveUntilBlock = 4294967295;
const operators = require('../../config/operators.json');
const { keccak256 } = require('js-sha3');
const stake = 100000000;

describe('LagrangeCommittee', function () {
  let admin, proxy;

  before(async function () {
    [admin] = await ethers.getSigners();
  });

  beforeEach(async function () {
    const VoteWeigherFactory =
      await ethers.getContractFactory('VoteWeigherMock');
    const voteWeigher = await VoteWeigherFactory.deploy(admin.address);
    await voteWeigher.deployed();

    const LagrangeCommitteeFactory =
      await ethers.getContractFactory('LagrangeCommittee');
    const committee = await LagrangeCommitteeFactory.deploy(
      admin.address,
      voteWeigher.address,
    );
    await committee.deployed();

    console.log('Deploying empty contract...');

    const EmptyContractFactory =
      await ethers.getContractFactory('EmptyContract');
    const emptyContract = await EmptyContractFactory.deploy();
    await emptyContract.deployed();

    console.log('Deploying proxy...');

    const ProxyAdminFactory = await ethers.getContractFactory(
      'lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol:ProxyAdmin',
    );
    const proxyAdmin = await ProxyAdminFactory.deploy();
    await proxyAdmin.deployed();

    console.log('Deploying transparent proxy...');

    const TransparentUpgradeableProxyFactory = await ethers.getContractFactory(
      'lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy',
    );
    proxy = await TransparentUpgradeableProxyFactory.deploy(
      emptyContract.address,
      proxyAdmin.address,
      '0x',
    );
    await proxy.deployed();

    console.log('Upgrading proxy...');

    await proxyAdmin.upgradeAndCall(
      proxy.address,
      committee.address,
      committee.interface.encodeFunctionData('initialize', [admin.address]),
    );

    shared.LagrangeCommittee = committee;
    shared.proxy = proxy;
    shared.proxyAdmin = proxyAdmin;
    shared.voteWeigher = voteWeigher;
    shared.emptyContract = emptyContract;
  });

  it('trie construction/deconstruction', async function () {
    const committee = await ethers.getContractAt(
      'LagrangeCommittee',
      proxy.address,
      admin,
    );

    leafHashes = [];
    addrs = [];

    for (i = 4; i <= 4; i++) {
      console.log('Building trie of size ' + i + '...');
      chainid =
        '0x000000000000000000000000000000000000000000000000000000000000000' + i;
      for (j = 1; j <= i; j++) {
        addr = '0x000000000000000000000000000000000000000' + j;
        bls_pub_key = '0x' + '0'.repeat(63) + j;
        await committee.addOperator(
          addr,
          [bls_pub_key, bls_pub_key],
          4294967295,
        );
        tx = await committee.subscribeChain(addr, chainid);
        rec = await tx.wait();

        croot = await committee.committees(chainid, 1);
        console.log('trie root at size ' + j + ':', croot.root.toString());

        addrs.push(addr);
      }

      tx = await committee.registerChain(chainid, 10000, 1000);
      rec = await tx.wait();
    }

    const leaves = await Promise.all(
      addrs.map(async (op, index) => {
        return await committee.committeeNodes(4, 0, index);
      }),
    );
    croot = await committee.committees(chainid, 1);
    console.log('current root: ', croot);

    for (i = 0; i < 1; i++) {
      console.log('Deconstructing trie #' + i + '...');
      for (j = 0; j < addrs.length; j++) {
        index = 3 - j;
        console.log('Removing operator ' + addrs[index] + '...');
        tx = await committee.unsubscribeChain(addrs[index], chainid);
        rec = await tx.wait();
      }
    }
  });

  it('leaf hash', async function () {
    const committee = await ethers.getContractAt(
      'LagrangeCommittee',
      proxy.address,
      admin,
    );
    const pubKey = bn254.ProjectivePoint.fromHex(
      operators[0].bls_pub_keys[0].slice(2),
    );
    const Gx = pubKey.toAffine()[0].value.toString(16);
    const Gy = pubKey.toAffine()[1].value.toString(16);
    console.log(Gx, Gy);
    const newPubKey = [Gx, Gy];
    const address = operators[0].operators[0];

    await committee.addOperator(address, newPubKey, serveUntilBlock);
    await committee.subscribeChain(address, operators[0].chain_id);
    await committee.registerChain(operators[0].chain_id, 10000, 1000);

    const chunks = [];
    for (let i = 0; i < 4; i++) {
      chunks.push(BigInt('0x' + Gx.slice(i * 24, (i + 1) * 24)));
    }

    for (let i = 0; i < 4; i++) {
      chunks.push(BigInt('0x' + Gy.slice(i * 24, (i + 1) * 24)));
    }
    const stakeStr = stake.toString(16).padStart(32, '0');
    chunks.push(BigInt(address.slice(0, 26)));
    chunks.push(BigInt('0x' + address.slice(26, 42) + stakeStr.slice(0, 8)));
    chunks.push(BigInt('0x' + stakeStr.slice(8, 32)));

    const left = keccak256(chunks.slice(0, 6));
    const right = keccak256(chunks.slice(6, 11));
    const leaf = keccak256([left, right]);
    console.log(
      chunks.map((e) => {
        return e.toString(16);
      }),
      leaf.toString(16),
    );

    const leafHash = await committee.committeeNodes(
      operators[0].chain_id,
      0,
      0,
    );
    const committeeRoot = await committee.getCommittee(
      operators[0].chain_id,
      1000,
    );
    const op = await committee.operators(operators[0].operators[0]);
    console.log(op);
    console.log(leafHash);
    expect(leafHash).to.equal(committeeRoot.currentCommittee.root);
    expect(stake).to.equal(
      committeeRoot.currentCommittee.totalVotingPower.toNumber(),
    );
    expect(leaf).to.equal(leafHash);
  });

  it('merkle root', async function () {
    const committee = await ethers.getContractAt(
      'LagrangeCommittee',
      proxy.address,
      admin,
    );
    for (let i = 0; i < operators[0].operators.length; i++) {
      const op = operators[0].operators[i];
      const pubKey = bn254.ProjectivePoint.fromHex(operators[0].bls_pub_keys[i].slice(2));
      const Gx = pubKey.toAffine()[0].value.toString(16).padStart(96, '0');
      const Gy = pubKey.toAffine()[1].value.toString(16).padStart(96, '0');
      const newPubKey = '0x' + Gx + Gy;

      await committee.addOperator(op, newPubKey, serveUntilBlock);
      await committee.subscribeChain(op, operators[0].chain_id);
    }
    await committee.registerChain(operators[0].chain_id, 10000, 1000);

    const leaves = await Promise.all(
      operators[0].operators.map(async (op, index) => {
        return (leaf = await committee.committeeNodes(
          operators[0].chain_id,
          0,
          index,
        ));
      }),
    );
    const committeeRoot = await committee.getCommittee(
      operators[0].chain_id,
      1000,
    );

    let count = 1;
    while (count < leaves.length) {
      count *= 2;
    }
    const len = leaves.length;
    for (let i = 0; i < count - len; i++) {
      leaves.push(BigInt(0));
    }

    while (count > 1) {
      for (let i = 0; i < count; i += 2) {
        const left = leaves[i];
        const right = leaves[i + 1];
        const hash = keccak256([left, right]);
        leaves[i / 2] = hash;
      }
      count /= 2;
    }
    console.log(leaves[0].toString(16));
    expect('0x' + leaves[0].toString(16).padStart(64, '0')).to.equal(
      committeeRoot.currentCommittee.root.toHexString(),
    );
  });
  it('merkle tree update', async function () {
    const committee = await ethers.getContractAt(
      'LagrangeCommittee',
      proxy.address,
      admin,
    );
    for (let i = 0; i < operators[0].operators.length; i++) {
      const op = operators[0].operators[i];
      const pubKey = bn254.ProjectivePoint.fromHex(operators[0].bls_pub_keys[i].slice(2));
      const Gx = pubKey.toAffine()[0].value.toString(16).padStart(96, '0');
      const Gy = pubKey.toAffine()[1].value.toString(16).padStart(96, '0');
      const newPubKey = '0x' + Gx + Gy;

      await committee.addOperator(op, newPubKey, serveUntilBlock);
      await committee.subscribeChain(op, operators[0].chain_id);
    }

    // unsubscribe the first operator
    await committee.unsubscribeChain(
      operators[0].operators[0],
      operators[0].chain_id,
    );
    // unsubscribe the last operator
    await committee.unsubscribeChain(
      operators[0].operators[operators[0].operators.length - 2],
      operators[0].chain_id,
    );
    // unsubscribe the middle operator
    await committee.unsubscribeChain(
      operators[0].operators[4],
      operators[0].chain_id,
    );
    await committee.unsubscribeChain(
      operators[0].operators[5],
      operators[0].chain_id,
    );

    const tx = await committee.registerChain(
      operators[0].chain_id,
      10000,
      1000,
    );
    let operatorCount = operators[0].operators.length - 4;

    const leaves = await Promise.all(
      new Array(operatorCount).fill(0).map(async (_, index) => {
        const leaf = await committee.committeeNodes(
          operators[0].chain_id,
          0,
          index,
        );
        return BigInt(leaf.toHexString());
      }),
    );
    const committeeRoot = await committee.getCommittee(
      operators[0].chain_id,
      tx.blockNumber,
    );
    let count = 1;
    while (count < leaves.length) {
      count *= 2;
    }
    for (let i = 0; i < count - operatorCount; i++) {
      leaves.push(BigInt(0));
    }

    while (count > 1) {
      for (let i = 0; i < count; i += 2) {
        const left = leaves[i];
        const right = leaves[i + 1];
        const hash = keccak256([left, right]);
        leaves[i / 2] = hash;
      }
      count /= 2;
    }
    console.log(leaves[0].toString(16));
    expect('0x' + leaves[0].toString(16).padStart(64, '0')).to.equal(
      committeeRoot.currentCommittee.root,
    );
  });
});
