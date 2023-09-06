require("@nomicfoundation/hardhat-toolbox");
require("hardhat-preprocessor");
const fs = require("fs");

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .filter((line) => !line.includes("node_modules")) // remove node_modules remappings
    .map((line) => line.trim().split("="));
}

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  mocha: {
    timeout: 100000000,
  },
  preprocess: {
    eachLine: (hre) => ({
      transform: (line) => {
        if (line.match(/^\s*import /i)) {
          for (const [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to);
              break;
            }
          }
        }
        return line;
      },
    }),
  },
  paths: {
    sources: "./src",
    cache: "./cache_hardhat",
    tests: "./test/hardhat",
  },
  networks: {
    hardhat: {
      gas: "auto", // Automatically estimate the gas in each transaction
      blockGasLimit: 0x1fffffffffffff, // Set a high block gas limit
      allowUnlimitedContractSize: true, // This option disables the contract size check
      accounts: [
        {
          privateKey:
            "0x3e17bc938ec10c865fc4e2d049902716dc0712b5b0e688b7183c16807234a84c",
          balance: "1000000000000000000000000",
        },
      ],
    },
    docker: {
      url: "http://0.0.0.0:8545",
      allowUnlimitedContractSize: true, // This option disables the contract size check
      timeout: 100000000,
    },
    devnet: {
      url: "http://0.0.0.0:8545",
      allowUnlimitedContractSize: true,
    },
  },
};
