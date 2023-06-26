PRIVATE_KEY=0x3e17bc938ec10c865fc4e2d049902716dc0712b5b0e688b7183c16807234a84c

# Run ethereum nodes
run-geth:
	cd docker && DEV_PERIOD=1 docker-compose up -d geth

init-accounts:
	cd docker && npm run init-accounts

#.PHONY: run-geth init-accounts
#.PHONY: init-accounts

# Deploy contracts

deploy-eigenlayer:
	forge script script/localnet/M1_Deploy.s.sol:Deployer_M1 --rpc-url http://localhost:8545  --private-key $(PRIVATE_KEY) --broadcast -vvvv

export-abi:
	node util/export_abis.js

deploy-weth9:
	forge script script/localnet/DeployWETH9.s.sol:DeployWETH9 --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) --broadcast -vvvvv

add-strategy:
	forge script script/localnet/AddStrategy.s.sol:AddStrategy --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) --broadcast -vvvvv

register-operator:
	cd docker && npm run register-operator

register-lagrange:
	cd docker && npm run register-lagrange

deploy-poseidon:
	node util/deploy_poseidon.js

deploy-lagrange:
	forge script script/Deploy_LGR.s.sol:Deploy --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) --broadcast -vvvvv

add-quorum:
	forge script script/Add_Quorum.s.sol:AddQuorum --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) --broadcast -vvvvv

init-committee:
	forge script script/Init_Committee.s.sol:InitCommittee --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) --broadcast -vvvvv

.PHONY: deploy-weth9 deploy-eigenlayer add-strategy register-operator register-lagrange deploy-poseidon deploy-lagrange add-quorum init-committee

# Build docker image

stop:
	cd docker && docker-compose down --remove-orphans

docker-build: stop
	cd docker && sudo docker build . -t lagrange/contracts

.PHONY: docker-build stop run-docker

# Test
test:
	docker run -p 8545:8545 -d lagrange/contracts
	sleep 3
	forge test --rpc-url http://localhost:8545  -vvvvv
	docker ps -q --filter ancestor="lagrange/contracts" | xargs -r docker rm -f
.PHONY: test

