PRIVATE_KEY?="0x3e17bc938ec10c865fc4e2d049902716dc0712b5b0e688b7183c16807234a84c"
RPC_URL?="http://localhost:8545"

# Run ethereum nodes
run-geth:
	cd docker && DEV_PERIOD=1 docker-compose up -d geth

init-accounts:
	node util/init-accounts.js

generate-accounts: 
	node util/generate-accounts.js

.PHONY: run-geth init-accounts

# Deploy contracts

deploy-eigenlayer:
	forge script script/localnet/M1_Deploy.s.sol:Deployer_M1 --rpc-url ${RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv

deploy-weth9:
	forge script script/localnet/DeployWETH9.s.sol:DeployWETH9 --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv

add-strategy:
	forge script script/localnet/AddStrategy.s.sol:AddStrategy --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv

register-operator:
	export PRIVATE_KEY=${PRIVATE_KEY} && export RPC_URL=${RPC_URL} && node util/register-operator.js

register-lagrange:
	export PRIVATE_KEY=${PRIVATE_KEY} && export RPC_URL=${RPC_URL} && node util/register-lagrange.js

deploy-poseidon:
	export PRIVATE_KEY=${PRIVATE_KEY} && export RPC_URL=${RPC_URL} && node util/deploy_poseidon.js

deploy-lagrange:
	forge script script/Deploy_LGR.s.sol:Deploy --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv

deploy-verifiers:
	export PRIVATE_KEY=${PRIVATE_KEY} && export RPC_URL=${RPC_URL} && npx hardhat run util/deploy-verifiers.js

add-quorum:
	forge script script/Add_Quorum.s.sol:AddQuorum --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv

init-committee:
	forge script script/Init_Committee.s.sol:InitCommittee --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv

deposit-stake:
	export PRIVATE_KEY=${PRIVATE_KEY} && export RPC_URL=${RPC_URL} && node util/deposit-stake.js

.PHONY: deploy-weth9 deploy-eigenlayer add-strategy register-operator register-lagrange deploy-poseidon deploy-lagrange add-quorum init-committee deposit-stake

deploy-register:
	export PRIVATE_KEY=${PRIVATE_KEY} && export RPC_URL=${RPC_URL} && node util/deploy-register.js

deploy-mock:
	forge script script/Deploy_Mock.s.sol:DeployMock --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast -vvvvv

update-config:
	node util/update-config.js

.PHONY: deploy-mock deploy-register update-config

# Build docker image

stop:
	cd docker && docker-compose down --remove-orphans

docker-build: stop
	cd docker && sudo docker build . -t lagrange/contracts

.PHONY: docker-build stop run-docker

# Test
test:
	forge test  -vvvvv
	npx hardhat test
.PHONY: test

clean: stop
	sudo rm -rf docker/geth_db

all: run-geth init-accounts deploy-weth9 deploy-eigenlayer add-strategy register-operator deploy-poseidon deploy-lagrange add-quorum register-lagrange init-committee

all-mock: run-geth init-accounts deploy-mock deploy-poseidon deploy-lagrange update-config add-quorum deploy-register init-committee	

all-native: run-geth init-accounts deploy-weth9 deploy-mock deploy-poseidon deploy-lagrange deploy-verifiers update-config add-quorum deposit-stake deploy-register init-committee	

distribute:
	node util/distributor.js

deploy-native: generate-accounts deploy-weth9 deploy-mock deploy-poseidon deploy-lagrange deploy-verifiers update-config add-quorum distribute deposit-stake deploy-register init-committee

deploy-staging: run-geth init-accounts generate-accounts deploy-weth9 deploy-mock deploy-poseidon deploy-lagrange deploy-verifiers update-config add-quorum deposit-stake deploy-register init-committee

.PHONY: all clean all-mock all-native

# Formatter
format:
	npx prettier --write {test,util}/**/*.js
	forge fmt

.PHONY: format
