const ethers = require('ethers');
const fs = require('fs');
require('dotenv').config();
const operators = require('./operators.json');

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RPC_URL = process.env.RPC_URL;

const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

const amountToSend = ethers.utils.parseEther('0.5');
const smallAmountToSend = ethers.utils.parseEther('0.02');

distributeEthers = async () => {
  for (const chain of operators) {
    for (let i = 0; i < chain.operators.length; i++) {
      const operator = chain.operators[i];

      const rawTx = {
        to: operator,
        value: smallAmountToSend,
      };

      const tx = await wallet.sendTransaction(rawTx);
      const receipt = await tx.wait();
      console.log(tx, receipt);
    }
  }
};

distributeEthers();
