const ethers = require('ethers');
const fs = require('fs');

const accounts = require('./accounts.json');
const abi = require('../out/LagrangeService.sol/LagrangeService.json').abi;
const deployedAddresses = require('../script/output/deployed_lgr.json');

const slasherABI = require('../out/Slasher.sol/Slasher.json').abi;
const eigenDeployedAddresses = require('../script/output/M1_deployment_data.json').addresses;

const operatorsPath = './operators.json';
const uint32Max = 4294967295;

fs.readFile(operatorsPath, 'utf8', (err, data) => {
    if (err) {
        console.error('Error reading file:', err);
        return;
    }

    try {
        const chains = JSON.parse(data);
        chains.forEach((chain) => {
            chain.operators.forEach((address, index) => {
                const privKey = accounts[address];
                const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
                const wallet = new ethers.Wallet(privKey, provider);
                const contract = new ethers.Contract(deployedAddresses.addresses.lagrangeService, abi, wallet);

                // call optIntoSlashing on slasher
                const slasher = new ethers.Contract(eigenDeployedAddresses.slasher, slasherABI, wallet);
                slasher.optIntoSlashing(deployedAddresses.addresses.lagrangeServiceManager).then((tx) => {
                    console.log("Starting to opt into slashing for address: ", address);
                    console.log(`Transaction hash: ${tx.hash}`);
                    tx.wait().then((receipt) => {
                        console.log(`Transaction was mined in block ${receipt.blockNumber}`);

                        // call register on lagrange service
                        contract.register(chain.chain_id, chain.bls_pub_keys[index], uint32Max).then((tx) => {
                            console.log("Starting to register operator for address: ", address);
                            console.log(`Transaction hash: ${tx.hash}`);
                            tx.wait().then((receipt) => {
                                console.log(`Transaction was mined in block ${receipt.blockNumber}`);
                            });
                        });
                    });
                });
            });
        });
    } catch (err) {
        console.error('Error parsing JSON string:', err);
    }
});