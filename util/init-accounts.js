/* eslint-disable no-await-in-loop */

const ethers = require('ethers');
const fs = require('fs');
require('dotenv').config();

const DEFAULT_MNEMONIC =
  'exchange holiday girl alone head gift unfair resist void voice people tobacco';
const DEFAULT_NUM_ACCOUNTS = 20;

async function main() {
  const currentProvider = new ethers.providers.JsonRpcProvider(
    process.env.RPC_URL,
  );
  const signerNode = await currentProvider.getSigner();

  const accounts = {};

  for (let i = 0; i < DEFAULT_NUM_ACCOUNTS; i++) {
    const pathWallet = `m/44'/60'/0'/0/${i}`;
    const accountWallet = ethers.Wallet.fromMnemonic(
      DEFAULT_MNEMONIC,
      pathWallet,
    );
    accounts[accountWallet.address] = accountWallet.privateKey;
    const params = [
      {
        from: await signerNode.getAddress(),
        to: accountWallet.address,
        value: '0x3635C9ADC5DEA00000',
      },
    ];
    const tx = await currentProvider.send('eth_sendTransaction', params);
    if (i === DEFAULT_NUM_ACCOUNTS - 1) {
      await currentProvider.waitForTransaction(tx);
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
