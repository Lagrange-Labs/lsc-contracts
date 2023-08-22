const { expect } = require("chai");
const { ethers } = require("hardhat");
const { poseidon } = require('circomlib');
const bls = require('@noble/bls12-381');
const shared = require("./shared");

const poseidonUnit = require("circomlibjs").poseidonContract;

const sponge = 0;

const deployPoseidon = async (signerNode) => {
    const poseidonAddrs = {};
    const params = [1, 2, 3, 4, 5, 6];
    await Promise.all(params.map(async i => {
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
        if (i == 2) {
            const res = await cd["poseidon(uint256[2])"]([1, 2]);
            const resString = res.toString();
            const target = String("7853200120776062878684798364095072458815029376092732009249414926327459813530");
            console.log("Result:", resString);
            console.log("Expected:", target);
            console.log("Hash check:", resString == target);
        }
        await cd.deployed();
        poseidonAddrs[i] = cd.address;
    }));

    return poseidonAddrs;
}

const serveUntilBlock = 4294967295;
const operators = require("../../config/operators.json");
const stake = 100000000;

describe("LagrangeCommittee", function () {
    let admin, proxy, poseidonAddresses;

    before(async function () {
        [admin] = await ethers.getSigners();
        poseidonAddresses = await deployPoseidon(admin);
    });

    beforeEach(async function () {
        const overrides = {
            gasLimit: 5000000,
        };

	//const Common = await ethers.getContractFactory("Common");
	//const common = await Common.deploy();
	//await common.deployed();
          
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

        console.log("Deploying empty contract...");

        const EmptyContractFactory = await ethers.getContractFactory("EmptyContract");
        const emptyContract = await EmptyContractFactory.deploy();
        await emptyContract.deployed();

        console.log("Deploying proxy...");

        const ProxyAdminFactory = await ethers.getContractFactory("ProxyAdmin");
        const proxyAdmin = await ProxyAdminFactory.deploy();
        await proxyAdmin.deployed();

        console.log("Deploying transparent proxy...");

        TransparentUpgradeableProxyFactory = await ethers.getContractFactory("TransparentUpgradeableProxy");
        lcproxy = await TransparentUpgradeableProxyFactory.deploy(emptyContract.address, proxyAdmin.address, "0x", overrides);
        await lcproxy.deployed();
        console.log("Committee proxy:",lcproxy.address);

        console.log("Deploying transparent proxy...");

        TransparentUpgradeableProxyFactory = await ethers.getContractFactory("TransparentUpgradeableProxy");
        lsproxy = await TransparentUpgradeableProxyFactory.deploy(emptyContract.address, proxyAdmin.address, "0x", overrides);
        await lsproxy.deployed();
        console.log("Service proxy:",lsproxy.address);

        console.log("Deploying transparent proxy...");

        TransparentUpgradeableProxyFactory = await ethers.getContractFactory("TransparentUpgradeableProxy");
        lsmproxy = await TransparentUpgradeableProxyFactory.deploy(emptyContract.address, proxyAdmin.address, "0x", overrides);
        await lsmproxy.deployed();

        console.log("Deploying Lagrange Service Manager...");
        
        const LSMFactory = await ethers.getContractFactory("LagrangeServiceManager");
        const lsm = await LSMFactory.deploy(slasher.address, lcproxy.address, lsproxy.address, overrides);
        await lsm.deployed();

        console.log("Upgrading proxy...");
        await proxyAdmin.upgradeAndCall(
            lsmproxy.address,
            lsm.address,
            lsm.interface.encodeFunctionData("initialize", [admin.address])
        )

        console.log("Deploying Lagrange Service...");

        const LSFactory = await ethers.getContractFactory("LagrangeService",{});
        const lagrangeService = await LSFactory.deploy(lcproxy.address, lsmproxy.address, overrides);
        await lagrangeService.deployed();
        lsaddr = lagrangeService.address;
        lcpaddr = await lagrangeService.committee();
        console.log("Service committee:",lcpaddr);

        console.log("Upgrading proxy...");
        await proxyAdmin.upgradeAndCall(
            lsproxy.address,
            lagrangeService.address,
            lagrangeService.interface.encodeFunctionData("initialize", [admin.address])
        )
        
        console.log("Deploying Lagrange Committee...");

        const LagrangeCommitteeFactory = await ethers.getContractFactory("LagrangeCommittee");
        const committee = await LagrangeCommitteeFactory.deploy(lagrangeService.address, lsmproxy.address, sm.address);
        await committee.deployed();
        
        serv = await committee.service();
        console.log("Committee service:",serv);

        console.log("Upgrading proxy...");
        await proxyAdmin.upgradeAndCall(
            lcproxy.address,
            committee.address,
            committee.interface.encodeFunctionData("initialize", [admin.address, poseidonAddresses[1], poseidonAddresses[2], poseidonAddresses[3], poseidonAddresses[4], poseidonAddresses[5], poseidonAddresses[6]])
        )

        const outboxFactory = await ethers.getContractFactory("Outbox");
        const outbox = await outboxFactory.deploy();
        await outbox.deployed();
        outboxAddr = outbox.address;

        const l2ooFactory = await ethers.getContractFactory("L2OutputOracle");
        const l2oo = await l2ooFactory.deploy(
            1,//_submissionInterval
            1,//_l2BlockTime
            11991388-1,//_startingBlockNumber
            1,//_startingTimestamp
            "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",//_proposer
            "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",//_challenger
            5//_finalizationPeriodSeconds
        );
        await l2oo.deployed();
        l2ooAddr = l2oo.address;
        
        const ovFactory = await ethers.getContractFactory("OptimismVerifier");
        const opt = await ovFactory.deploy(l2oo.address);
        
        const avFactory = await ethers.getContractFactory("ArbitrumVerifier");
        const arb = await avFactory.deploy(outbox.address);

        const rhvFactory = await ethers.getContractFactory("RecursiveHeaderVerifier");
        const rhv = await rhvFactory.deploy();

        console.log("L2OutputOracle:",l2oo.address);
        console.log("Outbox:",outbox.address);
        
        await lagrangeService.setOptAddr(opt.address);
        await lagrangeService.setArbAddr(arb.address);
        await lagrangeService.setRHVerifier(rhv.address);

        console.log("OptimismVerifier:",opt.address);
        console.log("ArbitrumVerifier:",arb.address);
        
        shared.LagrangeCommittee = committee;
        shared.LagrangeService = lagrangeService;
        shared.LagrangeServiceManager = lsm;
        shared.L2OutputOracle = l2oo;
        shared.Outbox = outbox;
        shared.RecursiveHeaderVerifier = rhv;
    });

    it("leaf hash", async function () {
        ls = shared.LagrangeService;
        
        const committee = await ethers.getContractAt("LagrangeCommittee", lcproxy.address, admin)
        const pubKey = bls.PointG1.fromHex(operators[0].bls_pub_keys[0].slice(2));
        const Gx = pubKey.toAffine()[0].value.toString(16).padStart(96, '0');
        const Gy = pubKey.toAffine()[1].value.toString(16).padStart(96, '0');
        const newPubKey = "0x" + Gx + Gy;
        const address = operators[0].operators[0];
        await ls.register(operators[0].chain_id, newPubKey, serveUntilBlock);
        console.log("committee.registerChain()");
        await committee.registerChain(operators[0].chain_id, 10000, 1000);

        const chunks = [];
        for (let i = 0; i < 4; i++) {
            chunks.push(BigInt("0x" + Gx.slice(i * 24, (i + 1) * 24)));
        }
        
        for (let i = 0; i < 4; i++) {
            chunks.push(BigInt("0x" + Gy.slice(i * 24, (i + 1) * 24)));
        }
        const stakeStr = stake.toString(16).padStart(32, '0');
        chunks.push(BigInt(address.slice(0, 26)));
        chunks.push(BigInt("0x" + address.slice(26, 42) + stakeStr.slice(0, 8)));
        chunks.push(BigInt("0x" + stakeStr.slice(8, 32)));
        
        const left = poseidon(chunks.slice(0, 6));
        const right = poseidon(chunks.slice(6, 11));
        const leaf = poseidon([left, right]);
        console.log(chunks.map((e) => { return e.toString(16);}), leaf.toString(16));

        const leafHash = await committee.committeeLeaves(operators[0].chain_id, 0);
        const committeeRoot = await committee.getCommittee(operators[0].chain_id, 1000);
        const op = await committee.operators(operators[0].operators[0]);
        console.log(op);
        console.log(leafHash);
        expect(leafHash).to.equal(committeeRoot.currentCommittee.root);
        expect(stake).to.equal(committeeRoot.currentCommittee.totalVotingPower.toNumber());
        expect(leaf).to.equal(leafHash);
    });

    it("merkle root", async function () {
        ls = shared.LagrangeService;
        
        const committee = await ethers.getContractAt("LagrangeCommittee", lcproxy.address, admin);
        for (let i = 0; i < operators[0].operators.length; i++) {
            const op = operators[0].operators[i];
            const pubKey = bls.PointG1.fromHex(operators[0].bls_pub_keys[i].slice(2));
            const Gx = pubKey.toAffine()[0].value.toString(16).padStart(96, '0');
            const Gy = pubKey.toAffine()[1].value.toString(16).padStart(96, '0');
            const newPubKey = "0x" + Gx + Gy;

            console.log("lagrangeService.reguster()");
            await ls.register(operators[0].chain_id, newPubKey, serveUntilBlock);
        }
        console.log("lagrangeService.register()");
        //await ls.register(operators[0].chain_id, newPubKey, serveUntilBlock);

        console.log("calculating roots...");
        const leaves = await Promise.all(operators[0].operators.map(async (op, index) => {
            const leaf = await committee.committeeLeaves(operators[0].chain_id, index);
            return BigInt(leaf.toHexString());
        }));
        const committeeRoot = await committee.getCommittee(operators[0].chain_id, 1000);
        console.log("leaves: ", leaves.map(l => l.toString(16)));
        console.log("current root: ", committeeRoot.currentCommittee.root.toHexString());
        console.log("next root: ", committeeRoot.nextRoot.toHexString());

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
                console.log("left: ", left, "right: ", right);
                const hash = poseidon([left, right]);
                console.log("hash: ", hash);
                leaves[i / 2] = hash;
            }
            count /= 2;
        }
        console.log(leaves[0].toString(16));
        expect("0x" + leaves[0].toString(16)).to.equal(committeeRoot.currentCommittee.root.toHexString());
    });
});
