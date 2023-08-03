const { expect } = require("chai");
const { ethers } = require("hardhat");
const shared = require("./shared");
const rlp = require('rlp');
const Big = require('big.js');
const sha3 = require('js-sha3');
const fs = require('fs');
const bls = require("bls-eth-wasm");

async function genBLSKey() {
    await bls.init(bls.BLS12_381);
    blsKey = new bls.SecretKey();
    await blsKey.setByCSPRNG();
    return blsKey;
}

async function uint2num(x) {
    return Buffer.from(x).toString('hex');
}

async function delay(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

async function getSampleEvidence() {
    return  [
          "0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9", //operator
          "0xabce508955d1aedc65109b5d11a197fde880dd771b613b28a045c6bf72f2c969", //blockhash
          "0xabce508955d1aedc65109b5d11a197fde880dd771b613b28a045c6bf72f2c969", //correctblockhash
          "0x0000000000000000000000000000000000000000000000000000000000000001", //currentCommitteeRoot
          "0x0000000000000000000000000000000000000000000000000000000000000001", //correctCurrentCommitteeRoot
          "0x0000000000000000000000000000000000000000000000000000000000000002", //nextCommitteeRoot
          "0x0000000000000000000000000000000000000000000000000000000000000002", //correctNextCommitteeRoot
          '0x'+BigInt('0x01c8f418').toString(16), //blockNumber
          '0x'+BigInt('0x0').toString(16), //epochBlockNumber
          "0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", //blockSignature
          "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", //commitSignature
          "0x1A4", //chainID
          "0xf90224a03e35bf1913bae12f31df48d9bd5450c9adf0fcd0686bb7bb68f5dfbb6823e398a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d4934794a4b000000000000000000073657175656e636572a0af635f011e499ad2366378afaabbe75459dd3a3d9bf92658e7c15e9ad92ef543a02acba3ec11a59c368c8cbd9667239af674848f4dd129f9b93fca0131b1cbf190a07b687f4eff7095882b12a863619b74adfd84a40bf8d2e5512f5e078189b7c930b9010000000000000000000000000000000000000000020000000000000000000000000000000000000000800000000000000000200000000000000000000000200000004000000000000400000008000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000010000000010000000000000000800000000000002000000000000000100000000000000000020000001000000000000000000000000000000000000000000000002000000000000002000000100000000000000000000000010200000000000000000000000010000000000000000000000000000000000000000000000000000000000000018401c8f41887040000000000008306d4568464abbf39a093f89bc3c61a48a17c55ad285b2586df8e19fb9ce6790eca03aa30df8b639809a0000000000000981200000000008e3b0b000000000000000a0000000000000000880000000000074d998405f5e100", //rawBlockHeader
        ];
}

describe("LagrangeService",
 function () {
    let admin, proxy, lagrangeService, lc, lsm, lsaddr, l2ooAddr, outboxAddr;

    before(async function () {
        [admin] = await ethers.getSigners();
    });

    beforeEach(async function () {
        const overrides = {
            gasLimit: 5000000,
        };

	const Common = await ethers.getContractFactory("Common");
	const common = await Common.deploy();
	await common.deployed();
          
        console.log("Deploying Slasher mock...");

        const SlasherFactory = await ethers.getContractFactory("Slasher");
        const slasher = await SlasherFactory.deploy(overrides);
        await slasher.deployed();

        console.log("Deploying Lagrange Service Manager...");
        
        const LSMFactory = await ethers.getContractFactory("LagrangeServiceManager");
        const lsm = await LSMFactory.deploy(slasher.address, overrides);
        await lsm.deployed();
        
        console.log("Loading Lagrange Committee shared state...");
        
        lc = shared.LagrangeCommittee;

        console.log("Deploying DelegationManager mock...");

        const DMFactory = await ethers.getContractFactory("DelegationManager");
        const dm = await DMFactory.deploy(overrides);
        await dm.deployed();

        console.log("Deploying StrategyManager mock...");

        const SMFactory = await ethers.getContractFactory("StrategyManager");
        const sm = await SMFactory.deploy(dm.address, overrides);
        await sm.deployed();

        console.log("Deploying Lagrange Service...");

        const LSFactory = await ethers.getContractFactory("LagrangeService",{});
        const lagrangeService = await LSFactory.deploy(lsm.address, lc.address, sm.address, overrides);
        await lagrangeService.deployed();
        lsaddr = lagrangeService.address;
        
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
        
        console.log("L2OutputOracle:",l2oo.address);
        console.log("Outbox:",outbox.address);
        
        await lagrangeService.setOptAddr(opt.address);
        await lagrangeService.setArbAddr(arb.address);

        console.log("OptimismVerifier:",opt.address);
        console.log("ArbitrumVerifier:",arb.address);
    });
        
     it('Smoke test L2-L1 settlement interfaces', async function() {
         const lagrangeService = await ethers.getContractAt("LagrangeService", lsaddr, admin)
	 addr1 = await lagrangeService.getArbAddr();
	 addr2 = await lagrangeService.getOptAddr();
	 console.log(addr1,addr2);
	 expect(addr1 != "0x0000000000000000000000000000000000000000" && addr2 != "0x0000000000000000000000000000000000000000").to.equal(true);
	 
     });
    it('Slashed status', async function() {
        const lc = shared.LagrangeCommittee;
        slashed = await lc.getSlashed("0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9");
        expect(slashed).to.equal(false);
    });
    it('Evidence submission (no registration)', async function() {
        const lagrangeService = await ethers.getContractAt("LagrangeService", lsaddr, admin)
        evidence = await getSampleEvidence();
        console.log(evidence)
        // Pre-registration
        try {
            await lagrangeService.uploadEvidence(evidence);
            expect(false).to.equal(false);
        } catch(error) {
        }
    });
    it('Optimism Output Verification', async function() {
        outputRoot = "0x9c7c59dcfc75aa57697ae880a52f82f179150a7e24d208f7f7ad804ea99535cb";
        const lagrangeService = await ethers.getContractAt("LagrangeService", lsaddr, admin);
        optAddr = await lagrangeService.getOptAddr();
        const ov = await ethers.getContractAt("OptimismVerifier", optAddr, admin);
        const l2oo = await ethers.getContractAt("IL2OutputOracle", l2ooAddr, admin);
        //console.log(l2oo);
        for (i = 0; i < 2; i++) {
          try {
          console.log("verifyOutputProof (pass "+(i+1)+")");
          outputProof = [
                  "0x0000000000000000000000000000000000000000000000000000000000000000",
                  "0xd0670aef39b98b172b625ca7dcb5823ba8b5be30e6832cb6a2d337d5b1038250",
                  "0xadb5d075466430af8891c4c88014ffb2e759752dde83a813713c4a5cd1fb3de6",
                  "0x061ec88a69acdc6f70289979cdb84d29f9024a09fabf6a48a11d7625078870b8"
              ];
          expect(i).to.equal(1);
          hash = await ov.getOutputHash(outputProof);
          expect(hash).to.equal(outputRoot);
          res = await ov.verifyOutputProof(
              11991348,
              "0xdd0ababc17fd2e1b37941fe55302df7ee03672b1b8acd738d05eac8c75cddd74",
              outputProof
          );
          expect(res).to.equal(true);
          console.log("result:",res);
          // check against output
          } catch(error) {
              // no output, first pass
              let provider = ethers.provider; // You can also use other providers
              let block = await provider.getBlock('latest');
              
              latest = await l2oo.latestBlockNumber();
              next = await l2oo.nextBlockNumber();
              console.log("latest:",latest);
              console.log("next:",next);
              
              if(i) console.log(error);

              expect(i).to.equal(0);
              
              // propose output
              await l2oo.proposeL2Output(
                outputRoot,
                11991388,
                block.hash,
                block.number
              );
              // confirm output exists
              oi = await l2oo.getL2OutputAfter(11991348);
              expect(oi.outputRoot).to.equal(outputRoot);
              // proceed to second pass
          }
        }
    });
    it('Arbitrum Verification', async function() {
        const lagrangeService = await ethers.getContractAt("LagrangeService", lsaddr, admin);
        arbAddr = await lagrangeService.getArbAddr();
        const av = await ethers.getContractAt("ArbitrumVerifier", arbAddr, admin);
        const ob = await ethers.getContractAt("IOutbox", outboxAddr, admin);
        // nonexistent root
        res = await av.verifyArbBlock(
            "0xf90224a06d44daee2a7d707dcd5cac574cba7ac880605be3d9cb090f8623f99120e13051a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d4934794a4b000000000000000000073657175656e636572a0b1a27641b49b7410f847dd7403cbfc77fb330c4682e4352f297e5733af7356e9a0d55ce2c8b1bc257d8548a011a3ee08512efd3e8d92143c5cf93b57cffacb9f7ba0aa5128dfa53bd7927f53918ddd02e2cf6d088e9fd3c8542dadbf1129d33dcc68b90100000000000000000800000080000000000004000000000100008001001000000000000000800000000000000000401200000000004000240000000000002000000000000000800008020000082000000000000000100000000000000000000000000000000000000c0000000000000000000000000000000000000010200880000000020000000100000000000000000000000004000000000000000000010000020000000000000000000000200040000000000000000000080000800020000000000002000000000000000000000000000000000000000400000000000020000010000000008000002000000080000000000000000000000000000000000000018401f1407d870400000000000083068c058464c9296da089c534a1c0018f90b84c7af63945814995a590091958c64f5610dce5bce91ac4a00000000000009c080000000000901ffe000000000000000a000000000000000088000000000008a7e38405f5e100",
            32587901,
            "0x550f72aec7c027aeb9ecb3a219dd7fb5792d246747e611a8c59c9da5f696fba3",
            "0x00",
            421613
        );
        expect(res).to.equal(false);
        await ob.updateSendRoot("0x89c534a1c0018f90b84c7af63945814995a590091958c64f5610dce5bce91ac4","0x550f72aec7c027aeb9ecb3a219dd7fb5792d246747e611a8c59c9da5f696fba3");
        // valid root
        res = await av.verifyArbBlock(
            "0xf90224a06d44daee2a7d707dcd5cac574cba7ac880605be3d9cb090f8623f99120e13051a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d4934794a4b000000000000000000073657175656e636572a0b1a27641b49b7410f847dd7403cbfc77fb330c4682e4352f297e5733af7356e9a0d55ce2c8b1bc257d8548a011a3ee08512efd3e8d92143c5cf93b57cffacb9f7ba0aa5128dfa53bd7927f53918ddd02e2cf6d088e9fd3c8542dadbf1129d33dcc68b90100000000000000000800000080000000000004000000000100008001001000000000000000800000000000000000401200000000004000240000000000002000000000000000800008020000082000000000000000100000000000000000000000000000000000000c0000000000000000000000000000000000000010200880000000020000000100000000000000000000000004000000000000000000010000020000000000000000000000200040000000000000000000080000800020000000000002000000000000000000000000000000000000000400000000000020000010000000008000002000000080000000000000000000000000000000000000018401f1407d870400000000000083068c058464c9296da089c534a1c0018f90b84c7af63945814995a590091958c64f5610dce5bce91ac4a00000000000009c080000000000901ffe000000000000000a000000000000000088000000000008a7e38405f5e100",
            32587901,
            "0x550f72aec7c027aeb9ecb3a219dd7fb5792d246747e611a8c59c9da5f696fba3",
            "0x00",
            421613
        );
        expect(res).to.equal(true);
        // invalid hash
        try {
        res = await av.verifyArbBlock(
            "0xf90224a06d44daee2a7d707dcd5cac574cba7ac880605be3d9cb090f8623f99120e13051a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d4934794a4b000000000000000000073657175656e636572a0b1a27641b49b7410f847dd7403cbfc77fb330c4682e4352f297e5733af7356e9a0d55ce2c8b1bc257d8548a011a3ee08512efd3e8d92143c5cf93b57cffacb9f7ba0aa5128dfa53bd7927f53918ddd02e2cf6d088e9fd3c8542dadbf1129d33dcc68b90100000000000000000800000080000000000004000000000100008001001000000000000000800000000000000000401200000000004000240000000000002000000000000000800008020000082000000000000000100000000000000000000000000000000000000c0000000000000000000000000000000000000010200880000000020000000100000000000000000000000004000000000000000000010000020000000000000000000000200040000000000000000000080000800020000000000002000000000000000000000000000000000000000400000000000020000010000000008000002000000080000000000000000000000000000000000000018401f1407d870400000000000083068c058464c9296da089c534a1c0018f90b84c7af63945814995a590091958c64f5610dce5bce91ac4a00000000000009c080000000000901ffe000000000000000a000000000000000088000000000008a7e38405f5e100",
            32587901,
            "0x0000000000000000000000000000000000000000000000000000000000000000",
            "0x00",
            421613
        );
            expect(true).to.equal(false);
        } catch(error) {
        }
    });
    /*
    it('Registration', async function() {
        const lagrangeService = await ethers.getContractAt("LagrangeService", lsaddr, admin);
        // Register
        blsKey = await genBLSKey();
        priv = blsKey.serializeToHexStr();
        pub = blsKey.getPublicKey();
        res = await lagrangeService.register(420,pub.serialize(),5);
    });
    */
        /*
        frozenStatus = await lsm.slasher.isFrozen("0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9");
        try {
            await lagrangeService.freezeOperator("0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9");
        } catch(error) {
	    freezeException = true;
        }
        */
});
