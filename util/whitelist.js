const Web3 = require('web3');
require('dotenv').config();

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RPC_URL = process.env.RPC_URL;

const web3 = new Web3(RPC_URL);
const abi = [
  {
    inputs: [
      {
        internalType: 'address[]',
        name: 'operators',
        type: 'address[]',
      },
    ],
    name: 'addOperatorsToWhitelist',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
];

// configure these values
const operators = ['0xadFDa3A18402D54534A4C8Ef8648C4732CEeAB53'];
const deployedAddresses = require('../script/output/deployed_lgr.json');

const contract = new web3.eth.Contract(abi, deployedAddresses.addresses.lagrangeService);

(async () => {
  try {
    const tx = await contract.methods.addOperatorsToWhitelist(operators);
    const signedTx = await web3.eth.accounts.signTransaction(
      { to: contractAddress, data: tx.encodeABI(), gas: 2000000 },
      PRIVATE_KEY,
    );
    const receipt = await web3.eth.sendSignedTransaction(
      signedTx.rawTransaction,
    );
    console.log(receipt);
  } catch (error) {
    console.log(error);
  }
})();
