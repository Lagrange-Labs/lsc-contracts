const ethers = require('ethers');
const fs = require('fs');
require('dotenv').config();

const accounts = require('./accounts.json');
const abi = require('../out/LagrangeService.sol/LagrangeService.json').abi;
const deployedAddresses = require('../script/output/deployed_lgr.json');

const operators = require('./operators.json');
const uint32Max = 4294967295;

operators.forEach(async (chain) => {
    for (let index = 0; index < chain.operators.length; index++) {
        const address = chain.operators[index];
        const privKey = accounts[address];
        const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
        const wallet = new ethers.Wallet(privKey, provider);
        const contract = new ethers.Contract(deployedAddresses.addresses.lagrangeService, abi, wallet);

        const tx = await contract.register(chain.chain_id, chain.bls_pub_keys[index], uint32Max);
        console.log(`Starting to register operator for address: ${address} tx hash: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`Transaction was mined in block ${receipt.blockNumber}`);
    }
});
