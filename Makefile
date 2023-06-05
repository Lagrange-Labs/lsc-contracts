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
	cd lib/eigenlayer-contracts && forge script script/M1_Deploy.s.sol:Deployer_M1 --rpc-url http://localhost:8545  --private-key $(PRIVATE_KEY) --broadcast -vvvv

eigenlayer-addresses:
	node util/extract_eigenlayer_addresses.js

deploy-weth9:
	forge script script/DeployWETH9.s.sol:DeployWETH9 --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) --broadcast -vvvvv

add-strategy:
	forge script script/AddStrategy.s.sol:AddStrategy --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) --broadcast -vvvvv

register-operator:
	cd docker && npm run register-operator

deploy-poseidon:
	node util/deploy_poseidon.js

deploy-lagrange:
	forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) --broadcast -vvvvv

.PHONY: deploy-weth9 deploy-eigenlayer eigenlayer-addresses add-strategy register-operator deploy-poseidon deploy-lagrange

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

