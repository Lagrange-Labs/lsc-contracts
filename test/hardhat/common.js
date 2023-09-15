const shared = require("./shared");
const { poseidon } = require("circomlib");
const poseidonUnit = require("circomlibjs").poseidonContract;

const sponge = 0;

const deployPoseidon = async (signerNode) => {
  console.log("Deploying Poseidon contracts...");
  const poseidonAddrs = {};
  const params = [1, 2, 3, 4, 5, 6];
  await Promise.all(
    params.map(async (i) => {
      let poseidonCode = null;
      let poseidonABI = null;
      try {
        if (sponge) {
          poseidonCode = await poseidonUnit.createCode("mimcsponge", 220);
          poseidonABI = await poseidonUnit.abi;
        } else {
          poseidonCode = await poseidonUnit.createCode(i);
          poseidonABI = await poseidonUnit.generateABI(i);
        }
      } catch (err) {
        console.log(err);
      }

      const cf = new ethers.ContractFactory(
        poseidonABI,
        poseidonCode,
        signerNode
      );
      const cd = await cf.deploy();
      await cd.deployed();
      if (i == 2) {
        const res = await cd["poseidon(uint256[2])"]([1, 2]);
        const resString = res.toString();
        const target = String(
          "7853200120776062878684798364095072458815029376092732009249414926327459813530"
        );
        console.log("Result:", resString);
        console.log("Expected:", target);
        console.log("Hash check:", resString == target);
      }
      poseidonAddrs[i] = cd.address;
    })
  );
  console.log("Done.");

  return poseidonAddrs;
};

