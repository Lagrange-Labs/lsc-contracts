const ethers = require('ethers');

const accounts = require('../../config/accounts.json');
const abi =
  require('../../out/LagrangeCommittee.sol/LagrangeCommittee.json').abi;
const serviceABI =
  require('../../out/LagrangeService.sol/LagrangeService.json').abi;

const deployedAddresses = require('../../script/output/deployed_sepolia.json');
const env = require('hardhat');
require('dotenv').config();

const privKey = process.env.PRIVATE_KEY;
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

const arbChainID = 421614;
const optChainID = 11155420;
const mantleChainID = 5003;

const chainIDs = [arbChainID, optChainID, mantleChainID];

const testCommitteeSepolia = async () => {
  for (let i = 0; i < chainIDs.length; i++) {
    const chainID = chainIDs[i];
    // for (let j = 0; j < 10; j++) {
    //   try {
    //     const res = await contract.committeeAddrs(chainID, j);
    //     console.log(chainID, j, res);
    //   } catch (e) {
    //     console.log(chainID, j, e);
    //   }
    // }

    const res = await contract.committeeLeavesMap(chainID, "0x7627e924F5e74aeeE246E701cd23F5B038b3c5cD");
    console.log("Leaves map", chainID, res);

    // for (let j = 0; j < 5; j++) {
    //   for (let k = 0; k < 10; k++) {
    //     try {
    //       const res = await contract.committeeNodes(chainID, j, k);
    //       console.log("committeeNodes:", chainID, j, k, res);
    //     } catch (e) {
    //       console.log(chainID, j, k, e);
    //     }
    //   }
    // }

    const res1 = await contract.updatedEpoch(chainID);
    console.log("Updated epoch", chainID, res1);

    const res2 = await contract.getEpochNumber(chainID,

      5374652

    );
    console.log("Epoch number", chainID, res2);
    const res3 = await contract.isUpdatable(chainID, res2);
    console.log("Is updatable", chainID, res3);

    const res4 = await contract.getCommittee(chainID,

      5374362

    );
    console.log("Committee", chainID, res4);
  }
  const res = await contract.getOperatorStatus("0x7627e924F5e74aeeE246E701cd23F5B038b3c5cD");
  console.log("Operator status", res);


  const res1 = await contract.getBlsPubKey("0x7627e924F5e74aeeE246E701cd23F5B038b3c5cD");
  hex = res1[0]._hex.slice(2) + res1[1]._hex.slice(2);
  console.log("Bls public key", hex);

  for (let i = 0; i < chainIDs.length; i++) {
    const chainID = chainIDs[i];
    const res = await contract.updatedEpoch(chainID);
    console.log("Operator status by chain", chainID, res);
    const res1 = await contract.getEpochNumber(chainID, 5368030);
    console.log("Epoch number by chain", chainID, res1);

    const res4 = await contract.getOperatorVotingPower("0x7627e924F5e74aeeE246E701cd23F5B038b3c5cD", chainID);
    console.log("Operator amount", res4);

  }

}



const unsubscribeChainByAdmin = async () => {
  for (let i = 0; i < chainIDs.length; i++) {
    const chainID = chainIDs[i];
    const tx = await contract.unsubscribeChainByAdmin("0x7627e924F5e74aeeE246E701cd23F5B038b3c5cD", chainID);
    console.log("Unsubscribe chain by admin", tx);
  }
}

const updateOperatorAmount = async () => {
  for (let i = 0; i < chainIDs.length; i++) {
    const chainID = chainIDs[i];
    const tx = await contract.updateByAdmin("0x7627e924F5e74aeeE246E701cd23F5B038b3c5cD", chainID);
    console.log("Update operator amount", tx);
  }
}

// unsubscribeChainByAdmin();

testCommitteeSepolia();

// updateOperatorAmount();