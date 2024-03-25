const { exec } = require('child_process');
require('dotenv').config();

const operatorData = require('../config/random_operator.json');

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

(async () => {
  const operator = operatorData.operator;
  console.log(
    `Starting to deposit stake for address: ${operator.operator_address}`,
  );
  const register_command = `forge script script/localnet/RegisterOperator.s.sol:RegisterOperator --rpc-url ${rpcURL} --private-key ${operator.ecdsa_private_key} --broadcast -vvvvv`;

  await executeCommand(register_command);

  const subscribe_command = `forge script script/localnet/SubscribeOperator.s.sol:SubscribeOperator --rpc-url ${rpcURL} --private-key ${operator.ecdsa_private_key} --broadcast -vvvvv`;

  await executeCommand(subscribe_command);
})()
  .then(() => {
    console.log('All done!');
  })
  .catch((err) => {
    console.error('Error:', err);
  });
