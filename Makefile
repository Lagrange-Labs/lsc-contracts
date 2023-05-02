register-operator:
	forge script script/RegisterOperator.s.sol:RegisterOperator --rpc-url http://localhost:8545 --private-key 0x49f6a64a011a6cd2e84d66396be15299ee9ad07a5c45daed40db37f6128a268e --broadcast -vvvvv
.PHONY: register-operator

deploy-lagrange:
	forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --private-key 0x49f6a64a011a6cd2e84d66396be15299ee9ad07a5c45daed40db37f6128a268e --broadcast -vvvvv
.PHONY: deploy-lagrange


run-ganache:
	ganache --db ./ganache-db/chaindata
.PHONY: run-ganache