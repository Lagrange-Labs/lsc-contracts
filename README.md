# Lagrange Contracts

## Prerequisites

1. Install [Node.js](https://nodejs.org/en/download/) 
2. Install [Docker](https://docs.docker.com/get-docker/)
3. Install [Docker Compose](https://docs.docker.com/compose/install/)
4. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)

After cloning the repository, run the following command to install the dependencies

```bash
forge install
```

## Local Deployment

1. Eigenlayer Deployment

    - Run the `geth` node using the following command

        ```bash
        make run-geth
        ```

    - Execute `make init-accounts` to initialize the accounts
    
    - Deploy the mock `WETH9` smart contract and update the `strategies/token_address` of `localnet/script/M1_deploy.config.json` with the deployed address

        ```bash
        make deploy-weth9
        ```
    - Update the `communityMultisig` of `eigenlayer-contracts/script/M1_deploy.config.json` with the first addres of the above list

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

2. Deploy the `Poseidon` smart contracts

    ```bash
    make deploy-poseidon
    ```

3. Deploy the `Lagrange` smart contracts

    ```bash
    make deploy-lagrange
    ```

4. Add the quorum to the `Lagrange` smart contracts

    ```bash
    make add-quorum
    ```

5. Opt into the `Lagrange` smart contracts

    ```bash
    make register-lagrange
    ```

6. Init the committee

    ```bash
    make init-committee
    ``

## Build the docker image

```bash
make docker-build

docker tag lagrange/contracts:latest lagrangelabs/lagrange-contracts:latest
docker push lagrangelabs/lagrange-contracts:latest
```
