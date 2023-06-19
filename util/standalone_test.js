const chai = require('chai');
const assert = require('assert');
const exec = require('child_process');
const ethers = require("ethers");
//const { JsonRpcProvider } = require('ethers/providers');
const fs = require('fs')
const bls = require("bls-eth-wasm");
const path = require("path");
//const utils = require('utils');

async function testDefaultFreeze(lagrangeService) {
    console.log("testDefaultFreeze");
    frozenStatus = await lagrangeService.getFrozenStatus("0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9");
    freezeException = false;
    try {
        await lagrangeService.freezeOperator("0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9");
    } catch(error) {
	freezeException = true;
    }
    return freezeException && !frozenStatus;
}

async function getProvider() {
    const currentProvider = new ethers.providers.JsonRpcProvider('http://0.0.0.0:8545');
    return currentProvider;
}
async function getSigner() {
    const currentProvider = await getProvider();
    ecdsapk = "3e17bc938ec10c865fc4e2d049902716dc0712b5b0e688b7183c16807234a84c";
    const wallet = new ethers.Wallet(ecdsapk, currentProvider);
    return wallet;
}

async function getLagrangeCommittee(lagrangeService) {
    const currentProvider = await getProvider();
    const signerNode = await getSigner();
    
    const lgrcAddr = await lagrangeService.LGRCommittee();
    const lgrcABI = await fs.readFileSync(path.join(__dirname,"../out/LagrangeCommittee.sol/LagrangeCommittee.json"),"utf-8");
    jsonABI = await JSON.parse(lgrcABI);
    sanitizedABI = await JSON.stringify(jsonABI);
    const lgrc = new ethers.Contract(lgrcAddr,jsonABI.abi,signerNode);
    return lgrc;
}

async function getWETH9() {
    const currentProvider = await getProvider();
    const signerNode = await getSigner();
	deployFile = await fs.readFileSync(path.join(__dirname,"../broadcast/DeployWETH9.s.sol/1337/run-latest.json"));
	deployJson = await JSON.parse(deployFile);
	deployTxns = deployJson.transactions;
        w9Addr = null;
	for(i = 0; i < deployTxns.length; i++) {
	    if(deployTxns[i].contractName == "WETH9") {
		w9Addr = deployTxns[i].contractAddress;
	    }
	}
	const w9ABI = await fs.readFileSync(path.join(__dirname,"../out/WETH9.sol/WETH9.json"),"utf-8");
	jsonABI = await JSON.parse(w9ABI);
	sanitizedABI = await JSON.stringify(jsonABI.abi);
        const w9Contract = new ethers.Contract(w9Addr,sanitizedABI,signerNode);
	console.log("w9Addr",w9Addr);
	return w9Contract;
}

