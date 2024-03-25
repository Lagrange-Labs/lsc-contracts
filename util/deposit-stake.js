const { exec } = require("child_process");
const fs = require("fs");
require("dotenv").config();

const operators = require("../config/operators.json");

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
      const command = `forge script script/localnet/Deposit_Stake.s.sol:DepositStake --rpc-url ${rpcURL} --private-key ${
        privateKeys[i + index]
      } --broadcast -vvvvv`;
      console.log(`Starting to deposit stake for address: ${address}`);
      return executeCommand(command);
    });
    await Promise.all(exec_batch);
  }
})()
  .then(() => {
    console.log("All done!");
  })
  .catch((err) => {
    console.error("Error:", err);
  });
