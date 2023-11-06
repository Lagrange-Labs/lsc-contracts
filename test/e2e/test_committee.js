const ethers = require('ethers');

const accounts = require('../../config/accounts.json');
const abi =
  require('../../out/LagrangeCommittee.sol/LagrangeCommittee.json').abi;
const stakeABI = require('../../out/StakeManager.sol/StakeManager.json').abi;

const deployedAddresses = require('../../script/output/deployed_lgr.json');
require('dotenv').config();

const address = '0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9';
const tokenAddress = '0x1D7Acca2751281Bd27d8254fC2fCd71a5243626c';
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

const arbChainID = 5001;
const optChainID = 5001;

contract.getCommittee(optChainID, 5000).then((current) => {
  console.log('Opt Current committee: ', current[0]);
  console.log('Opt Next committee: ', current[1]);
});

contract.getCommittee(arbChainID, 4677).then((current) => {
  console.log('Arb Current committee: ', current[0]);
  console.log('Arb Next committee: ', current[1]);
});

contract.committeeParams(arbChainID).then((params) => {
  console.log('Arb params: ', params);
});

contract.operators(address).then((op) => {
  console.log(op);
});
