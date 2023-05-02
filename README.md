# Lagrange Contracts

## Local Deployment

1. Eigenlayer Deployment

    - Execute the `Ganache` node using the following command

    ```bash
    ganache -f {RPC_URL} --db ./ganache-db/chaindata
    ```

        ```address
        Available Accounts
        ==================
        (0) 0x10B7fE3270b4D3196c4458AB3dc0D3B068DA48d8 (1000 ETH)
        (1) 0x5c948967555EB37a7a0F35386b6431bBbf8873B0 (1000 ETH)
        (2) 0x6DfC5717B04726a0Fe6F3Ad42fceF0CbFDE7D395 (1000 ETH)
        (3) 0x0Fb7929B930Fb63A3a0781D8BBeEB09FdB046B96 (1000 ETH)
        (4) 0x215e4750D5e54362D4D0ee15e9eb4861eCEE5239 (1000 ETH)
        (5) 0x5CDcb6A9143979E6A794846Bb00109ef88a7F044 (1000 ETH)
        (6) 0x2a30FC1DE021484F1ae80aaaeA67224f899377fA (1000 ETH)
        (7) 0x43b94784837359CEe17Cc9A105A023e2f723CbD6 (1000 ETH)
        (8) 0x77991B853f381d18D37F92BE0B3023dA48A34499 (1000 ETH)
        (9) 0x5eF6F609E9Bd361c4Cb3a404E185dFd30AF9A5B7 (1000 ETH)

        Private Keys
        ==================
        (0) 0x49f6a64a011a6cd2e84d66396be15299ee9ad07a5c45daed40db37f6128a268e
        (1) 0xaf09af2426bf40758baeff7e5d7314b6a596ac71ddb33700f50d74330bc38ae6
        (2) 0x7eedda23766d41a27df98d7867f23429a7791de57ed333810fc9ee92ffa85ce4
        (3) 0xe017138e8a45cef27949b165cf175802ebc8227ed6454e49e921447784479a4a
        (4) 0xa9fc8bd0ca9a0260d3a5f0ff5a1a320580d6051ddf18858e9970a63809e0ccd8
        (5) 0x87da4d7fdc9ce8eb97aa23936c061d402bc372bb737d0d7ddd2cb6739abd84d5
        (6) 0xf2541a7640664a007fd2e0b5ebfb7f2a33b355941f4f4f6d34a529e9b2df7f0c
        (7) 0x36e141f2ebe87274a2fecd5f7e4a19a7f9cff7a3e38e0157ef01f5c820ca305c
        (8) 0x843a913bcdf07f4cbb9b8de1ee1ba81714d268d6494c5013011b4d4bd11e3905
        (9) 0x6ad7ca63baa68d7bd23c99ba629eae9402472a1079f2f9da816144aed9b03ff3
        ```
    - Deploy the `Eigenlayer` smart contracts, pick one private key from `Ganache` node and update the `communityMultisig` of `eigenlayer-contracts/script/M1_deploy.config.json` with the given address

    ```bash
    forge script script/M1_Deploy.s.sol:Deployer_M1 --rpc-url http://localhost:8545  --private-key {PRIVATE_KEY} --broadcast -vvvv
    ```

2. Register the `Operator`

    ```bash
    make register-operator 
    ```

3. Deploy the `Lagrange` smart contracts

    ```bash
    make deploy-lagrange
    ```

    // 0x7Fd233Ca513E9a92628F69dbD0eee033788C432b