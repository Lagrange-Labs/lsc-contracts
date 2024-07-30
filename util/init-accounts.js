/* eslint-disable no-await-in-loop */

const ethers = require('ethers');
const fs = require('fs');
require('dotenv').config();

const DEFAULT_MNEMONIC =
  'exchange holiday girl alone head gift unfair resist void voice people tobacco';

const TESTNET_MODE = process.env.TESTNET_MODE;
const RPC_URL = process.env.RPC_URL;
let MNEMONIC = process.env.MNEMONIC;
const NUM_ACCOUNTS = parseInt(process.env.NUM_ACCOUNTS || '15');

if (!MNEMONIC) {
  MNEMONIC = DEFAULT_MNEMONIC;
}

async function main() {
  const currentProvider = new ethers.providers.JsonRpcProvider(RPC_URL);
  const signerNode = await currentProvider.getSigner();

  const accounts = {};

  for (let i = 0; i < NUM_ACCOUNTS; i++) {
    const pathWallet = `m/44'/60'/0'/0/${i}`;
    const accountWallet = ethers.Wallet.fromMnemonic(MNEMONIC, pathWallet);
    accounts[accountWallet.address] = accountWallet.privateKey;
    if (!TESTNET_MODE) {
      const params = [
        {
          from: await signerNode.getAddress(),
          to: accountWallet.address,
          value: '0x3635C9ADC5DEA00000',
        },
      ];
      const tx = await currentProvider.send('eth_sendTransaction', params);
      if (i === NUM_ACCOUNTS - 1) {
        await currentProvider.waitForTransaction(tx);
      }
    } else {
      const wallet = new ethers.Wallet(
        process.env.PRIVATE_KEY,
        currentProvider,
      );
      const rawTx = {
        to: accountWallet.address,
        value: '40000000000000000',
      };

      const tx = await wallet.sendTransaction(rawTx);
      if (i === NUM_ACCOUNTS - 1) {
        const receipt = await tx.wait();
      }
    }
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
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
