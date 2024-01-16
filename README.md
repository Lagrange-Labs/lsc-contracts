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

## Local Deployment

The following walks through the necessary steps to deploy the Lagrange contracts, interfacing with mock contracts for EigenLayer, as well as Arbitrum Nitro and Optimism Bedrock settlement mock contracts.

```
make deploy-eigen-localnet
```

## Local Deployment

**Note**: _The following steps are deprecated as of July 2023._

1. Eigenlayer Deployment

   - Run the `geth` node using the following command

     ```bash
     make run-geth
     ```

   - Execute `make init-accounts` to initialize the accounts
   - Execute `make generate-accounts` to create the accounts configuration file
   - Deploy the mock `WETH9` smart contract for the virtual strategy

     ```bash
     make deploy-weth9
     ```

   - Execute `make update-strategy-config` to update the strategy config of Eigenlayer Deployment

   - Deploy the `Eigenlayer` smart contracts,

     ```bash
     make deploy-eigenlayer
     ```

   - Add the `WETH` strategy to the `Eigenlayer` StrategyManager

     ```bash
     make add-strategy
     ```

   - Register the `Operator`

     ```bash
     make register-operator
     ```

2. Deploy the `Lagrange` smart contracts

   ```bash
   make deploy-lagrange
   ```

   - Execute `make update-config` to update the token config of `Add Quorum`

3. Add the quorum to the `Lagrange` smart contracts

   ```bash
   make add-quorum
   ```

4. Opt into the `Lagrange` smart contracts

   ```bash
   make register-lagrange
   ```

5. Register operators and subscribe the given chains

   ```bash
   make deploy-register
   ```

6. Init the committee

   ```bash
   make init-committee
   ```

To clean up the deployment, run the following command

```bash
make clean
```

## Build the docker image

```bash
make docker-build

docker tag lagrange/contracts:latest lagrangelabs/lagrange-contracts:latest
docker push lagrangelabs/lagrange-contracts:latest
```
