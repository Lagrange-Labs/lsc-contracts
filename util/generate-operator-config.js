/* eslint-disable no-await-in-loop */

const ethers = require('ethers');
const fs = require('fs');
const bls = require('bls-eth-wasm');
const blst = require('@noble/bls12-381');
const config = require('../config/LagrangeService.json');
require('dotenv').config();

const DEFAULT_MNEMONIC =
  'exchange holiday girl alone head gift unfair resist void voice people tobacco';
const ACCOUNT_ID = 103;

const convertBLSPubKey = (oldPubKey) => {
  const pubKey = blst.PointG1.fromHex(oldPubKey.slice(2));
  const Gx = pubKey.toAffine()[0].value.toString(16).padStart(96, '0');
  const Gy = pubKey.toAffine()[1].value.toString(16).padStart(96, '0');
  return '0x' + Gx + Gy;
};

async function genBLSKey() {
  await bls.init(bls.BLS12_381);
  blsKey = new bls.SecretKey();
  await blsKey.setByCSPRNG();
  return blsKey;
}

async function main() {
  const operator = {};

  const pathWallet = `m/44'/60'/0'/0/${ACCOUNT_ID}`;
  const accountWallet = ethers.Wallet.fromMnemonic(
    DEFAULT_MNEMONIC,
    pathWallet,
  );
  operator['operator_address'] = accountWallet.address;
  operator['ecdsa_private_key'] = accountWallet.privateKey;

  blsPair = await genBLSKey();
  pub = await blsPair.getPublicKey();
  operator['bls_public_key'] = '0x' + (await pub.serializeToHexStr());
  operator['bls_private_key'] = '0x' + (await blsPair.serializeToHexStr());
  operator['bls_public_point'] = convertBLSPubKey(operator['bls_public_key']);
  operator['chain_id'] = config.chains[0].chain_id;

  await fs.promises.writeFile(
    './config/random_operator.json',
    JSON.stringify({ operator: operator }, null, 4),
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
