const ethers = require('ethers');

require('dotenv').config();

const serviceABI =
  require('../out/LagrangeService.sol/LagrangeService.json').abi;
const committeeABI =
  require('../out/LagrangeCommittee.sol/LagrangeCommittee.json').abi;
const deployedAddresses = require('../script/output/deployed_lgr.json');

const operators = require('../config/operators.json');

const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);

const convertBLSPubKey = (oldPubKey) => {
  const Gx = BigInt(oldPubKey.slice(0, 66));
  const Gy = BigInt('0x' + oldPubKey.slice(66));
  return [Gx, Gy];
};

(async () => {
  const owallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const ocontract = new ethers.Contract(
    deployedAddresses.addresses.lagrangeService,
    serviceABI,
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

  const committee = new ethers.Contract(
    deployedAddresses.addresses.lagrangeCommittee,
    committeeABI,
    owallet,
  );

  const chainParams = [];
  for (let i = 0; i < operators.length; i++) {
    chainParams.push(await committee.committeeParams(operators[i].chain_id));
  }
  console.log('Chain Params', chainParams);

  await Promise.all(
    operators[0].operators.map(async (operator, index) => {
      const privKey = operators[0].ecdsa_priv_keys[index];
      const wallet = new ethers.Wallet(privKey, provider);
      const contract = new ethers.Contract(
        deployedAddresses.addresses.lagrangeService,
        serviceABI,
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

  for (let k = 0; k < operators.length; k++) {
    const chain = operators[k];
    for (let index = 0; index < chain.operators.length; index++) {
      const address = chain.operators[index];
      const privKey = operators[0].ecdsa_priv_keys[index];
      const wallet = new ethers.Wallet(privKey, provider);
      const contract = new ethers.Contract(
        deployedAddresses.addresses.lagrangeService,
        serviceABI,
        wallet,
      );

      while (true) {
        const blockNumber = await provider.getBlockNumber();
        const isLocked = await committee.isLocked(chain.chain_id);
        console.log(
          `Block Number: ${blockNumber} isLocked: ${isLocked[1].toNumber()} Freeze Duration: ${chainParams[
            k
          ].freezeDuration.toNumber()}`,
        );
        if (
          blockNumber <
          isLocked[1].toNumber() - chainParams[k].freezeDuration.toNumber() - 1
        ) {
          break;
        }

        await new Promise((resolve) => setTimeout(resolve, 500));
      }

      const tx = await contract.subscribe(chain.chain_id);
      console.log(
        `Starting to subscribe operator for address: ${address} tx hash: ${tx.hash}`,
      );
      const receipt = await tx.wait();
      console.log(
        `Subscribe Transaction was mined in block ${receipt.blockNumber} gas consumed: ${receipt.gasUsed}`,
      );
    }
  }
})();
