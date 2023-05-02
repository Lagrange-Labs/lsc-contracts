PRIVATE_KEY=0x3e17bc938ec10c865fc4e2d049902716dc0712b5b0e688b7183c16807234a84c

# Run ethereum nodes
run-geth:
	cd docker && DEV_PERIOD=1 docker-compose up -d geth

run-ganache:
	ganache --db ./ganache-db/chaindata

.PHONY: run-ganache run-geth

# Deploy contracts

deploy-eigenlayer:
	cd lib/eigenlayer-contracts && forge script script/M1_Deploy.s.sol:Deployer_M1 --rpc-url http://localhost:8545  --private-key $(PRIVATE_KEY) --broadcast -vvvv

deploy-weth9:
	forge script script/DeployWETH9.s.sol:DeployWETH9 --rpc-url http://localhost:8545 --private-key 0x3e17bc938ec10c865fc4e2d049902716dc0712b5b0e688b7183c16807234a84c --broadcast -vvvvv

register-operator:
	forge script script/RegisterOperator.s.sol:RegisterOperator --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) --broadcast -vvvvv

deploy-lagrange:
	forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) --broadcast -vvvvv

.PHONY: deploy-weth9 deploy-eigenlayer  register-operator deploy-lagrange

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
	