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

const operatorsPath = './config/operators.json';
const uint32Max = 4294967295;

const convertBLSPubKey = (oldPubKey) => {
  const pubKey = bls.PointG1.fromHex(oldPubKey.slice(2));
  const Gx = pubKey.toAffine()[0].value.toString(16).padStart(96, '0');
  const Gy = pubKey.toAffine()[1].value.toString(16).padStart(96, '0');
  const newPubKey = '0x' + Gx + Gy;
  console.log('newPubKey: ', newPubKey);
  return newPubKey;
};

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
        const provider = new ethers.providers.JsonRpcProvider(
          process.env.RPC_URL,
        );
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
              console.log(
                `Transaction was mined in block ${receipt.blockNumber}`,
              );
            });
          });
      });
    });
  } catch (err) {
    console.error('Error parsing JSON string:', err);
  }
});