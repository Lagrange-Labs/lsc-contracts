const ethers = require('ethers');
const fs = require('fs');
const bls = require('@noble/bls12-381');
require('dotenv').config();

const accounts = require('../config/accounts.json');
const abi = require('../out/LagrangeService.sol/LagrangeService.json').abi;
const deployedAddresses = require('../script/output/deployed_lgr.json');

const slasherABI = require('../out/Slasher.sol/Slasher.json').abi;
const eigenDeployedAddresses =
  require('../script/output/M1_deployment_data.json').addresses;

const operatorsData = require('../config/operators.json');

const chain = operatorsData[0];

chain.operators.forEach((address, index) => {
  const privKey = chain.ecdsa_priv_keys[index];
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(privKey, provider);

  // call optIntoSlashing on slasher
  const slasher = new ethers.Contract(
    eigenDeployedAddresses.slasher,
    slasherABI,
    wallet,
  );
  slasher
    .optIntoSlashing(deployedAddresses.addresses.lagrangeServiceManager)
    .then((tx) => {
      console.log('Starting to opt into slashing for address: ', address);
      console.log(`Transaction hash: ${tx.hash}`);
      tx.wait().then((receipt) => {
        console.log(`Transaction was mined in block ${receipt.blockNumber}`);
      });
    });
});
