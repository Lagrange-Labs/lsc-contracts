/* eslint-disable no-await-in-loop */

const ethers = require('ethers');
const fs = require('fs');
const { bn254 } = require('@noble/curves/bn254');
const { config } = require('dotenv');
require('dotenv').config();

const DEFAULT_MNEMONIC =
  'exchange holiday girl alone head gift unfair resist void voice people tobacco';
const DEFAULT_NUM_ACCOUNTS = 10;

function genBLSKey(i) {
  const privateKey = BigInt(1234567890 + i + 1);
  const publicKey = bn254.getPublicKey(privateKey, false);
  return [
    privateKey.toString(16).padStart(64, '0'),
    Buffer.from(publicKey.slice(1)).toString('hex'),
  ];
}

async function main() {
  const accounts = {};
  const blsPairs = {};

  for (let i = 0; i < DEFAULT_NUM_ACCOUNTS; i++) {
    const pathWallet = `m/44'/60'/0'/0/${i}`;
    const accountWallet = ethers.Wallet.fromMnemonic(
      DEFAULT_MNEMONIC,
      pathWallet,
    );
    accounts[accountWallet.address] = accountWallet.privateKey;

    blsKey = await genBLSKey(i);
    console.log(blsKey);

    blsPairs[accountWallet.address] = {
      priv: '0x' + blsKey[0],
      pub: '0x' + blsKey[1],
    };
  }

  try {
    const config = require('../config/LagrangeService.json');
    operators = [];

    op = [];
    bpubk = [];
    bprivk = [];
    ecdsaprivk = [];

    await Object.entries(accounts).forEach(([k, v]) => {
      op.push(k);
      ecdsaprivk.push(v);
      bpubk.push(blsPairs[k].pub);
      bprivk.push(blsPairs[k].priv);
    });

    for (i = 0; i < config.chains.length; i++) {
      operator = {};
      operator.chain_name = config.chains[i].chain_name;
      operator.chain_id = config.chains[i].chain_id;
      operator.operators = op;
      operator.ecdsa_priv_keys = ecdsaprivk;
      operator.bls_pub_keys = bpubk;
      operator.bls_priv_keys = bprivk;
      operators.push(operator);
    }

    await fs.promises.writeFile(
      './config/operators.json',
      JSON.stringify(operators, null, 2),
    );
    console.log(
      `Operators saved to ./config/operators.json\n${JSON.stringify(
        operators,
        null,
        2,
      )}`,
    );
  } catch (err) {
    console.error('Error writing to file:', err);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
