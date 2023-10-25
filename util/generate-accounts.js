/* eslint-disable no-await-in-loop */

const ethers = require('ethers');
const fs = require('fs');
const bls = require('bls-eth-wasm');
require('dotenv').config();

const DEFAULT_MNEMONIC =
  'exchange holiday girl alone head gift unfair resist void voice people tobacco';
const DEFAULT_NUM_ACCOUNTS = 150;

async function genBLSKey() {
  await bls.init(bls.BLS12_381);
  blsKey = new bls.SecretKey();
  await blsKey.setByCSPRNG();
  return blsKey;
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

    blsPair = await genBLSKey();
    pub = await blsPair.getPublicKey();
    blsPairs[accountWallet.address] = {
      pub: '0x' + (await pub.serializeToHexStr()),
      priv: '0x' + (await blsPair.serializeToHexStr()),
    };
  }

  try {
    await fs.promises.writeFile(
      './config/accounts.json',
      JSON.stringify(accounts, null, 2),
    );
    console.log(
      `Accounts saved to ./config/accounts.json\n${JSON.stringify(
        accounts,
        null,
        2,
      )}`,
    );
  } catch (err) {
    console.error('Error writing to file:', err);
  }

  try {
    operators = await require('../config/operators.json');

    op = [];
    bpk = [];

    await Object.entries(accounts).forEach(([k, v]) => {
      op.push(k);
      bpk.push(blsPairs[k].pub);
    });

    for (i = 0; i < operators.length; i++) {
      chain = operators[i];
      operators[i].operators = op;
      operators[i].bls_pub_keys = bpk;
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
