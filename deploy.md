# Testnet Deployment Checklist

## Preparation

- **Cleanup** Consider clearing the working tree or creating a fresh clone of the repository as it exists at the remote origin.

- Test the contracts.

  - Foundry:

  ```bash
  make test
  ```

  - Hardhat:

  ```bash
  npx hardhat test
  ```

- Test a local deployment.
  - Export relevant environmental variables:
  ```bash
  export RPC_URL="http://0.0.0.0:8545"
  ```
  - Deploy.
  ```bash
  make all-native
  ```
  - Cleanup.
  ```bash
  make clean
  ```

## Deployment

- Export relevant environmental vars
  ```bash
  export RPC_URL="https://example.com/path/to/endpoint";
  export PRIVATE_KEY="0x...";
  ```
- Walk through `make all-native` step by step, without `run-geth` or `init-accounts`:

```bash
make run-geth;
make generate-accounts;
make deploy-weth9;
make deploy-mock;
make deploy-lagrange;
make deploy-verifiers;
make update-config;
make add-quorum;
node util/distributor.js # optional for private testnet
make deposit-stake;
make deploy-register;
make init-committee;
```

## Post-Deployment Verification

`TBD`