async function getLagrangeService(redeploy) {
    const currentProvider = await getProvider();
    const signerNode = await getSigner();
    
    if(redeploy) {
	console.log("Redeploying...");
	await exec.execSync("rm -rf ./deployments/privnet/");
	const options = { encoding: 'utf-8' }; // Set the encoding for the output
//	await exec.execSync("npx compile --force", options);
	const deploy = await exec.execSync("npx hardhat deploy --network privnet", options);
	console.log("Redeploying complete.");
	
	nsAddr = null;
	for(i = 0; i < deployTxns.length; i++) {
	    if(deployTxns[i].contractName == "LagrangeService") {
		nsAddr = deployTxns[i].contractAddress;
	    }
	}

	const nsABI = await fs.readFileSync(path.join(__dirname,"../out/LagrangeService.sol/LagrangeService.json"),"utf-8");

	console.log("LagrangeService Address:", nsAddr);
    
        jsonABI = await JSON.parse(nsABI);
        sanitizedABI = await JSON.stringify(jsonABI);
	
        const lagrangeService = new ethers.Contract(nsAddr,sanitizedABI,signerNode);

	console.log("Slasher Address:", lagrangeService.eslasher);
	return lagrangeService;
    } else {
	deployFile = await fs.readFileSync(path.join(__dirname,"../broadcast/Deploy.s.sol/1337/run-latest.json"));
	deployJson = await JSON.parse(deployFile);
	deployTxns = deployJson.transactions;
	nsAddr = null;
	for(i = 0; i < deployTxns.length; i++) {
	    if(deployTxns[i].contractName == "LagrangeService") {
		nsAddr = deployTxns[i].contractAddress;
	    }
	}
	const nsABI = await fs.readFileSync(path.join(__dirname,"../out/LagrangeService.sol/LagrangeService.json"),"utf-8");
	jsonABI = await JSON.parse(nsABI);
	sanitizedABI = await JSON.stringify(jsonABI.abi);

        const lagrangeService = new ethers.Contract(nsAddr,sanitizedABI,signerNode);
        console.log("LagrangeService loaded.");
        
	return lagrangeService;
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

    ecdsapk = "3e17bc938ec10c865fc4e2d049902716dc0712b5b0e688b7183c16807234a84c";
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
    // calculate block hash
    blockHash = await nodeStaking.calculateBlockHash("0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a");
    assert.equal(blockHash, "0xecd60d0964cddddba478aa5d06d166d17417e16d9edb3c82bb5d343fde48c16f");
    // invalid block hash
    try {
        res = await nodeStaking.verifyStateRoot("0x0000000000000000000000000000000000000000000000000000000000000000","0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3");
        assert.fail();
    } catch(error) {
    }
    // invalid state root
    try {
        res = await nodeStaking.verifyStateRoot("0x0000000000000000000000000000000000000000000000000000000000000000","0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xecd60d0964cddddba478aa5d06d166d17417e16d9edb3c82bb5d343fde48c16f");
        assert.equal(res, false);
    } catch(error) {
    }
    // valid state root
    try {
        res = await nodeStaking.verifyStateRoot("0xad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3","0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xecd60d0964cddddba478aa5d06d166d17417e16d9edb3c82bb5d343fde48c16f");
    } catch(error) {
        assert.fail();
    }
    return true;
}

async function delay(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

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
    // Generate BLS public key for submission to committee
    blsKey = await genBLSKey();
    pub = blsKey.getPublicKey();
    // Add committee leaf
    lgrc.committeeAdd(cChainID,32,pub.serialize());
    await delay(3000);
    // Only occurs organically during rotation, must be manually triggered for testing
    flux = await lgrc.getNext1CommitteeRoot(cChainID);
    await delay(3000);

    pass = true;

    // Verify initial committee roots
    r0 = await lgrc.CommitteeRoot(cChainID,0);
    r1 = await lgrc.CommitteeRoot(cChainID,1);
    r2 = await lgrc.CommitteeRoot(cChainID,2);
    console.log(r0.toHexString());
    
    results = [
        r0.toHexString() == "0x00",
        r1.toHexString() == "0x00",
        r2.toHexString() == "0x00",
        flux.toHexString() != "0x00",
    ];
    
    for(i = 0; i < results.length; i++) {
        console.log(results[i]);
        if(!results[i]) pass = false;
    }
    
    return pass;
}
async function testCommitteeRotate(lgrc,cChainID) {
    console.log('testCommitteeRotate');
/*
    provider = await getProvider();

    // Setup Burn Transactions
    ecdsapk = "3e17bc938ec10c865fc4e2d049902716dc0712b5b0e688b7183c16807234a84c";
    const wallet = new ethers.Wallet(ecdsapk);

    const publicKey = wallet.publicKey;
    const address = wallet.address;
    
    signer = await provider.getSigner();

    pass = true;
    
    txn = { to: address, value: ethers.utils.parseEther('0.0').toHexString(), gasPrice: ethers.utils.parseUnits('1', 'gwei').toHexString() };
*/
    
    // Rotate Committee Roots
    for(i = 0; i < 100; i++) {
        try {
            await lgrc.rotateCommittee(cChainID);
            console.log(false);
	    await delay(3000);
        } catch(error) {
            console.log(true);
            console.log(error);
	    await delay(3000);
            //res = await provider.sendTransaction(txn);
            //await res.wait();
        }
    }
    return pass;
}

/*
describe('debug', async function() {
 describe('t', async function() {
   it('c', async function() {});
 });
});
*/
async function getStrategyManager(lagrangeService) {
    const currentProvider = await getProvider();
    const signerNode = await getSigner();
	smAddr = await lagrangeService.StrategyMgr();
	const smABI = await fs.readFileSync(path.join(__dirname,"../out/IStrategyManager.sol/IStrategyManager.json"),"utf-8");
	jsonABI = await JSON.parse(smABI);
	sanitizedABI = await JSON.stringify(jsonABI.abi);
	const smContract = new ethers.Contract(smAddr,sanitizedABI,signerNode);
	return smContract;
}
async function getWETHStrategy(lagrangeService) {
    const currentProvider = await getProvider();
    const signerNode = await getSigner();
        wsAddr = await lagrangeService.WETHStrategy();
	const wsABI = await fs.readFileSync(path.join(__dirname,"../out/IStrategy.sol/IStrategy.json"),"utf-8");
	jsonABI = await JSON.parse(wsABI);
	sanitizedABI = await JSON.stringify(jsonABI.abi);
        const wsContract = new ethers.Contract(wsAddr,sanitizedABI,signerNode);
        return wsContract;
}
describe('Lagrange Service Smoke Tests', async function() {
    const redeploy = process.argv.includes('--redeploy');
    const lagrangeService = await getLagrangeService(redeploy);
    const provider = await getProvider();
/*
    describe('Diagnostics', async function() {
        it('StrategyManager check', async function() {
            smAddr = await lagrangeService.StrategyMgr();
            assert.ok(smAddr.length == 42);
        });
        w9Contract = await getWETH9();
        it('WETH9 mock contract check', function() {
            assert.ok(w9Contract.address.length == 42);
        });
        it('WETH Strategy check', async function() {
            wethStrategy = await lagrangeService.WETHStrategy();
            assert.ok(wethStrategy.length == 42);
        });
        it('WETH9 Approval', async function() {
            let amount = ethers.utils.parseUnits("32", 18);
            smContract = await getStrategyManager(lagrangeService);
            assert.ok(smContract.address.length == 42);
            wsContract = await getWETHStrategy(lagrangeService);
            assert.ok(wsContract.address.length == 42);
            this.timeout(30000);

            let zerolimit = await ethers.utils.parseUnits("0.0", 18);
            let limit = await ethers.utils.parseUnits("33000.0", 18);
	    const signerNode = await getSigner();

            tx = await w9Contract.deposit({value:amount});
            w = await tx.wait();
            tx = await w9Contract.approve(wsContract.address,limit);
            w = await tx.wait();
            tx = await w9Contract.approve(signerNode.address,limit);
            w = await tx.wait();
            tx = await w9Contract.approve(w9Contract.address,limit);
            w = await tx.wait();
            tx = await w9Contract.approve(smContract.address,limit);
            w = await tx.wait();

            let gasLimitValue = 30000000;
            //console.log([wsContract.address,w9Contract.address,amount,{gasLimit:gasLimitValue}]);
            tx = await smContract.depositIntoStrategy(wsContract.address,w9Contract.address,amount,{gasLimit:gasLimitValue});
            w = await tx.wait();
//            console.log(await smContract.getDeposits("0xb2AaA94B0dbc3Af219B5abD7a141d0F66d55fB82"));
  //          console.log(await smContract.getDeposits("0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9"));
        });
    });
*/
    describe('Lagrange Service Contract', function() {
        it('LGRCommittee address associated', async function() {
            lc = await lagrangeService.LGRCommittee();
            assert.ok(lc.length > 0);
        });
        it('LGRServiceManager address associated', async function() {
            lsm = await lagrangeService.LGRServiceMgr();
            assert.ok(lsm.length > 0);
        });
        it('Lagrange Service Owner', async function() {
            const owner = await lagrangeService.owner();
            assert.equal(owner, "0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9");
        });
        it('Lagrange Service Strategy Manager', async function() {
            const addr = await lagrangeService.StrategyMgr();
            assert.ok(addr.length > 4);
        });
    });
    const lgrc = await getLagrangeCommittee(lagrangeService);
    
    describe('Lagrange Committee Smoke Tests', async function() {
            it('Poseidon Profile Tests', async function() {
              h0 = await lgrc.hash1Elements(0);
              console.log(h0.toString());
              h1 = await lgrc.hash1Elements(1);
              console.log(h1.toString());
              hh0 = await lgrc.hash1Elements(h0);
              console.log(hh0.toString());
            });
    });
term();

    describe('Lagrange Committee Smoke Tests', async function() {
        it('Poseidon Hash Wrapper', async function() {
            hash = await lgrc.hash2Elements(1,2);
            assert.equal(hash.toString(),"7853200120776062878684798364095072458815029376092732009249414926327459813530");
        });
        it('Lagrange Committee Owner', async function() {
            const owner = await lgrc.owner();
            assert.equal(owner, "0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9");
        });
    });

    describe('Lagrange Committee Block Verification', async function() {
        it('Verify Block Header (Invalid Block Hash)', async function() {
          try {
              await lgrc.verifyBlockNumber(33,"0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3",22062);
              assert.fail();
          } catch (error) {
          }
        });
        it('Verify Block Header (Invalid Block Number)', async function() {
          try {
              res = await lgrc.verifyBlockNumber(32,"0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xecd60d0964cddddba478aa5d06d166d17417e16d9edb3c82bb5d343fde48c16f",22062);
              assert.equal(res,false);
          } catch (error) {
          }
        });
        it('Verify Block Header (Valid Block Number)', async function() {
          try {
              res = await lgrc.verifyBlockNumber(33,"0xf9025fa01720898ba6aaccc2ed9780843286151172f10149ecad6b89407d23edcd6727ffa01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0ad683f1c4d79ea6298b09b31892b4de88416454013c54d405f2d9dcade2bf2a3a0517785f3ba91b4a7fdee87ca2f6d3d2f153a179e45cd9db3eade3b611c8b22d8a0741e015c72ad7dc3caf0c5db58f17c6068dd5a002a7dd4e5f0a29a9acdb0f87bb901000000000000000000000000000000000040000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000200000100000000040000000000000000000000000002000000000000010000080000000080000000000000000000000040000000000000000000000000000000000000000000008000000000000080000000000000008000000000000000040000000000000000002000000000000000000000012000000020000000000004000000000000240000000000000000002000000000000000000001000000000000000000000000000000000000000000000002218401bb3d8f830d1eca84645ce923b861d883010b00846765746888676f312e31392e32856c696e7578000000000000008d10b98fd3dc1d3ba76285b0c9c9e6e9d4eb3105499c7f8e926a09d2e44a7cc94120c0e804711da820f4e88e15c69d6fc8b5ba4bbc3ae127d1d9826f82dce6f200a000000000000000000000000000000000000000000000000000000000000000008800000000000000008403945c3a","0xecd60d0964cddddba478aa5d06d166d17417e16d9edb3c82bb5d343fde48c16f",22062);
              assert.equal(res,true);
          } catch (error) {
              assert.fail();
          }
        });
    });

    const extChainID = await Math.ceil(Math.random() * 1000000);
    const extDuration = 5;
    const freezeDuration = 2048;
    describe('Lagrange Committee', async function() {
        it('Initialize Committee', async function() {
            this.timeout(5000);
            tx = await lgrc.initCommittee(extChainID, extDuration, freezeDuration);
            rec = await tx.wait();
            cs = await lgrc.getCommitteeStart(extChainID);
            cd = await lgrc.getCommitteeDuration(extChainID);
            en = await lgrc.getCurrentEpoch(extChainID);
            const blockNumber = await provider.getBlockNumber();
            assert.ok(cs.toNumber() <= blockNumber);
            assert.ok(cs.toNumber() > 0);
            assert.ok(cdEquiv = cd.toNumber() == 5);
            assert.ok(en.toNumber() == 0);
            // TODO account for refactoring and related variable changes here and elsewhere
        });
        it('Lagrange Service Operator Registration', async function() {
            this.timeout(5000);
            const blockNumber = await provider.getBlockNumber();
            const amount = ethers.utils.parseUnits("1", 18);
            blsKey = await genBLSKey();
            priv = blsKey.serializeToHexStr();
            pub = blsKey.getPublicKey();
            tx = await lagrangeService.register(extChainID, amount, pub.serialize(), blockNumber + 10);
            res = await tx.wait();
            console.log(res);
        });
    });
});

/*
async function main() {

//    console.log(await testVerifyStateRoot(lagrangeService));
//    console.log("Committee Chain ID:",cChainID);
    assert.ok(await testCommitteeAdd(lgrc,cChainID), "testCommitteeAdd");
    assert.ok(await testCommitteeRotate(lgrc,cChainID), "testCommitteeRotate");
//    console.log(await testDefaultFreeze(lagrangeService));
//    console.log(await testAddStakeIdent(lagrangeService));
}
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
*/

