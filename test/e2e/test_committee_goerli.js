const ethers = require('ethers');

const accounts = require('../../config/accounts.json');
const abi = require('../../out/LagrangeCommittee.sol/LagrangeCommittee.json').abi;
const serviceABI = require('../../out/LagrangeService.sol/LagrangeService.json').abi;

const deployedAddresses = require('../../script/output/deployed_goerli.json');
require('dotenv').config();

const address = "0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9"
const privKey = accounts[address];
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(privKey, provider);
const contract = new ethers.Contract(deployedAddresses.lagrange.addresses.lagrangeCommittee, abi, wallet);
const service = new ethers.Contract(deployedAddresses.lagrange.addresses.lagrangeService, serviceABI, wallet);

const arbChainID = 421613;
const optChainID = 420;


contract.getEpochNumber(arbChainID, 9372848).then((epoch) => {
    console.log("Arb epoch: ", epoch);
});


contract.getEpochNumber(optChainID, 9372848).then((epoch) => {
    console.log("Opt epoch: ", epoch);
});

contract.isUpdatable(2, arbChainID).then((updatable) => {
    console.log("Arb updatable: ", updatable);
});

contract.isUpdatable(3, arbChainID).then((updatable) => {
    console.log("Arb updatable: ", updatable);
});

contract.updatedEpoch(arbChainID).then((epoch) => {
    console.log("Arb updated epoch: ", epoch);
});