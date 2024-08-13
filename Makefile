PRIVATE_KEY?="0x3e17bc938ec10c865fc4e2d049902716dc0712b5b0e688b7183c16807234a84c"
RPC_URL?="http://localhost:8545"

# Run ethereum nodes
run-geth:
	cd docker && DEV_PERIOD=1 docker compose up -d geth --wait

init-accounts:
	node util/init-accounts.js

generate-accounts: 
	node util/generate-accounts.js

.PHONY: run-geth init-accounts

# Deploy scripts

deploy-eigenlayer:
	forge script script/localnet/M1_Deploy.s.sol:Deployer_M1 --rpc-url ${RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv --slow

deploy-weth9:
	forge script script/localnet/DeployWETH9.s.sol:DeployWETH9 --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv --slow

add-strategy:
	forge script script/localnet/AddStrategy.s.sol:AddStrategy --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv --slow

register-operator:
	export PRIVATE_KEY=${PRIVATE_KEY} && export RPC_URL=${RPC_URL} && node util/register-operator.js

deploy-lagrange:
	forge script script/Deploy_LGR.s.sol:Deploy --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv --slow

deploy-verifiers:
	export PRIVATE_KEY=${PRIVATE_KEY} && export RPC_URL=${RPC_URL} && npx hardhat run util/deploy-verifiers.js

add-quorum:
	forge script script/Add_Quorum.s.sol:AddQuorum --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv --slow

init-committee:
	forge script script/Init_Committee.s.sol:InitCommittee --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv --slow

deposit-stake:
	export PRIVATE_KEY=${PRIVATE_KEY} && export RPC_URL=${RPC_URL} && node util/deposit-stake.js

.PHONY: deploy-weth9 deploy-eigenlayer add-strategy register-operator deploy-lagrange add-quorum init-committee deposit-stake

deploy-register:
	export PRIVATE_KEY=${PRIVATE_KEY} && export RPC_URL=${RPC_URL} && node util/deploy-register.js

deploy-mock:
	forge script script/Deploy_Mock.s.sol:DeployMock --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv --slow

update-strategy-config:
	export PRIVATE_KEY=${PRIVATE_KEY} && export RPC_URL=${RPC_URL} && node util/update-strategy-config.js

update-config:
	node util/update-config.js

distribute:
	node util/distributor.js

.PHONY: deploy-mock deploy-register update-config update-strategy-config distribute

# Build docker image

stop:
	cd docker && docker compose down --remove-orphans

docker-build: stop
	sudo chmod -R go+rxw docker/geth_db && cd docker && docker build . -t lagrange/contracts

.PHONY: docker-build stop run-docker

# Test
test:
	forge test -vvvvv
	npx hardhat test
test-gas:
	forge script ./script/TestGas.s.sol:TestGas -vvvv --slow
.PHONY: test

clean: stop
	sudo rm -rf docker/geth_db

give-permission:
	sudo chmod -R go+rxw docker/geth_db

# Deploy
deploy-eigen-localnet: run-geth init-accounts generate-accounts deploy-weth9 update-strategy-config deploy-eigenlayer add-strategy register-operator deploy-lagrange update-config add-quorum init-committee  deploy-register

deploy-mock-localnet: run-geth init-accounts generate-accounts deploy-mock deploy-lagrange update-config add-quorum deploy-register init-committee

deploy-native-localnet: run-geth init-accounts generate-accounts deploy-weth9 deploy-lagrange update-config add-quorum init-committee deposit-stake deploy-register

deploy-lagrange-testnet: deploy-lagrange add-quorum init-committee

depoloy-eigen-private-testnet: init-accounts generate-accounts deploy-weth9 update-strategy-config deploy-eigenlayer add-strategy register-operator deploy-lagrange update-config add-quorum deploy-register

.PHONY: deploy-eigen-localnet deploy-mock-localnet deploy-native-localnet

# Formatter
format:
	npx prettier --write {test,util}/**/*.js
	forge fmt

solhint:
	npx solhint "contracts/protocol/*.sol"

.PHONY: format

# Register one random operator
generate-one-operator:
	node util/generate-operator-config.js

register-one-operator: generate-one-operator
	export RPC_URL=${RPC_URL} && node util/register-one-operator.js

.PHONY: generate-one-operator register-one-operator