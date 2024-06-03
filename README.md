# Lagrange Contracts

## Prerequisites

1. Install [Node.js](https://nodejs.org/en/download/)
2. Install [Docker](https://docs.docker.com/get-docker/)
3. Install [Docker Compose](https://docs.docker.com/compose/install/)
4. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)

After cloning the repository, run the following command to install the dependencies

```bash
# Update forge packages
foundryup

# Install or update dependencies
forge install
```

## Deployments

### Current Mainnet Deployment

The current mainnet deployment is on Ethereum mainnet. You can view the deployed contract addresses below, or check out the code itself on the [`mainnet`](https://github.com/Lagrange-Labs/lagrange-contracts/tree/mainnet) branch.

| Name                                                                                                                                                              | Proxy                                                                                                                   | Implementation                                                                             | Notes                                                                                                                                                |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`LagrangeCommittee`](https://github.com/Lagrange-Labs/lagrange-contracts/blob/220929d1d0582aa14b9422d8398487050da72e49/contracts/protocol/LagrangeCommittee.sol) | [`0xECc22f3EcD0EFC8aD77A78ad9469eFbc44E746F5`](https://etherscan.io/address/0xECc22f3EcD0EFC8aD77A78ad9469eFbc44E746F5) | [`0x6934...0854`](https://etherscan.io/address/0x69347e29480949995B6F527D7ac24225D66b0854) | Proxy: [`TUP@4.7.1`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.1/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) |
| [`LagrangeService`](https://github.com/Lagrange-Labs/lagrange-contracts/blob/220929d1d0582aa14b9422d8398487050da72e49/contracts/protocol/LagrangeService.sol)     | [`0x35F4f28A8d3Ff20EEd10e087e8F96Ea2641E6AA2`](https://etherscan.io/address/0x35F4f28A8d3Ff20EEd10e087e8F96Ea2641E6AA2) | [`0x9bfd...0659`](https://etherscan.io/address/0x9bfd992F5886f126ddB2539555064A0d1C040659) | Proxy: [`TUP@4.7.1`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.1/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) |
| [`EigenAdapter`](https://github.com/Lagrange-Labs/lagrange-contracts/blob/220929d1d0582aa14b9422d8398487050da72e49/contracts/library/StakeManager.sol)            | [`0xc39D3882E2Aa607bd37725C99357405E14aba05A`](https://etherscan.io/address/0xc39D3882E2Aa607bd37725C99357405E14aba05A) | [`0xb58c...e133`](https://etherscan.io/address/0xb58c233ba70bEC4c3E49D9438921E5a1Ec91e133) | Proxy: [`TUP@4.7.1`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.1/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) |
| [`VoteWeigher`](https://github.com/Lagrange-Labs/lagrange-contracts/blob/220929d1d0582aa14b9422d8398487050da72e49/contracts/protocol/VoteWeigher.sol)             | [`0xe1E25a74Eb983e668f2aBC93407a102010b48FD9`](https://etherscan.io/address/0xe1E25a74Eb983e668f2aBC93407a102010b48FD9) | [`0x7360...Fb22`](https://etherscan.io/address/0x736041228AF67631d4d390D5ADB5358e3730Fb22) | Proxy: [`TUP@4.7.1`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.1/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) |
| [`OZ: Proxy Admin`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.1/contracts/proxy/transparent/ProxyAdmin.sol)                                | -                                                                                                                       | [`0x7F11...845f`](https://etherscan.io/address/0x7F1130BC34a9633A202767B461772eCd953A845f) |                                                                                                                                                      |

### Current Testnet Deployment

The current testnet deployment is on Holesky testnet. You can view the deployed contract addresses below, or check out the code itself on the [`holesky/testnet`](https://github.com/Lagrange-Labs/lagrange-contracts/tree/holesky/testnet) branch.

| Name                                                                                                                                     | Proxy                                                                                                                           | Implementation                                                                                     | Notes                                                                                                                                                |
| ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`LagrangeCommittee`](https://github.com/Lagrange-Labs/lagrange-contracts/blob/holesky/testnet/contracts/protocol/LagrangeCommittee.sol) | [`0x57BAf26C77BBBa3D3A8Bd620c8d74B44Bfda8818`](https://holesky.etherscan.io/address/0x57BAf26C77BBBa3D3A8Bd620c8d74B44Bfda8818) | [`0xb0c7...87A5`](https://holesky.etherscan.io/address/0xb0c7b37c84169352f8b8808f20Ad549BF03387A5) | Proxy: [`TUP@4.7.1`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.1/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) |
| [`LagrangeService`](https://github.com/Lagrange-Labs/lagrange-contracts/blob/holesky/testnet/contracts/protocol/LagrangeService.sol)     | [`0x18A74E66cc90F0B1744Da27E72Df338cEa0A542b`](https://holesky.etherscan.io/address/0x18A74E66cc90F0B1744Da27E72Df338cEa0A542b) | [`0xDB83...2FF3`](https://holesky.etherscan.io/address/0xDB83CA0E993b61eE6d9dE5ebF41d3e64807D2FF3) | Proxy: [`TUP@4.7.1`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.1/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) |
| [`EigenAdapter`](https://github.com/Lagrange-Labs/lagrange-contracts/blob/holesky/testnet/contracts/library/StakeManager.sol)            | [`0xCe450Bbf64EF764D2092450718971B9D0b1789fb`](https://holesky.etherscan.io/address/0xCe450Bbf64EF764D2092450718971B9D0b1789fb) | [`0xBF24...ec8c`](https://holesky.etherscan.io/address/0xBF24691071edBCA48AD6bcC59c9A17886294ec8c) | Proxy: [`TUP@4.7.1`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.1/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) |
| [`VoteWeigher`](https://github.com/Lagrange-Labs/lagrange-contracts/blob/holesky/testnet/contracts/protocol/VoteWeigher.sol)             | [`0xd03B086323d011445AC25c4FcBFD0A7A0463A89C`](https://holesky.etherscan.io/address/0xd03B086323d011445AC25c4FcBFD0A7A0463A89C) | [`0x4f00...c618`](https://holesky.etherscan.io/address/0x4f00C996E2a32fE8D1100c89594041E73DF7c618) | Proxy: [`TUP@4.7.1`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.1/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) |
| [`OZ: Proxy Admin`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.1/contracts/proxy/transparent/ProxyAdmin.sol)       | -                                                                                                                               | [`0x5c70...0F70`](https://holesky.etherscan.io/address/0x5c7029658bB7223774220f85117bC52813C40F70) |                                                                                                                                                      |

### Audit Reports

Here are the [audit reports](./audits/)

## Local Deployment

The following walks through the necessary steps to deploy the Lagrange contracts locally.

```
make deploy-eigen-localnet
```

## Build the docker image

```bash
make docker-build

docker tag lagrange/contracts:latest lagrangelabs/lagrange-contracts:latest
docker push lagrangelabs/lagrange-contracts:latest
```
