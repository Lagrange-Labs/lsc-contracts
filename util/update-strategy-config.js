const eigenConfig = require('../script/localnet/M1_deploy.config.json');
const deployedWETH = require('../script/output/deployed_weth9.json');
const fs = require('fs');
const { ethers } = require('ethers');

require('dotenv').config();

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RPC_URL = process.env.RPC_URL;

const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

eigenConfig.multisig_addresses.communityMultisig = wallet.address;
eigenConfig.multisig_addresses.operationsMultisig = wallet.address;
eigenConfig.multisig_addresses.pauserMultisig = wallet.address;
eigenConfig.multisig_addresses.executorMultisig = wallet.address;

for (const strategy of eigenConfig.strategies) {
  if (strategy.token_symbol == 'WETH') {
    strategy.token_address = deployedWETH.WETH9;
  }
}

// Convert the JavaScript object back to a JSON string
const updatedJsonString = JSON.stringify(eigenConfig, null, 4);
const filePath = './script/localnet/M1_deploy.config.json';

// Write the updated JSON string back to the file
fs.writeFile(filePath, updatedJsonString, 'utf8', (err) => {
  if (err) {
    console.error('Error writing JSON file:', err);
    return;
  }

  console.log('JSON file updated successfully.');
});