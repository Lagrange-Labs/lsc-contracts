const { exec } = require('child_process');
const fs = require('fs');
require('dotenv').config();

const accountsPath = './config/accounts.json';

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

fs.readFile(accountsPath, 'utf8', (err, data) => {
  if (err) {
    console.error('Error reading file:', err);
    return;
  }

  try {
    const accounts = JSON.parse(data);
    const addresses = Object.keys(accounts);
    const batch_size = 10;
    (async () => {
      for (let i = 0; i < addresses.length; i += batch_size) {
        const batch = addresses.slice(i, i + batch_size);

        const exec_batch = batch.map((address) => {
          const command = `forge script script/localnet/Deposit_Stake.s.sol:DepositStake --rpc-url ${rpcURL} --private-key ${accounts[address]} --broadcast -vvvvv`;
          console.log(`Starting to deposit stake for address: ${address}`);
          return executeCommand(command);
        });
        await Promise.all(exec_batch);
      }
    })()
      .then(() => {
        console.log('All done!');
      })
      .catch((err) => {
        console.error('Error:', err);
      });
  } catch (err) {
    console.error('Error parsing JSON string:', err);
  }
});
