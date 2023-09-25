const { expect } = require("chai");
const { ethers } = require("hardhat");
const shared = require("./shared");
const common = require("./common");
const { poseidon } = require("circomlib");

const serveUntilBlock = 4294967295;
const operators = require("../../config/operators.json");
const stake = 100000000;

describe("LagrangeCommittee", function () {
  let admin, proxy, poseidonAddresses, lcpaddr;

  before(async function () {
    [admin] = await ethers.getSigners();
    await common.deployPoseidon(admin);
  });

  beforeEach(async function () {
      await common.redeploy(admin);
      lcpaddr = shared.ServiceCommittee;
  });

  it("leaf hash", async function () {
  return;
    this.timeout(60000);
    ls = shared.LagrangeService;

    const committee = await ethers.getContractAt(
      "LagrangeCommittee",
      lcpaddr,
      admin
    );
    
    const data = await common.registerOperatorAndChain(operators[0], 0, serveUntilBlock);
    address = data.address;
    Gx = data.Gx;
    Gy = data.Gy;
    
    const chunks = [];
    for (let i = 0; i < 4; i++) {
      chunks.push(BigInt("0x" + Gx.slice(i * 24, (i + 1) * 24)));
    }

    for (let i = 0; i < 4; i++) {
      chunks.push(BigInt("0x" + Gy.slice(i * 24, (i + 1) * 24)));
    }
    const stakeStr = stake.toString(16).padStart(32, "0");
    chunks.push(BigInt(address.slice(0, 26)));
    chunks.push(BigInt("0x" + address.slice(26, 42) + stakeStr.slice(0, 8)));
    chunks.push(BigInt("0x" + stakeStr.slice(8, 32)));

    const left = poseidon(chunks.slice(0, 6));
    const right = poseidon(chunks.slice(6, 11));
    const leaf = poseidon([left, right]);
    console.log(
      chunks.map((e) => {
        return e.toString(16);
      }),
      leaf.toString(16)
    );

    const leafHash = await committee.committeeLeaves(operators[0].chain_id, 0);
    const op = await committee.operators(operators[0].operators[0]);
    const committeeRoot = await committee.getCommittee(
      operators[0].chain_id,
      1000
    );
    console.log(op);
    console.log(leafHash);
    expect(leafHash).to.equal(committeeRoot.currentCommittee.root);
    console.log(committeeRoot);
    expect(stake).to.equal(
      committeeRoot.currentCommittee.totalVotingPower.toNumber()
    );
    expect(leaf).to.equal(leafHash);
  });

  it("merkle root", async function () {
  return;
    this.timeout(60000);
    ls = common.LagrangeService;

    const committee = await ethers.getContractAt(
      "LagrangeCommittee",
      lcpaddr,
      admin
    );

    for (let i = 0; i < operators[0].operators.length; i++) {
      const op = operators[0].operators[i];
      const data = await common.register(operators[0], i, serveUntilBlock);
    }

    start = Date.now();
    await common.registerChain(operators[0],0);
    end = Date.now();
    console.log("Done. (" + (end - start) + " ms)");

    console.log("calculating roots...");
    //console.log(operators);
    const leaves = await Promise.all(
      operators[0].operators.map(async (op, index) => {
        console.log(operators[0].chain_id, index);
        const leaf = await committee.committeeLeaves(
          operators[0].chain_id,
          index
        );
        return BigInt(leaf.toHexString());
      })
    );
    console.log(leaves);
    const committeeRoot = await committee.getCommittee(
      operators[0].chain_id,
      1000
    );
    console.log(
      "leaves: ",
      leaves.map((l) => l.toString(16))
    );
    console.log(
      "current root: ",
      committeeRoot.currentCommittee.root.toHexString()
    );
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
    expect("0x" + leaves[0].toString(16)).to.equal(
      committeeRoot.currentCommittee.root.toHexString()
    );
  });
});
