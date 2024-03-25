const ethers = require("ethers");
const bls = require("@noble/bls12-381");
require("dotenv").config();

const abi = require("../out/LagrangeService.sol/LagrangeService.json").abi;
const deployedAddresses = require("../script/output/deployed_lgr.json");

const operators = require("../config/operators.json");
const uint32Max = 4294967295;

const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);

const convertBLSPubKey = (oldPubKey) => {
  const Gx = BigInt(oldPubKey.slice(0, 66));
  const Gy = BigInt("0x" + oldPubKey.slice(66));
  return [Gx, Gy];
};

(async () => {
  const owallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const ocontract = new ethers.Contract(
    deployedAddresses.addresses.lagrangeService,
    abi,
    owallet,
  );

  const tx = await ocontract.addOperatorsToWhitelist(operators[0].operators);
  console.log(
    `Starting to add operator to whitelist for address: ${operators[0].operators} tx hash: ${tx.hash}`,
  );
  const receipt = await tx.wait();
  console.log(
    `Add Operator Transaction was mined in block ${receipt.blockNumber} gas consumed: ${receipt.gasUsed}`,
  );

  await Promise.all(
    operators[0].operators.map(async (operator, index) => {
      const privKey = operators[0].ecdsa_priv_keys[index];
      const wallet = new ethers.Wallet(privKey, provider);
      const contract = new ethers.Contract(
        deployedAddresses.addresses.lagrangeService,
        abi,
        wallet,
      );

      const tx = await contract.register(
        convertBLSPubKey(operators[0].bls_pub_keys[index]),
      );
      console.log(
        `Starting to register operator for address: ${operator} tx hash: ${tx.hash}`,
      );
      const receipt = await tx.wait();
      console.log(
        `Register Transaction was mined in block ${receipt.blockNumber} gas consumed: ${receipt.gasUsed}`,
      );
    }),
  );

  operators.forEach(async (chain, k) => {
    for (let index = 0; index < chain.operators.length; index++) {
      const address = chain.operators[index];
      const privKey = operators[0].ecdsa_priv_keys[index];
      const wallet = new ethers.Wallet(privKey, provider);
      const contract = new ethers.Contract(
        deployedAddresses.addresses.lagrangeService,
        abi,
        wallet,
      );
      const nonce = await provider.getTransactionCount(address);
      const tx = await contract.subscribe(chain.chain_id, {
        nonce: nonce + k,
      });
      console.log(
        `Starting to subscribe operator for address: ${address} tx hash: ${tx.hash}`,
      );
      const receipt = await tx.wait();
      console.log(
        `Subscribe Transaction was mined in block ${receipt.blockNumber} gas consumed: ${receipt.gasUsed}`,
      );
    }
  });
})();
