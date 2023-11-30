const fs = require('fs');
const { ethers } = require('hardhat');
const deployed_verifiers = require('../script/output/deployed_verifiers.json');

async function main() {
  const raw = fs.readFileSync('script/output/deployed_lgr.json');
  const json = JSON.parse(raw);
  const addresses = json.addresses;

  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

  // deploy - aggregate

  evABI = JSON.parse(
    fs.readFileSync('out/EvidenceVerifier.sol/EvidenceVerifier.json'),
  ).abi;
  ev = new ethers.Contract(addresses['evidenceVerifier'], evABI, wallet);

  const sizes = [0, 16, 32, 64, 128, 256, 512];
  for (size of sizes) {
    path = `contracts/library/slashing_aggregate/verifier_${size}.sol:Verifier_${size}`;
    if (size == 0) {
      path = `contracts/library/slashing_single/verifier.sol:Verifier`;
    }
    factory = await ethers.getContractFactory(path, wallet);
    verifier = await factory.deploy();
    tx = await verifier.deployed();
    console.log(
      'slashing_aggregate verifier contract for size',
      size,
      'deployed to address',
      verifier.address,
    );

    deployed_verifiers[size] = verifier.address;

    // associate
    if (size == 0) {
      tx = await ev.setSingleVerifier(verifier.address);
    } else {
      tx = await ev.setAggregateVerifierRoute(size, verifier.address);
    }
    console.log(
      'verifier contract associated with triage contract at',
      ev.address,
    );
    await tx.wait();
  }

  fs.writeFileSync(
    'script/output/deployed_verifiers.json',
    JSON.stringify(deployed_verifiers, null, 4),
  );
}

main();
