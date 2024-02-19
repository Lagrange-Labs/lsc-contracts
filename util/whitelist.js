const Web3 = require("web3");
require('dotenv').config();

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RPC_URL = process.env.RPC_URL;

const web3 = new Web3(RPC_URL);
const abi = [{
    inputs: [
        {
            internalType: "address[]",
            name: "operators",
            type: "address[]"
        }
    ],
    name: "addOperatorsToWhitelist",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
}];

// configure these values
const operators = ['0x7627e924F5e74aeeE246E701cd23F5B038b3c5cD', '0x032145C977D623B34DD8702c44484b693013f885'];
const contractAddress = '0x8cbFb6310b10CD0510cDA02c7419fc7d8F162b48';

const contract = new web3.eth.Contract(abi, contractAddress);

(async () => {
    try {
        const tx = await contract.methods.addOperatorsToWhitelist(operators);
        const signedTx = await web3.eth.accounts.signTransaction({ to: contractAddress, data: tx.encodeABI(), gas: 2000000 }, PRIVATE_KEY);
        const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
        console.log(receipt);
    } catch (error) {
        console.log(error);
    }
})();

