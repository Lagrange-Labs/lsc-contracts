const { expect } = require('chai');
const { ethers } = require('hardhat');
const { bn254 } = require('@noble/curves/bn254');
const { mineUpTo } = require('@nomicfoundation/hardhat-network-helpers');

const operators = require('../../config/operators.json');

const stake = 100000000;
const minWeight = 50000;
const maxWeight = 200000;

describe('LagrangeCommittee', function () {
  let admin, committeeProxy, voteWeigherProxy, stakeManagerProxy, token;

  before(async function () {
    [admin] = await ethers.getSigners();
  });

  beforeEach(async function () {
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

    committeeProxy = await TransparentUpgradeableProxyFactory.deploy(
      emptyContract.address,
      proxyAdmin.address,
      '0x',
    );
    await committeeProxy.deployed();

    voteWeigherProxy = await TransparentUpgradeableProxyFactory.deploy(
      emptyContract.address,
      proxyAdmin.address,
      '0x',
    );
    await voteWeigherProxy.deployed();

    stakeManagerProxy = await TransparentUpgradeableProxyFactory.deploy(
      emptyContract.address,
      proxyAdmin.address,
      '0x',
    );
    await stakeManagerProxy.deployed();

    const StakeManagerFactory = await ethers.getContractFactory('StakeManager');
    const stakeManager = await StakeManagerFactory.deploy(admin.address);
    await stakeManager.deployed();

    const VoteWeigherFactory = await ethers.getContractFactory('VoteWeigher');
    const voteWeigher = await VoteWeigherFactory.deploy(
      stakeManagerProxy.address,
    );
    await voteWeigher.deployed();

    const LagrangeCommitteeFactory =
      await ethers.getContractFactory('LagrangeCommittee');
    const committee = await LagrangeCommitteeFactory.deploy(
      admin.address,
      voteWeigherProxy.address,
    );
    await committee.deployed();

    console.log('Upgrading proxy...');

    await proxyAdmin.upgradeAndCall(
      committeeProxy.address,
      committee.address,
      committee.interface.encodeFunctionData('initialize', [admin.address]),
    );

    await proxyAdmin.upgradeAndCall(
      voteWeigherProxy.address,
      voteWeigher.address,
      voteWeigher.interface.encodeFunctionData('initialize', [admin.address]),
    );

    await proxyAdmin.upgradeAndCall(
      stakeManagerProxy.address,
      stakeManager.address,
      stakeManager.interface.encodeFunctionData('initialize', [admin.address]),
    );

    const WETH9Factory = await ethers.getContractFactory('WETH9');
    token = await WETH9Factory.deploy();
    await token.deployed();

    const voteWeigherProxyContract = await ethers.getContractAt(
      'VoteWeigher',
      voteWeigherProxy.address,
      admin,
    );
    await voteWeigherProxyContract.addQuorumMultiplier(0, [
      { token: token.address, multiplier: 1e15 },
    ]);
    const stakeManagerProxyContract = await ethers.getContractAt(
      'StakeManager',
      stakeManagerProxy.address,
      admin,
    );
    await stakeManagerProxyContract.addTokensToWhitelist([token.address]);
  });

  it('trie construction/deconstruction', async function () {
    const committee = await ethers.getContractAt(
      'LagrangeCommittee',
      committeeProxy.address,
      admin,
    );
    const stakeManager = await ethers.getContractAt(
      'StakeManager',
      stakeManagerProxy.address,
      admin,
    );

    const chainCount = 4;
    const operatorCount = 10;

    const operators = [];
    for (let j = 1; j < operatorCount; j++) {
      const operator = await ethers.getSigner(j);
      const bls_pub_key = '0x' + '0'.repeat(63) + j;
      await token.connect(operator).deposit({ value: stake * j });
      await token.connect(operator).approve(stakeManager.address, stake * j);
      await stakeManager.connect(operator).deposit(token.address, stake * j);

      await committee.addOperator(operator.address, operator.address, [
        [bls_pub_key, bls_pub_key],
      ]);
      operators.push(operator);
    }
    for (i = 1; i <= chainCount; i++) {
      await committee.registerChain(i, 0, 10000, 1000, 0, minWeight, maxWeight);

      console.log('Building trie of size ' + i + '...');
      await Promise.all(
        operators.map(async (operator) => {
          return committee.subscribeChain(operator.address, i);
        }),
      );
    }

    await mineUpTo(9500);
    await committee.update(1, 1);

    await mineUpTo(15000);
    croot = await committee.getCommittee(1, 15000);
    console.log('current committee: ', croot);

    for (i = 1; i <= chainCount; i++) {
      console.log('Deconstructing trie #' + i + '...');
      await Promise.all(
        operators.map(async (operator) => {
          return committee.unsubscribeChain(operator.address, i);
        }),
      );
    }
  });

  it('leaf hash', async function () {
    const committee = await ethers.getContractAt(
      'LagrangeCommittee',
      committeeProxy.address,
      admin,
    );
    const stakeManager = await ethers.getContractAt(
      'StakeManager',
      stakeManagerProxy.address,
      admin,
    );

    await mineUpTo(20000);
    await committee.registerChain(
      operators[0].chain_id,
      0,
      10000,
      1000,
      0,
      minWeight,
      maxWeight,
    );

    // deposit stake
    const signer = await ethers.getSigner(1);
    await token.connect(signer).deposit({ value: stake });
    await token.connect(signer).approve(stakeManager.address, stake);
    await stakeManager.connect(signer).deposit(token.address, stake);

    const Gx = operators[0].bls_pub_keys[0].slice(0, 66);
    const Gy = '0x' + operators[0].bls_pub_keys[0].slice(66);
    const newPubKeys = [[Gx, Gy]];

    await committee.addOperator(signer.address, signer.address, newPubKeys);
    await committee.subscribeChain(signer.address, operators[0].chain_id);

    const leaf = ethers.utils.solidityKeccak256(
      ['bytes1', 'uint256', 'uint256', 'address', 'uint96'],
      ['0x01', Gx, Gy, signer.address, stake / 1e3],
    );

    await mineUpTo(29500);
    await committee.update(operators[0].chain_id, 1);

    const committeeRoot = await committee.getCommittee(
      operators[0].chain_id,
      35000,
    );
    const expectVotingPower = await committee.getOperatorVotingPower(
      signer.address,
      operators[0].chain_id,
    );
    expect(stake).to.equal(expectVotingPower.toNumber() * 1e3);
    expect(leaf).to.equal(committeeRoot.root);
  });

  it('merkle root', async function () {
    const committee = await ethers.getContractAt(
      'LagrangeCommittee',
      committeeProxy.address,
      admin,
    );
    const stakeManager = await ethers.getContractAt(
      'StakeManager',
      stakeManagerProxy.address,
      admin,
    );

    await mineUpTo(40000);
    await committee.registerChain(
      operators[0].chain_id,
      0,
      10000,
      1000,
      0,
      minWeight,
      maxWeight,
    );

    // deposit stake
    for (let i = 0; i < operators[0].operators.length; i++) {
      const signer = await ethers.getSigner(i + 1);
      const _stake =
        1000 * Math.floor(minWeight + Math.random() * (maxWeight - minWeight));
      await token.connect(signer).deposit({ value: _stake });
      await token.connect(signer).approve(stakeManager.address, _stake);
      await stakeManager.connect(signer).deposit(token.address, _stake);

      const Gx = operators[0].bls_pub_keys[i].slice(0, 66);
      const Gy = '0x' + operators[0].bls_pub_keys[i].slice(66);
      const newPubKeys = [[Gx, Gy]];

      await committee.addOperator(signer.address, signer.address, newPubKeys);
      await committee.subscribeChain(signer.address, operators[0].chain_id);
    }

    await mineUpTo(49500);
    await committee.update(operators[0].chain_id, 1);

    const leaves = [];

    const _leavesList = await Promise.all(
      operators[0].operators.map(async (_, index) => {
        const signer = await ethers.getSigner(index + 1);
        const operator = signer.address;
        const votingPowers = await committee.getBlsPubKeyVotingPowers(
          operator,
          operators[0].chain_id,
        );
        const _leaves = [];
        for (let i = 0; i < votingPowers.length; i++) {
          const Gx = operators[0].bls_pub_keys[index].slice(0, 66);
          const Gy = '0x' + operators[0].bls_pub_keys[index].slice(66);
          const leaf = ethers.utils.solidityKeccak256(
            ['bytes1', 'uint256', 'uint256', 'address', 'uint96'],
            ['0x01', Gx, Gy, operator, votingPowers[i].toNumber()],
          );
          _leaves.push(leaf);
        }
        return _leaves;
      }),
    );
    console.log({ _leavesList });
    _leavesList.forEach((_leaves) => leaves.push(..._leaves));

    const committeeRoot = await committee.getCommittee(
      operators[0].chain_id,
      55000,
    );

    let count = 1;
    while (count < leaves.length) {
      count *= 2;
    }
    const len = leaves.length;
    for (let i = 0; i < count - len; i++) {
      leaves.push('0x' + '0'.repeat(64));
    }

    while (count > 1) {
      for (let i = 0; i < count; i += 2) {
        const left = leaves[i];
        const right = leaves[i + 1];
        const hash = ethers.utils.solidityKeccak256(
          ['bytes1', 'bytes32', 'bytes32'],
          ['0x02', left, right],
        );
        leaves[i / 2] = hash;
      }
      count /= 2;
    }
    expect(leaves[0]).to.equal(committeeRoot.root);
  });
});
