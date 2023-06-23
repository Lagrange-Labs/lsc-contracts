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
    
        ```address
        Available Accounts
            Account 0: 0x6E654b122377EA7f592bf3FD5bcdE9e8c1B1cEb9
            Private key: 0x3e17bc938ec10c865fc4e2d049902716dc0712b5b0e688b7183c16807234a84c
            Account 1: 0x516D6C27C23CEd21BF7930E2a01F0BcA9A141a0d
            Private key: 0x232d99bc62cf95c358fb496e9f820ec299f43417397cea32f9f365daf4748429
            Account 2: 0x4d694DE17246086d6451D732Ea8EA2a9a76dC997
            Private key: 0x25f536330df3a72fa381bfb5ea5552b2731523f08580e7a0e2e69618a9643faa
            Account 3: 0x5d51B4c1fb0c67d0e1274EC96c1B895F45505a3D
            Private key: 0xc262364335471942e02e79d760d1f5c5ad7a34463303851cacdd15d72e68b228
            Account 4: 0x13cF11F76a08214A826355a1C8d661E41EA7Bf97
            Private key: 0xb126ae5e3d88007081b76024477b854ca4f808d48be1e22fe763822bc0c17cb3
            Account 5: 0xBD2369a9535751004617bC47cB0BF8Ea5c35Ed7C
            Private key: 0x220ecb0a36b61b15a3af292c4520a528395edc51c8d41db30c74382a4af4328d
            Account 6: 0x83070c799c0d41526D4c71e462557CdbB2C750AC
            Private key: 0x2a1b271106503777361139b2d28c3f360ce980e2dab0c18f4684d5b417ac46b3
            Account 7: 0x7365666466f97E8aBBEE8900925521e0469A1f25
            Private key: 0x311fb4aa77facbc0debb6d9d88d3b4047115d905a4ff7b4399fc164494a75e3c
            Account 8: 0xaa58F0fC9eddeFBef9E4C1c3e81f8cA5f22b9B8e
            Private key: 0x897ae21c31176946115ad9174145c2e8b755e1be0c1b4987a63db790349e8e15
            Account 9: 0x40e1201138f0519877e3704F253153C92f5cfD2a
            Private key: 0x9750901b0ded0603e9be4a56315fe1487d4afc7ec05e3fc75fe6c568d52bea1b
            Account 10: 0xF4F16235e0591BD0BD21772718288126388C52c7
            Private key: 0xf1efa79837b4ea45d2345ff3946859dda9afe131b97bcb0654927248f4eb2918
            Account 11: 0x3928b81f4f36913055B9D127F6F4f4EBc47B03bd
            Private key: 0x5055f4029a4b83fd3e2c94e0c9baa9042529a067d42cec843c7d109c5b5756e0
            Account 12: 0xb6e28D040F412054e769d8Fa01964fD30fe585a5
            Private key: 0x913f118220494d05facd61f2a4919d2d10148042cffb2732c30c10a759713d7f
            Account 13: 0x9fBDa3FC11494bF357FD2041631836795322Dd33
            Private key: 0x5b8e5f0e79175b7098a1cea3972a6739b0bbbcee527cec13d6a0dd605858e389
            Account 14: 0xf431E2fd356150677831Be391b2a73D37EDeeA60
            Private key: 0xa617dc90522527902e6cc78c367b1a61dfc8e9f0b6cde537e281623f6da80a3d
            Account 15: 0xD1b53572F9d2F186dE2B6319DAF70dD724888b79
            Private key: 0x10c77ae8faf550e9c23b07856c2de36c992b8f0bb7497409c133b2caede81295
            Account 16: 0xeEB0A6E0dD3C77113D7A1d876e6Fbb06f8e8F465
            Private key: 0x4906854b045b4d8d51dfc696786391de44bd7996b7a66e268453dd0609af45bb
            Account 17: 0xDAD2031D449F8C61A852f3d5b3c3f1e9425FA4f9
            Private key: 0xfec75f4d982cce5e1e43d41d55557ff58875e7e44b0a3f4e06e97ea437d8162a
            Account 18: 0x84634743616036a45Ce02D8d6A2B06F8e4ED37b7
            Private key: 0x37652b3171834042ce595e8b16f9b6705ba678231030d11fcae3ecec254454b0
            Account 19: 0x3cDE5DD353Bf3c8C0D3D7d905436D7A7c3C369a2
            Private key: 0xa9f8fe458bddbb32c12e6bfbef75f313efff844565ba38b3098d6f88b88c7075
        ```
    - Deploy the mock `WETH9` smart contract and update the `strategies/token_address` of `localnet/script/M1_deploy.config.json` with the deployed address

        ```bash
        make deploy-weth9
        ```
    - Update the `communityMultisig` of `eigenlayer-contracts/script/M1_deploy.config.json` with the first addres of the above list

    - Deploy the `Eigenlayer` smart contracts, 
        ```bash
        make deploy-eigenlayer
        ```

2. Add the `WETH` strategy to the `Eigenlayer` StrategyManager

    ```bash
    make add-strategy
    ```
    
3. Deploy the `Poseidon` smart contracts

    ```bash
    make deploy-poseidon
    ```

4. Deploy the `Lagrange` smart contracts

    ```bash
    make deploy-lagrange
    ```

5. Register the `Operator`

    ```bash
    make register-operator 
    ```

## Build the docker image

```bash
make docker-build

# WETH: 0xbB9dDB1020F82F93e45DA0e2CFbd27756DA36956
# LagrangeCommittee: 0xF824C350EA9501234a731B01B8EC6E660e069c7F
# Lagrange Service: 0x75B96311d8040c0F0d543ED5dc57b8Aa8492ffEF
```
