const exec = require('child_process');
const ethers = require("ethers");
//const { JsonRpcProvider } = require('ethers/providers');
const fs = require('fs')
const bls = require("bls-eth-wasm");
//const utils = require('utils');

async function testDefaultFreeze(nodeStaking) {
    console.log("testDefaultFreeze");
    frozenStatus = await nodeStaking.getFrozenStatus("0xb2AaA94B0dbc3Af219B5abD7a141d0F66d55fB82");
    freezeException = false;
    try {
        await nodeStaking.freezeOperator("0xb2AaA94B0dbc3Af219B5abD7a141d0F66d55fB82");
    } catch(error) {
	freezeException = true;
    }
    return freezeException && !frozenStatus;
}

async function getProvider() {
    const currentProvider = new ethers.providers.JsonRpcProvider('http://0.0.0.0:8545');
    return currentProvider;
}
async function getLagrangeCommittee(nodeStaking) {
    const currentProvider = await getProvider();
    const signerNode = await currentProvider.getSigner();
    const lgrcAddr = await nodeStaking.LGRCommittee();
    const lgrcABI = await fs.readFileSync("./deployments/privnet/LagrangeCommittee.json","utf-8");
    jsonABI = await JSON.parse(lgrcABI);
    sanitizedABI = await JSON.stringify(jsonABI);
    const lgrc = new ethers.Contract(lgrcAddr,jsonABI.abi,signerNode);
    return lgrc;
}

async function getNodeStaking(redeploy) {
    const currentProvider = await getProvider();
    const signerNode = await currentProvider.getSigner();
    
    if(redeploy) {
	console.log("Redeploying...");
	await exec.execSync("rm -rf ./deployments/privnet/");
	const options = { encoding: 'utf-8' }; // Set the encoding for the output
//	await exec.execSync("npx compile --force", options);
	const deploy = await exec.execSync("npx hardhat deploy --network privnet", options);
	console.log("Redeploying complete.");
	
        nsAddr = await fs.readFileSync("./tmp/nodestaking.addr","utf-8");
        nsABI = await fs.readFileSync("./tmp/nodestaking.abi","utf-8");

	console.log("NodeStaking Address:", nsAddr);
    
        jsonABI = await JSON.parse(nsABI);
        sanitizedABI = await JSON.stringify(jsonABI);
	
        const nodeStaking = new ethers.Contract(nsAddr,sanitizedABI,signerNode);

	console.log("Slasher Address:", nodeStaking.eslasher);
	return nodeStaking;
    } else {
        nsAddr = await fs.readFileSync("./tmp/nodestaking.addr","utf-8");
        nsABI = await fs.readFileSync("./tmp/nodestaking.abi","utf-8");
	
        jsonABI = await JSON.parse(nsABI);
        sanitizedABI = await JSON.stringify(jsonABI);

        const nodeStaking = new ethers.Contract(nsAddr,sanitizedABI,signerNode);
	return nodeStaking;
    }
}

async function genBLSKey() {
    await bls.init(bls.BLS12_381);
    blsKey = new bls.SecretKey();
    await blsKey.setByCSPRNG();
    return blsKey;
}

async function testAddStakeIdent(nodeStaking) {
    console.log("testAddStakeIdent");
    blsKey = await genBLSKey();
    priv = blsKey.serializeToHexStr();
    pub = blsKey.getPublicKey();
    console.log("BLS secret key:",priv);
    console.log("BLS public key:",await pub.serializeToHexStr());

    ecdsapk = "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
    const wallet = new ethers.Wallet(ecdsapk);

    const publicKey = wallet.publicKey;
    const address = wallet.address;

    console.log("Public Key:", publicKey.replace("0x","").substring(0,48));
    console.log("Address:", address);

    dataRoot = ethers.utils.formatBytes32String("abc");
    blsSig = blsKey.sign(dataRoot);
    blsSigHex = blsSig.serializeToHexStr();
    blsSigBytes = blsSig.serialize();
    console.log(blsSigHex);
    
    try {
        await nodeStaking.addStakeIdent(1, pub.serialize(), publicKey, dataRoot, blsSigBytes);
    } catch(error) {
        console.log(error);
        return false;
    }
    return true;
}

async function testVerifyStateRoot(nodeStaking) {
    console.log('testVerifyStateRoot');
    // calculate block hash
    blockHash = await nodeStaking.calculateBlockHash("0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a");
    console.log(blockHash == "0xecd60d0964cddddba478aa5d06d166d17417e16d9edb3c82bb5d343fde48c16f");
    // invalid block hash
    try {
        res = await nodeStaking.verifyStateRoot("0x0000000000000000000000000000000000000000000000000000000000000000","0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3");
    } catch(error) {
        console.log(true);
    }
    // invalid state root
    try {
        res = await nodeStaking.verifyStateRoot("0x0000000000000000000000000000000000000000000000000000000000000000","0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xecd60d0964cddddba478aa5d06d166d17417e16d9edb3c82bb5d343fde48c16f");
        console.log(res == false);
    } catch(error) {
    }
    // valid state root
    try {
        res = await nodeStaking.verifyStateRoot("0xad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3","0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xecd60d0964cddddba478aa5d06d166d17417e16d9edb3c82bb5d343fde48c16f");
        console.log(true);
    } catch(error) {
        console.log("false");
    }
    return true;
}

