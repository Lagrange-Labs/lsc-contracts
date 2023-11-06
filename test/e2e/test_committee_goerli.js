const ethers = require('ethers');

const accounts = require('../../config/accounts.json');
const abi =
  require('../../out/LagrangeCommittee.sol/LagrangeCommittee.json').abi;
const serviceABI =
  require('../../out/LagrangeService.sol/LagrangeService.json').abi;

const deployedAddresses = require('../../script/output/deployed_goerli.json');
require('dotenv').config();

const address = '0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9';
const privKey = accounts[address];
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(privKey, provider);
const contract = new ethers.Contract(
  deployedAddresses.lagrange.addresses.lagrangeCommittee,
  abi,
  wallet,
);
const service = new ethers.Contract(
  deployedAddresses.lagrange.addresses.lagrangeService,
  serviceABI,
  wallet,
);

const arbChainID = 5001;
const optChainID = 5001;

contract.getEpochNumber(arbChainID, 9998228).then((epoch) => {
  console.log('Arb epoch: ', epoch);
});

contract.getCommittee(arbChainID, 9998228).then((current) => {
  console.log('Arb Current committee: ', current[0]);
  console.log('Arb Next committee: ', current[1]);
});

contract.getEpochNumber(optChainID, 9998228).then((epoch) => {
  console.log('Opt epoch: ', epoch);
});

contract.isUpdatable(arbChainID, 2).then((updatable) => {
  console.log('Arb updatable: ', updatable);
});

contract.isUpdatable(arbChainID, 3).then((updatable) => {
  console.log('Arb updatable: ', updatable);
});

contract.updatedEpoch(arbChainID).then((epoch) => {
  console.log('Arb updated epoch: ', epoch);
});