async function redeploy(admin,poseidonAddresses) {
    const overrides = {
      gasLimit: 5000000,
    };
    
    //
    // Mock Contract Deployments
    //

    console.log("Deploying Slasher mock...");

    const SlasherFactory = await ethers.getContractFactory("Slasher");
    const slasher = await SlasherFactory.deploy(overrides);
    await slasher.deployed();

    console.log("Deploying DelegationManager mock...");

    const DMFactory = await ethers.getContractFactory("DelegationManager");
    const dm = await DMFactory.deploy(overrides);
    await dm.deployed();

    console.log("Deploying StrategyManager mock...");

    const SMFactory = await ethers.getContractFactory("StrategyManager");
    const sm = await SMFactory.deploy(dm.address, overrides);
    await sm.deployed();

    //
    // Proxy Setup
    //

    console.log("Deploying empty contract...");

    const EmptyContractFactory = await ethers.getContractFactory(
      "EmptyContract"
    );
    const emptyContract = await EmptyContractFactory.deploy();
    await emptyContract.deployed();

    console.log("Deploying admin proxy...");

    const ProxyAdminFactory = await ethers.getContractFactory("ProxyAdmin");
    const proxyAdmin = await ProxyAdminFactory.deploy();
    await proxyAdmin.deployed();

    console.log("Deploying transparent proxy...");

    TransparentUpgradeableProxyFactory = await ethers.getContractFactory(
      "TransparentUpgradeableProxy"
    );
    lcproxy = await TransparentUpgradeableProxyFactory.deploy(
      emptyContract.address,
      proxyAdmin.address,
      "0x",
      overrides
    );
    await lcproxy.deployed();
    console.log("Committee proxy:", lcproxy.address);

    console.log("Deploying transparent proxy...");

    TransparentUpgradeableProxyFactory = await ethers.getContractFactory(
      "TransparentUpgradeableProxy"
    );
    lsproxy = await TransparentUpgradeableProxyFactory.deploy(
      emptyContract.address,
      proxyAdmin.address,
      "0x",
      overrides
    );
    await lsproxy.deployed();
    console.log("Service proxy:", lsproxy.address);

    console.log("Deploying transparent proxy...");

    TransparentUpgradeableProxyFactory = await ethers.getContractFactory(
      "TransparentUpgradeableProxy"
    );
    lsmproxy = await TransparentUpgradeableProxyFactory.deploy(
      emptyContract.address,
      proxyAdmin.address,
      "0x",
      overrides
    );
    await lsmproxy.deployed();
    console.log("Service manager proxy:", lsmproxy.address);

    //
    // Implementation Setup
    //

    console.log("Deploying Lagrange Committee...");
    const LagrangeCommitteeFactory = await ethers.getContractFactory(
      "LagrangeCommittee"
    );
    const committee = await LagrangeCommitteeFactory.deploy(
      lsproxy.address,
      lsmproxy.address,
      sm.address
    );
    await committee.deployed();
    serv = await committee.service();
    console.log("Committee service:", serv);

    console.log("Deploying Lagrange Service Manager...");
    const LSMFactory = await ethers.getContractFactory(
      "LagrangeServiceManager"
    );
    const lsm = await LSMFactory.deploy(
      slasher.address,
      lcproxy.address,
      lsproxy.address,
      overrides
    );
    await lsm.deployed();

    console.log("Deploying Lagrange Service...");
    const LSFactory = await ethers.getContractFactory("LagrangeService", {});
    const lagrangeService = await LSFactory.deploy(
      lcproxy.address,
      lsmproxy.address,
      overrides
    );
    await lagrangeService.deployed();

    lsaddr = lagrangeService.address;
    lcpaddr = await lagrangeService.committee();
    console.log("Service committee:", lcpaddr);

    //
    // Verifier Libraries
    //

    const outboxFactory = await ethers.getContractFactory("Outbox");
    const outbox = await outboxFactory.deploy();
    await outbox.deployed();
    outboxAddr = outbox.address;

    const l2ooFactory = await ethers.getContractFactory("L2OutputOracle");
    const l2oo = await l2ooFactory.deploy(
      1, //_submissionInterval
      1, //_l2BlockTime
      11991388 - 1, //_startingBlockNumber
      1, //_startingTimestamp
      admin.address, //_proposer
      admin.address, //_challenger
      5 //_finalizationPeriodSeconds
    );
    await l2oo.deployed();
    l2ooAddr = l2oo.address;

    const ovFactory = await ethers.getContractFactory("OptimismVerifier");
    const opt = await ovFactory.deploy(l2oo.address);
    await opt.deployed();

    const avFactory = await ethers.getContractFactory("ArbitrumVerifier");
    const arb = await avFactory.deploy(outbox.address);
    await arb.deployed();

    const rhvFactory = await ethers.getContractFactory(
      "RecursiveHeaderVerifier"
    );
    const rhv = await rhvFactory.deploy();
    await rhv.deployed();

    console.log("L2OutputOracle:", l2oo.address);
    console.log("Outbox:", outbox.address);

    console.log("OptimismVerifier:", opt.address);
    console.log("ArbitrumVerifier:", arb.address);

    //
    // Proxy Upgrades
    //

    console.log("Upgrading service manager proxy...");
    await proxyAdmin.upgradeAndCall(
      lsmproxy.address,
      lsm.address,
      lsm.interface.encodeFunctionData("initialize", [admin.address])
    );
    lsmpaddr = lsmproxy.address;
    lsmproxy = await ethers.getContractAt("LagrangeServiceManager", lsmpaddr);

    console.log("Upgrading service proxy...");
    await proxyAdmin.upgradeAndCall(
      lsproxy.address,
      lagrangeService.address,
      lagrangeService.interface.encodeFunctionData("initialize", [
        admin.address,
        arb.address,
        opt.address,
        rhv.address,
      ])
    );
    lspaddr = lsproxy.address;
    lsproxy = await ethers.getContractAt("LagrangeService", lspaddr);

    console.log("Upgrading proxy...");
    await proxyAdmin.upgradeAndCall(
      lcproxy.address,
      committee.address,
      committee.interface.encodeFunctionData("initialize", [
        admin.address,
        poseidonAddresses[1],
        poseidonAddresses[2],
        poseidonAddresses[3],
        poseidonAddresses[4],
        poseidonAddresses[5],
        poseidonAddresses[6],
      ])
    );
    lcpaddr = lcproxy.address;
    lcproxy = await ethers.getContractAt("LagrangeCommittee", lcpaddr);

    shared.LagrangeCommittee = committee;
    shared.LagrangeCommitteeProxy = lcproxy;
    shared.LagrangeService = lagrangeService;
    shared.LagrangeServiceProxy = lsproxy;
    shared.LagrangeServiceManager = lsm;
    shared.L2OutputOracle = l2oo;
    shared.Outbox = outbox;
    shared.RecursiveHeaderVerifier = rhv;
}

async function getPubKeyByOperator(operator, index) {
    const pubKey = bls.PointG1.fromHex(operator.bls_pub_keys[index].slice(2));
    const Gx = pubKey.toAffine()[0].value.toString(16).padStart(96, "0");
    const Gy = pubKey.toAffine()[1].value.toString(16).padStart(96, "0");
    const newPubKey = "0x" + Gx + Gy;
    const address = operator.operators[index];
    return {newPubKey:newPubKey, address:address};
}

async function register(operator, index, lsproxy, serveUntilBlock) {
    const pkData = await getPubKeyByOperator(operator);
    
    console.log("lsproxy.register()");
    tx = await lsproxy.register(
      operator.chain_id,
      pkData.newPubKey,
      serveUntilBlock
    );//TODO review - based on msg.sender.  should n:1 bls:addr be permitted?  what is our testnet approach?
    console.log(await getGas(tx));
    
    return pkData;
}

async function registerChain(operator, index) {
    console.log("committee.registerChain()");
    tx = await committee.registerChain(operator.chain_id, 10000, 1000);
    console.log(await getGas(tx));
}

async function registerOperatorAndChain(operator, index, lsproxy, serveUntilBlock) {
    data = await register(operator, lsproxy, serveUntilBlock);
    await registerChain(operator);
    return data;
}

module.exports = {
    deployPoseidon:deployPoseidon,
    redeploy:redeploy,
    getPubKeyByOperator:getPubKeyByOperator,
    register:register,
    registerChain:registerChain,
};
