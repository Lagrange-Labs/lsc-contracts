const ethers = require('ethers');
const bls = require('@noble/bls12-381');
require('dotenv').config();

const accounts = require('../config/accounts.json');
const abi = require('../out/LagrangeService.sol/LagrangeService.json').abi;
const deployedAddresses = require('../script/output/deployed_lgr.json');

const operators = require('../config/operators.json');
const uint32Max = 4294967295;

const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);


const convertBLSPubKey = (oldPubKey) => {
    const pubKey = bls.PointG1.fromHex(oldPubKey.slice(2));
    const Gx = pubKey.toAffine()[0].value.toString(16).padStart(96, '0');
    const Gy = pubKey.toAffine()[1].value.toString(16).padStart(96, '0');
    const newPubKey = "0x" + Gx + Gy;
    console.log("newPubKey: ", newPubKey);
    return newPubKey;
}

operators.forEach(async (chain) => {
    for (let index = 0; index < chain.operators.length; index++) {
        const address = chain.operators[index];
        const privKey = accounts[address];
        const wallet = new ethers.Wallet(privKey, provider);
        const contract = new ethers.Contract(deployedAddresses.addresses.lagrangeService, abi, wallet);
        const tx = await contract.register(chain.chain_id, convertBLSPubKey(chain.bls_pub_keys[index]), uint32Max)
        console.log(`Starting to register operator for address: ${address} tx hash: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`Transaction was mined in block ${receipt.blockNumber}`);
    }
});
