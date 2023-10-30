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

const chainHeaderABI = [
    'bytes32',
    'uint256',
    'uint32'
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
        const verAgg64Factory = await ethers.getContractFactory("src/library/slashing_aggregate_64/verifier.sol:Verifier");
        
        const verSig = await verSigFactory.deploy();
        const verAgg = await verAggFactory.deploy();
        const verAgg32 = await verAgg32Factory.deploy();
        const verAgg64 = await verAgg64Factory.deploy();
        
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
        await taProxy.setRoute(64,verAgg64.address);
        
        shared.SSV = verSig;
        shared.SAV = verAgg;
        shared.SAV32 = verAgg32;
        shared.SAV64 = verAgg64;
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
    /*
    it("slashing_aggregate_32 verifier", async function () {
        const verAgg = shared.SAV32;
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
    it("slashing_aggregate_64 verifier", async function () {
        const verAgg = shared.SAV64;
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
    */
    it("triage smoke tests", async function () {
        const verSig = shared.SSV;
        const verAgg = shared.SAV;
        const verAgg32 = shared.SAV32;
        const verAgg64 = shared.SAV64;
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
        k = await triAgg.verifiers(64);
        expect(k).to.equal(verAgg64.address);
        l = await triAgg.verifiers(256);
        expect(l).to.equal("0x0000000000000000000000000000000000000000");
    });
    it("slashing_single triage", async function () {
        // load relevant contracts from shared
        const triSig = shared.SSVT;
        // retrieve input and public statement
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
        // convert input to hex bytes for evidence
        const encoded = await ethers.utils.defaultAbiCoder.encode(verSigABI, [a,b,c,input]);
        // use bls keypair, derived from query layer
        blsPriv = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
        blsPub = "0x86b50179774296419b7e8375118823ddb06940d9a28ea045ab418c7ecbe6da84d416cb55406eec6393db97ac26e38bd4";
        // derive chainheader from in-contract event emission
        chainHeaderPreimage = await ethers.utils.solidityPack(
            chainHeaderABI,[
            "0x90b40de3f413784ec5a5aa2de3e9b7e4f00b81b473d38095e98740e8f40e7e31",
            39613956,
            421613
            ]
        );
        console.log("preimage:",chainHeaderPreimage);
        chainHeader = await ethers.utils.keccak256(chainHeaderPreimage);
        console.log("hash:",chainHeader);
        // derive signingRoot from chainHeader and cur/next committee roots, poseidon hash
        signingRoot = chainHeader
                    + "2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514"
                    + "2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514";

        srHash = await poseidon.hashBytes(Uint8Array.from(Buffer.from(signingRoot.slice(2), 'hex'))).toString(16);
        if (srHash.length % 2 == 1) {
            srHash = '0' + srHash;
        }
        console.log("signingRoot:",signingRoot,"hash:",ethers.BigNumber.from('0x'+srHash));
        // sign signingroot
	message = new Uint8Array(Buffer.from(srHash,'hex'));
	signature = "0x842f2fb51708ee79d8ef1ac3e09cddb6b6b2f8ab770f440658819485170411c02fa3d97dee3ed4402d86f773bc5011cb098544560f1e495b4caf13964ea820f773c84e254156b7b8a4abde9c9953896b4eab2004c5e4d4d75d8f5791c5d180d8";
	console.log("aggsig___:",signature);
        coords = await bls.PointG2.fromHex(signature.slice(2));
        console.log(coords);
	/*
	*/
	/*
	signature = await bls.sign(message, blsPriv.slice(2));
	// convert coordinates to hex for verifier
        coords = await bls.PointG2.fromSignature(signature);
	*/
	affine = [
	  coords.toAffine()[0].c0.value.toString(16).padStart(96, '0'),
	  coords.toAffine()[0].c1.value.toString(16).padStart(96, '0'),
	  coords.toAffine()[1].c0.value.toString(16).padStart(96, '0'),
	  coords.toAffine()[1].c1.value.toString(16).padStart(96, '0'),  
	]; 
	csig = '0x' + affine.join("");
	console.log("signature:",csig);
	     
    const pubKey = await bls.PointG1.fromHex(blsPub.slice(2));
    const Gx = await pubKey.toAffine()[0].value.toString(16).padStart(96, '0');
    const Gy = await pubKey.toAffine()[1].value.toString(16).padStart(96, '0');
    const newPubKey = '0x' + Gx + Gy;
            
    const evidence = {
        operator: "0x5d51B4c1fb0c67d0e1274EC96c1B895F45505a3D",
        blockHash: "0xd31e8eeac337ce066c9b6fedd907c4e0e0ac2fdd61078c61e8f0df9af0481896",
        correctBlockHash: "0xd31e8eeac337ce066c9b6fedd907c4e0e0ac2fdd61078c61e8f0df9af0481896",
        currentCommitteeRoot: "0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514",
        correctCurrentCommitteeRoot: "0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514",
        nextCommitteeRoot: "0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514",
        correctNextCommitteeRoot: "0x2e3d2e5c97ee5320cccfd50434daeab6b0072558b693bb0e7f2eeca97741e514",
        blockNumber: 28809913,
        epochBlockNumber: "0x0000000000000000000000000000000000000000000000000000000000000000",
        blockSignature: csig,
        commitSignature:csig,
        chainID: 421613,
        attestBlockHeader: "0x00",
        sigProof: encoded,
        aggProof: "0x00"
    };

        tx = await triSig.verify(
            evidence,
            newPubKey,
            1
        );
        /*
        rec = await tx.wait();
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
          expect(tx).to.equal(true);
        };
    });
    /*
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
        
        const indices = [21];
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
    it("slashing_aggregate_64 triage", async function () {
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
        
        const indices = [34,55];
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
    */
});