async function testVerifyBlockNumber(LGRCommittee) {
    console.log('testVerifyBlockNumber');
    // invalid block hash
    try {
        res = await LGRCommittee.verifyBlockNumber(33,"0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3",22062);
    } catch(error) {
        console.log(true);
    }
    // invalid block number
    try {
        res = await LGRCommittee.verifyBlockNumber(32,"0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xecd60d0964cddddba478aa5d06d166d17417e16d9edb3c82bb5d343fde48c16f",22062);
        console.log(res == false);
    } catch(error) {
    }
    // valid block number
    try {
        res = await LGRCommittee.verifyBlockNumber(33,"0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xecd60d0964cddddba478aa5d06d166d17417e16d9edb3c82bb5d343fde48c16f",22062);
        console.log(true);
    } catch(error) {
        console.log("false");
    }
    return true;
}

async function delay(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

async function testInitCommittee(lgrc) {
    console.log('testInitCommittee');

    const provider = await getProvider();

    extChainID = await Math.ceil(Math.random() * 1000000);
    extDuration = 5;
    await lgrc.initCommittee(extChainID, extDuration);
    await delay(1000);

    cs = await lgrc.COMMITTEE_START(extChainID);
    cd = await lgrc.COMMITTEE_DURATION(extChainID);
    en = await lgrc.EpochNumber(extChainID);

    const blockNumber = await provider.getBlockNumber();
    csEquiv = cs.toNumber() == blockNumber;
    cdEquiv = cd.toNumber() == 5;
    enEquiv = en.toNumber() == 0;
    console.log(csEquiv);
    console.log(cdEquiv);
    console.log(enEquiv);
    if(csEquiv && cdEquiv && enEquiv) {
      return extChainID;
    } else {
      return false;
    }
}
/*
async function testRotateCommittee(lgrc) {
    console.log('testRotateCommittee');
    await lgrc.on("InitCommittee",(chainID,duration,evt) => {
        chainID = chainID.toNumber();
        duration = duration.toNumber();
        console.log(chainID,extChainID,duration, extDuration);
        chainIDMatch = extChainID == chainID;
        durationMatch = extDuration == duration;
        console.log(chainIDMatch);
        console.log(durationMatch);
    });
    await delay(1000);
//    lgrc.on("RotateCommittee",(from, to, value, event) => {
//        console.log(event);
//    });
    return false;
}
*/

async function testCommitteeAdd(lgrc,cChainID) {
    console.log('testCommitteeAdd');
    // Generate BLS public key for submission to committee
    blsKey = await genBLSKey();
    pub = blsKey.getPublicKey();
    // Add committee leaf
    lgrc.committeeAdd(cChainID,32,pub.serialize());
    await delay(1000);

    pass = true;

    // Verify initial committee roots
    r0 = await lgrc.CommitteeRoot(cChainID,0);
    r1 = await lgrc.CommitteeRoot(cChainID,1);
    r2 = await lgrc.CommitteeRoot(cChainID,2);
    r3 = await lgrc.CommitteeRoot(cChainID,3);
    
    results = [
        r0.toNumber() == 0,
        r1.toNumber() == 0,
        r2.toNumber() == 0,
        r3.gt(0)
    ];
    
    for(i = 0; i < results.length; i++) {
        console.log(results[i]);
        if(!results[i]) pass = false;
    }
    
    return pass;
}
async function testCommitteeRotate(lgrc,cChainID) {
    console.log('testCommitteeRotate');
    provider = await getProvider();

    // Setup Burn Transactions

    ecdsapk = "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
    const wallet = new ethers.Wallet(ecdsapk);

    const publicKey = wallet.publicKey;
    const address = wallet.address;
    
    signer = await provider.getSigner();

    pass = true;
    
    txn = { to: address, value: ethers.utils.parseEther('0.0').toHexString(), gasPrice: ethers.utils.parseUnits('1', 'gwei').toHexString() };
    
    // Rotate Committee Roots
    for(i = 0; i < 100; i++) {
        try {
            await lgrc.rotateCommittee(cChainID);
            console.log(false);
        } catch(error) {
            console.log(true);
            res = await provider.sendTransaction(txn);
            await res.wait();
        }
    }
    return pass;
}
async function main() {    
    const redeploy = process.argv.includes('--redeploy');
    const nodeStaking = await getNodeStaking(redeploy);
    const lgrc = await getLagrangeCommittee(nodeStaking);
    
//    console.log(await testVerifyStateRoot(nodeStaking));
    console.log(await testVerifyBlockNumber(lgrc));
    cChainID = await testInitCommittee(lgrc);
    console.log(cChainID != false);
//    console.log("Committee Chain ID:",cChainID);
    console.log(await testCommitteeAdd(lgrc,cChainID));
    console.log(await testCommitteeRotate(lgrc,cChainID));
//    console.log(await testDefaultFreeze(nodeStaking));
//    console.log(await testAddStakeIdent(nodeStaking));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

