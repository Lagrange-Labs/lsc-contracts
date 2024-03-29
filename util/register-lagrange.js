const ethers = require('ethers');

require('dotenv').config();

const serviceConfig = require('../config/LagrangeService.json');

const serviceABI =
  require('../out/LagrangeService.sol/LagrangeService.json').abi;
const committeeABI =
  require('../out/LagrangeCommittee.sol/LagrangeCommittee.json').abi;
const avsDirectoryABI =
  require('../out/IAVSDirectory.sol/IAVSDirectory.json').abi;
const deployedAddresses = require('../script/output/deployed_lgr.json');

const operator = "0x3Ea592963Db02A3b6a68211676492F137987caeE";
const blsPubKey = "0x08a1fe4e6dc41f627676a49261ce9707b5180c1ac2a116c163e8c49a7a6609d510b36e0d5b66dd8c9a96d54a3fc0ae83b50ec4151a23f99deb9038ba0a19e2cb";

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

  const avsDirectory = new ethers.Contract(
    serviceConfig.eigenlayer_addresses.holesky.avsDirectory,
    avsDirectoryABI,
    owallet,
  );

  const tx = await ocontract.addOperatorsToWhitelist([operator]);
  console.log(
    `Starting to add operator to whitelist for address: ${operator} tx hash: ${tx.hash}`,
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
  for (let i = 0; i < serviceConfig.chains.length; i++) {
    chainParams.push(await committee.committeeParams(serviceConfig.chains[i].chain_id));
  }
  console.log('Chain Params', chainParams);

  const privKey = process.env.OPERATOR_PRIV_KEY;
  const wallet = new ethers.Wallet(privKey, provider);
  const contract = new ethers.Contract(
    deployedAddresses.addresses.lagrangeService,
    serviceABI,
    wallet,
  );

  const timestamp = (await provider._getBlock()).timestamp;
  const salt =
    '0x0000000000000000000000000000000000000000000000000000000000000011'; //
  const expiry = timestamp + 60; // 1 minutes from now
  const avs = deployedAddresses.addresses.lagrangeService; //

  const digestHash =
    await avsDirectory.calculateOperatorAVSRegistrationDigestHash(
      operator, // address operator,
      avs, // address avs, // This address should be smart contract address who calls AVSDirectory.registerOperatorToAVS
      salt, // bytes32 approverSalt,
      expiry, // uint256 expiry
    );
  console.log('Digest Hash', digestHash);
  let hexPrivKey = privKey;
  if (!privKey.startsWith('0x')) {
    hexPrivKey = '0x' + privKey;
  }
  const signingKey = new ethers.utils.SigningKey(hexPrivKey);
  const signature = signingKey.signDigest(digestHash).compact;

  const tx1 = await contract.register(
    operator,
    [convertBLSPubKey(blsPubKey)],
    { signature, salt, expiry },
  );
  console.log(
    `Starting to register operator for address: ${operator} tx hash: ${tx1.hash}`,
  );
  const receipt1 = await tx1.wait();
  console.log(
    `Register Transaction was mined in block ${receipt1.blockNumber} gas consumed: ${receipt1.gasUsed}`,
  );

  for (let k = 0; k < chainParams.length; k++) {
    const chain_id = serviceConfig.chains[k].chain_id;
    while (true) {
      const blockNumber = await provider.getBlockNumber();
      const isLocked = await committee.isLocked(chain_id);
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

    const tx = await contract.subscribe(chain_id);
    console.log(
      `Starting to subscribe operator for address: ${operator} tx hash: ${tx.hash}`,
    );
    const receipt = await tx.wait();
    console.log(
      `Subscribe Transaction was mined in block ${receipt.blockNumber} gas consumed: ${receipt.gasUsed}`,
    );
  }
})();
