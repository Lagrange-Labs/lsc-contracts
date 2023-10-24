const { expect } = require("chai");
const { ethers } = require("hardhat");
const fs = require('fs');
const shared = require("./shared");
const bls = require('@noble/bls12-381');
let { PointG1, PointG2 } = require("./zk-utils-index.js");
const { poseidon } = require("@iden3/js-crypto");

const verSigABI = [
    'uint[2]',
    'uint[2][2]',
    'uint[2]',
    'uint[47]'
];

const verAggABI = [
    'uint[2]',
    'uint[2][2]',
    'uint[2]',
    'uint[5]'
];

async function getJSON(path) {
     txt = await fs.readFileSync(path);
     json = await JSON.parse(txt);
     return json;
}

describe("Lagrange Verifiers", function () {
    let admin;
    before(async function () {
        [admin] = await ethers.getSigners();
    });

    beforeEach(async function () {
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
        tsProxy = await TransparentUpgradeableProxyFactory.deploy(emptyContract.address, proxyAdmin.address, "0x");
        await tsProxy.deployed();

        TransparentUpgradeableProxyFactory = await ethers.getContractFactory("TransparentUpgradeableProxy");
        taProxy = await TransparentUpgradeableProxyFactory.deploy(emptyContract.address, proxyAdmin.address, "0x");
        await taProxy.deployed();

        console.log("Deploying verifier contracts...");
        
        const verSigFactory = await ethers.getContractFactory("src/library/slashing_single/verifier.sol:Verifier");
        const verAggFactory = await ethers.getContractFactory("src/library/slashing_aggregate_16/verifier.sol:Verifier");
        const verAgg32Factory = await ethers.getContractFactory("src/library/slashing_aggregate_32/verifier.sol:Verifier");
        
        const verSig = await verSigFactory.deploy();
        const verAgg = await verAggFactory.deploy();
        const verAgg32 = await verAgg32Factory.deploy();
        
        console.log("Deploying verifier triage contracts...");

        const triSigFactory = await ethers.getContractFactory("SlashingSingleVerifierTriage");
        const triAggFactory = await ethers.getContractFactory("SlashingAggregateVerifierTriage");
        
        const triSig = await triSigFactory.deploy();
        const triAgg = await triAggFactory.deploy();
        
        tx1 = await verSig.deployed();
        tx2 = await verAgg.deployed();
        tx3 = await verAgg.deployed();
        tx4 = await triSig.deployed();
        tx5 = await triAgg.deployed();

        console.log("Upgrading proxy...");

        await proxyAdmin.upgradeAndCall(
            tsProxy.address,
            triSig.address,
            triSig.interface.encodeFunctionData("initialize", [admin.address])
        )

        await proxyAdmin.upgradeAndCall(
            taProxy.address,
            triAgg.address,
            triAgg.interface.encodeFunctionData("initialize", [admin.address])
        )
        
        console.log("signature verifier:",verSig.address);
        console.log("aggregate verifier:",verAgg.address);
        console.log("signature triage:",tsProxy.address);
        console.log("aggregate triage:",taProxy.address);
        
        console.log("Linking verifier triage contracts to verifier contracts...");
        
        tsProxy = await ethers.getContractAt("SlashingSingleVerifierTriage",tsProxy.address);
        taProxy = await ethers.getContractAt("SlashingAggregateVerifierTriage",taProxy.address);

        await tsProxy.setRoute(1,verSig.address);
        
        await taProxy.setRoute(1,verAgg.address);
        await taProxy.setRoute(2,verAgg.address);
        await taProxy.setRoute(4,verAgg.address);
        await taProxy.setRoute(8,verAgg.address);
        await taProxy.setRoute(16,verAgg.address);
        await taProxy.setRoute(32,verAgg32.address);
        
        shared.SSV = verSig;
        shared.SAV = verAgg;
        shared.SAV32 = verAgg32;
        shared.SSVT = tsProxy;
        shared.SAVTimp = triAgg;
        shared.SAVT = taProxy;
    });

    it("slashing_single verifier", async function () {
        const verSig = shared.SSV;
        pub = await getJSON("test/hardhat/slashing_single/public.json");
        proof = await getJSON("test/hardhat/slashing_single/proof.json");
        pubNumeric = Object.values(pub).map(ethers.BigNumber.from);
        
        a = [
          ethers.BigNumber.from(proof.pi_a[0]),
          ethers.BigNumber.from(proof.pi_a[1])
        ];
        b = [
         [
          ethers.BigNumber.from(proof.pi_b[0][1]),
          ethers.BigNumber.from(proof.pi_b[0][0]),
         ],
         [
          ethers.BigNumber.from(proof.pi_b[1][1]),
          ethers.BigNumber.from(proof.pi_b[1][0]),
         ]
        ];
        c = [
          ethers.BigNumber.from(proof.pi_c[0]),
          ethers.BigNumber.from(proof.pi_c[1])
        ];
        input = pubNumeric;
        
        res = await verSig.verifyProof(a,b,c,input);
        expect(res).to.equal(true);
    });
    it("slashing_aggregate_16 verifier", async function () {
        const verAgg = shared.SAV;
        pub = await getJSON("test/hardhat/slashing_aggregate_16/public.json");
        proof = await getJSON("test/hardhat/slashing_aggregate_16/proof.json");
        pubNumeric = Object.values(pub).map(ethers.BigNumber.from);
        
        a = [
          ethers.BigNumber.from(proof.pi_a[0]),
          ethers.BigNumber.from(proof.pi_a[1])
        ];
        b = [
         [
          ethers.BigNumber.from(proof.pi_b[0][1]),
          ethers.BigNumber.from(proof.pi_b[0][0]),
         ],
         [
          ethers.BigNumber.from(proof.pi_b[1][1]),
          ethers.BigNumber.from(proof.pi_b[1][0]),
         ]
        ];
        c = [
          ethers.BigNumber.from(proof.pi_c[0]),
          ethers.BigNumber.from(proof.pi_c[1])
        ];
        input = pubNumeric;
        
        res = await verAgg.verifyProof(a,b,c,input);
        expect(res).to.equal(true);
    });
    it("triage smoke tests", async function () {
        const verSig = shared.SSV;
        const verAgg = shared.SAV;
        const verAgg32 = shared.SAV32;
        const triSig = shared.SSVT;
        const triAgg = shared.SAVT;
        
        a = await triSig.verifiers(0);
        expect(a).to.equal("0x0000000000000000000000000000000000000000");
        b = await triSig.verifiers(1);
        expect(b).to.equal(verSig.address);
        c = await triSig.verifiers(2);
        expect(c).to.equal("0x0000000000000000000000000000000000000000");
        
        d = await triAgg.verifiers(0);
        expect(d).to.equal("0x0000000000000000000000000000000000000000");
        e = await triAgg.verifiers(1);
        expect(e).to.equal(verAgg.address);
        f = await triAgg.verifiers(2);
        expect(f).to.equal(verAgg.address);
        g = await triAgg.verifiers(4);
        expect(g).to.equal(verAgg.address);
        h = await triAgg.verifiers(8);
        expect(h).to.equal(verAgg.address);
        i = await triAgg.verifiers(16);
        expect(i).to.equal(verAgg.address);
        j = await triAgg.verifiers(32);
        expect(j).to.equal(verAgg32.address);
        k = await triAgg.verifiers(256);
        expect(k).to.equal("0x0000000000000000000000000000000000000000");
    });
    it("slashing_single triage", async function () {
        const triSig = shared.SSVT;
        pub = await getJSON("test/hardhat/slashing_single/public.json");
        proof = await getJSON("test/hardhat/slashing_single/proof.json");
        pubNumeric = Object.values(pub).map(ethers.BigNumber.from);
        
        a = [
          ethers.BigNumber.from(proof.pi_a[0]),
          ethers.BigNumber.from(proof.pi_a[1])
        ];
        b = [
         [
          ethers.BigNumber.from(proof.pi_b[0][1]),
          ethers.BigNumber.from(proof.pi_b[0][0]),
         ],
         [
          ethers.BigNumber.from(proof.pi_b[1][1]),
          ethers.BigNumber.from(proof.pi_b[1][0]),
         ]
        ];
        c = [
          ethers.BigNumber.from(proof.pi_c[0]),
          ethers.BigNumber.from(proof.pi_c[1])
        ];
        input = pubNumeric;
        
        const encoded = await ethers.utils.defaultAbiCoder.encode(verSigABI, [a,b,c,input]);
        
        blsPriv = "0x27d402641e400663087b57e1394e1dffa233083129ff5283555c193f7d0aecfc";
        blsPub = "0xb66a7d0803f34de5acbb832dc4952c4c486367e1c2a9356be3836f4ee4a20acc0b0fe8a76c89210eea0bf4490f0af93b";
        chainHeader = "0xe796232da2a2990e05ed6a097c4964f8ce229c3b3c4f0bc9bf9b0b15f344d61b";
        signingRoot = chainHeader
                    + "15c5994da30094441f9b699a147c4f5b87eaf8bfb1effec08d16e94e79464756"
                    + "15c5994da30094441f9b699a147c4f5b87eaf8bfb1effec08d16e94e79464756";
        srHash = await poseidon.hashBytes(Uint8Array.from(Buffer.from(signingRoot.slice(2), 'hex'))).toString(16);
        console.log(signingRoot,srHash);
        
	message = new Uint8Array(Buffer.from(srHash,'hex'));
	signature = await bls.sign(message, blsPriv.slice(2));
        coords = await bls.PointG2.fromSignature(signature);
	affine = [
	  coords.toAffine()[0].c0.value.toString(16).padStart(96, '0'),
	  coords.toAffine()[0].c1.value.toString(16).padStart(96, '0'),
	  coords.toAffine()[1].c0.value.toString(16).padStart(96, '0'),
	  coords.toAffine()[1].c1.value.toString(16).padStart(96, '0'),  
	]; 
	
	     
    const pubKey = await bls.PointG1.fromHex(blsPub.slice(2));
    const Gx = await pubKey.toAffine()[0].value.toString(16).padStart(96, '0');
    const Gy = await pubKey.toAffine()[1].value.toString(16).padStart(96, '0');
    const newPubKey = '0x' + Gx + Gy;

	console.log(newPubKey);return;
        
        csig = "0x"
        + "0e4121f36bffdfea60d4ad6f76f46e8b14ff065ae65ebe38fde5058d717c45535ef83723106fe34270d8dd51f6628163"
        + "0fa18e6016e317a0965ed54d6de009d2bb47a93a1fff59757f41e781ac3efb9a4a91c50d6a4b0cf68e4ee07dbd740f2b"
        + "038474fb4623f9053b90424eced3f507608ed293cef1c44b54e91e7e05fb7d4a2340f00b71ea2ad53a650801b3e8399f"
        + "1866fc169a323ad7b1f98d4f34f3e71e62e52bc649245de6c733e2073a3ba7bd1d399a8de58ae9c4739c651884faf080";
        
    const evidence = {
        operator: "0x0000000000000000000000000000000000000000",
        blockHash: "0xa0091f9446be880a0674e20fb5ec6c4d0511e5d687c5e7e36f01393beec1df96",
        correctBlockHash: "0xa0091f9446be880a0674e20fb5ec6c4d0511e5d687c5e7e36f01393beec1df96",
        currentCommitteeRoot: "0x15c5994da30094441f9b699a147c4f5b87eaf8bfb1effec08d16e94e79464756",
        correctCurrentCommitteeRoot: "0x15c5994da30094441f9b699a147c4f5b87eaf8bfb1effec08d16e94e79464756",
        nextCommitteeRoot: "0x15c5994da30094441f9b699a147c4f5b87eaf8bfb1effec08d16e94e79464756",
        correctNextCommitteeRoot: "0x15c5994da30094441f9b699a147c4f5b87eaf8bfb1effec08d16e94e79464756",
        blockNumber: 23173304,
        epochBlockNumber: "0x0000000000000000000000000000000000000000000000000000000000000000",
        blockSignature: csig,
        commitSignature:csig,
        chainID: 5001,
        attestBlockHeader: "0x00",
        sigProof: encoded,
        aggProof: "0x00"
    };

        tx = await triSig.verify(
            evidence,
            "0x166a7d0803f34de5acbb832dc4952c4c486367e1c2a9356be3836f4ee4a20acc0b0fe8a76c89210eea0bf4490f0af93b"
            + "1929866a5a506aecf1110492f8d466ffd096831e9d930faf4f843c99e974bce24761bd4f599fd4b5a6ba7ae1b4210dc8",
            1
        );
        /*
        rec = await tx.wait();
        console.log(JSON.stringify(rec.events,null,2));
	console.log(rec.events[0].args);
        */
	
        expect(tx).to.equal(true);
    });
    it("slashing_aggregate_16 triage", async function () {
        const triAgg = shared.SAVT;

        pub = await getJSON("test/hardhat/slashing_aggregate_16/public.json");
        proof = await getJSON("test/hardhat/slashing_aggregate_16/proof.json");
        pubNumeric = Object.values(pub).map(ethers.BigNumber.from);
	
        a = [
          ethers.BigNumber.from(proof.pi_a[0]),
          ethers.BigNumber.from(proof.pi_a[1])
        ];
        b = [
         [
          ethers.BigNumber.from(proof.pi_b[0][1]),
          ethers.BigNumber.from(proof.pi_b[0][0]),
         ],
         [
          ethers.BigNumber.from(proof.pi_b[1][1]),
          ethers.BigNumber.from(proof.pi_b[1][0]),
         ]
        ];
        c = [
          ethers.BigNumber.from(proof.pi_c[0]),
          ethers.BigNumber.from(proof.pi_c[1])
        ];
        input = pubNumeric;
        
        const encoded = ethers.utils.defaultAbiCoder.encode(verAggABI, [a,b,c,input]);
        
        const indices = [1, 2, 3, 5, 8, 13];
        for(i = 0; i < indices.length; i++) {
          index = indices[i];
          
          tx = await triAgg.verify(
            encoded, //aggProof
            "0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514", //currentCommitteeRoot
            "0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514", //nextCommitteeRoot
            "0xd31e8eeac337ce066c9b6fedd907c4e0e0ac2fdd61078c61e8f0df9af0481896", //blockHash
            28809913, //blockNumber
            421613, //chainID
            9 //committeeSize
          );
          console.log(tx);
          //rec = await tx.wait();
          //console.log(await rec.events[0].args);
          expect(tx).to.equal(true);
        };
    });
    it("slashing_aggregate_32 triage", async function () {
        const triAgg = shared.SAVT;

        pub = await getJSON("test/hardhat/slashing_aggregate_16/public.json");
        proof = await getJSON("test/hardhat/slashing_aggregate_16/proof.json");
        pubNumeric = Object.values(pub).map(ethers.BigNumber.from);
        a = [
          ethers.BigNumber.from(proof.pi_a[0]),
          ethers.BigNumber.from(proof.pi_a[1])
        ];
        b = [
         [
          ethers.BigNumber.from(proof.pi_b[0][1]),
          ethers.BigNumber.from(proof.pi_b[0][0]),
         ],
         [
          ethers.BigNumber.from(proof.pi_b[1][1]),
          ethers.BigNumber.from(proof.pi_b[1][0]),
         ]
        ];
        c = [
          ethers.BigNumber.from(proof.pi_c[0]),
          ethers.BigNumber.from(proof.pi_c[1])
        ];
        input = pubNumeric;
        
        const encoded = ethers.utils.defaultAbiCoder.encode(verAggABI, [a,b,c,input]);
        
        const indices = [32];
        for(i = 0; i < indices.length; i++) {
          index = indices[i];
          tx = await triAgg.verify(
            encoded, //aggProof
            "0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514", //currentCommitteeRoot
            "0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514", //nextCommitteeRoot
            "0x95aea085c0d4a908eed989c9f2c793477d53309ae3e9f0a28f29510ffeff2b91", //blockHash
            28810640, //blockNumber
            421613, //chainID
            index //committeeSize
          );
          expect(tx).to.equal(true);
        };
    });
});
