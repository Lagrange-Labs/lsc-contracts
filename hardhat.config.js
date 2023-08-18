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
  solidity: "0.8.12",
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
	allowUnlimitedContractSize: true // This option disables the contract size check
    },
  },
};
