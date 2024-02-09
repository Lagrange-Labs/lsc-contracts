const { exec } = require('child_process');
const ethers = require('ethers');
require('dotenv').config();

const operators = require('../config/operators.json');

const rpcURL = process.env.RPC_URL;

function executeCommand(command) {
  return new Promise((resolve, reject) => {
    exec(command, (error, stdout, stderr) => {
      if (error) {
        reject(error);
      } else if (stderr) {
        resolve(stderr);
      } else {
        resolve(stdout);
      }
    });
  });
}

const addresses = operators[0].operators;
const privateKeys = operators[0].ecdsa_priv_keys;
const batch_size = 10;

(async () => {
  for (let i = 0; i < addresses.length; i += batch_size) {
    const batch = addresses.slice(i, i + batch_size);
    const exec_batch = batch.map((address, index) => {
      const command = `forge script script/localnet/Deposit_Stake.s.sol:DepositStake --rpc-url ${rpcURL} --private-key ${privateKeys[i + index]
        } --broadcast -vvvvv`;
      console.log(`Starting to deposit stake for address: ${address}`);
      return executeCommand(command);
    });
    await Promise.all(exec_batch);
  }
})()
  .then(() => {
    console.log('Staking done!');
  })
  .catch((err) => {
    console.error('Staking Error:', err);
  });


// const deployedAddresses = require('../script/output/deployed_lgr.json');
// const abi = require('../out/LagrangeService.sol/LagrangeService.json').abi;

// (async () => {
//   const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
//   const owallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
//   const ocontract = new ethers.Contract(
//     deployedAddresses.addresses.lagrangeService,
//     abi,
//     owallet,
//   );

//   const tx = await ocontract.addOperatorsToWhitelist(operators[0].operators);
//   console.log(
//     `Starting to add operator to whitelist for address: ${operators[0].operators} tx hash: ${tx.hash}`,
//   );
//   const receipt = await tx.wait();
//   console.log(
//     `Add Operator Transaction was mined in block ${receipt.blockNumber} gas consumed: ${receipt.gasUsed}`,
//   );
// })().then(() => {
//   console.log('WhiteListing done!');
// }).catch((err) => {
//   console.error('WhiteListing Error:', err);
// });