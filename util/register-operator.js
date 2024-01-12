const { exec } = require('child_process');
const fs = require('fs');
require('dotenv').config();

const rpcURL = process.env.RPC_URL;

const operators = require('../config/operators.json');
const chain = operators[0];

chain.operators.forEach((address, index) => {
  console.log('Starting to register operator for address: ', address);
  const privKey = chain.ecdsa_priv_keys[index];
  const command = `forge script script/localnet/RegisterOperator.s.sol:RegisterOperator --rpc-url ${rpcURL} --private-key ${privKey} --broadcast -vvvvv`;
  exec(command, (error, stdout, stderr) => {
    console.log(`Command output: ${stdout}`);
    if (error) {
      console.error(`Error executing command: ${error.message}`);
      return;
    }

    if (stderr) {
      console.error(`Command stderr: ${stderr}`);
      return;
    }
  });
});
