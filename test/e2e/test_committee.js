const ethers = require('ethers');

const accounts = require('../../config/accounts.json');
const abi =
  require('../../out/LagrangeCommittee.sol/LagrangeCommittee.json').abi;
const stakeABI = require('../../out/StakeManager.sol/StakeManager.json').abi;

const deployedAddresses = require('../../script/output/deployed_lgr.json');
require('dotenv').config();

const address = '0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9';
const tokenAddress = '0xbB9dDB1020F82F93e45DA0e2CFbd27756DA36956';
const privKey = accounts[address];
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(privKey, provider);
const contract = new ethers.Contract(
  deployedAddresses.addresses.lagrangeCommittee,
  abi,
  wallet,
);
const stake = new ethers.Contract(
  deployedAddresses.addresses.stakeManager,
  stakeABI,
  wallet,
);

provider.getNetwork().then((network) => {
  console.log('chainID: ', network.chainId);
});

stake.weightOfOperator(address, 1).then((weight) => {
  console.log('Weight: ', weight);
});

stake.tokenMultipliers(0).then((multiplier) => {
  console.log('Multiplier: ', multiplier);
});

stake.operatorStakes(tokenAddress, address).then((stake) => {
  console.log('Stake: ', stake);
});

const arbChainID = 1337;
const optChainID = 420;

contract.getCommittee(optChainID, 1000).then((current) => {
  console.log('Opt Current committee: ', current[0]);
  console.log('Opt Next committee: ', current[1]);
});

contract.getCommittee(arbChainID, 1000).then((current) => {
  console.log('Arb Current committee: ', current[0]);
  console.log('Arb Next committee: ', current[1]);
});

contract.operators(address).then((op) => {
  console.log(op);
});
