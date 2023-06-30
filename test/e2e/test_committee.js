const ethers = require('ethers');

const accounts = require('../../config/accounts.json');
const abi = require('../../out/LagrangeCommittee.sol/LagrangeCommittee.json').abi;
const serviceABI = require('../../out/LagrangeService.sol/LagrangeService.json').abi;

const deployedAddresses = require('../../script/output/deployed_lgr.json');
require('dotenv').config();

const address = "0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9"
const privKey = accounts[address];
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(privKey, provider);
const contract = new ethers.Contract(deployedAddresses.addresses.lagrangeCommittee, abi, wallet);
const service = new ethers.Contract(deployedAddresses.addresses.lagrangeService, serviceABI, wallet);



provider.getNetwork().then((network) => {
    console.log("chainID: ", network.chainId);
});

service.weightOfOperator(address, 1).then((weight) => {
    console.log("Weight: ", weight);
});

const arbChainID = 1337;
const optChainID = 420;

contract.getCommittee(optChainID, 1000).then((current) => {
    console.log("Opt Current committee: ", current[0]);
    console.log("Opt Next committee: ", current[1]);
});


contract.getCommittee(arbChainID, 1000).then((current) => {
    console.log("Arb Current committee: ", current[0]);
    console.log("Arb Next committee: ", current[1]);
});

contract.operators(address).then((op) => {
    console.log(op);
});

contract.CommitteeLeaves(arbChainID, 0).then((leaf) => {
    console.log("Arb leaf 0: ", leaf);
});