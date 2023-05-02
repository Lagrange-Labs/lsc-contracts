/* eslint-disable no-await-in-loop */

const ethers = require('ethers');

const DEFAULT_MNEMONIC = 'exchange holiday girl alone head gift unfair resist void voice people tobacco';
const DEFAULT_NUM_ACCOUNTS = 20;

async function main() {
    const currentProvider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
    const signerNode = await currentProvider.getSigner();

    for (let i = 0; i < DEFAULT_NUM_ACCOUNTS; i++) {
        const pathWallet = `m/44'/60'/0'/0/${i}`;
        const accountWallet = ethers.Wallet.fromMnemonic(DEFAULT_MNEMONIC, pathWallet);
        console.log(`Account ${i}: ${accountWallet.address}`);
        console.log(`Private key: ${accountWallet.privateKey}`);
        const params = [{
            from: await signerNode.getAddress(),
            to: accountWallet.address,
            value: '0x3635C9ADC5DEA00000',
        }];
        const tx = await currentProvider.send('eth_sendTransaction', params);
        if (i === DEFAULT_NUM_ACCOUNTS - 1) {
            await currentProvider.waitForTransaction(tx);
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });