const ethers = require('ethers');
const fs = require('fs');

const accounts = require('../docker/accounts.json');
const abi = require('../out/LagrangeCommittee.sol/LagrangeCommittee.json').abi;
const deployedAddresses = require('../script/output/deployed_lgr.json');
const { getContractAddress } = require('ethers/lib/utils');

const address = '0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9';
const privKey = accounts[address];
const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
const wallet = new ethers.Wallet(privKey, provider);
const contract = new ethers.Contract(deployedAddresses.addresses.lagrangeCommittee, abi, wallet);

const arbChainID = 42161;
const optChainID = 10;

contract.getCommittee(optChainID, 10000).then((current) => {
    console.log("Current committee: ", current[0]);
    console.log("Next committee: ", current[1]);
});


contract.getCommittee(arbChainID, 10000).then((current) => {
    console.log("Current committee: ", current[0]);
    console.log("Next committee: ", current[1]);
});

