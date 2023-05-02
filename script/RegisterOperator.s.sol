pragma solidity =0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategy.sol";
import {StrategyManager} from "eigenlayer-contracts/core/StrategyManager.sol";
import {IDelegationTerms} from "eigenlayer-contracts/interfaces/IDelegationTerms.sol";
import {DelegationManager} from "eigenlayer-contracts/core/DelegationManager.sol";

import {Slasher} from "eigenlayer-contracts/core/Slasher.sol";
import {LagrangeService} from "src/LagrangeService.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RegisterOperator is Script, Test {
    string public deployDataPath = string(bytes("lib/eigenlayer-contracts/script/output/M1_deployment_data.json"));
    address WETHStractegyAddress;
    bytes4 private constant WETH_DEPOSIT_SELECTOR = bytes4(keccak256(bytes('deposit()')));
    address private constant WETH_ADDRESS = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    function run() public {
        vm.startBroadcast(msg.sender);

        string memory deployData = vm.readFile(deployDataPath);
        WETHStractegyAddress = stdJson.readAddress(deployData, ".addresses.strategies.WETH");
        StrategyManager strategyManager = StrategyManager(stdJson.readAddress(deployData, ".addresses.strategyManager"));

        IStrategy WETHStrategy = IStrategy(WETHStractegyAddress);
        IERC20 WETH = WETHStrategy.underlyingToken();

        // send 1e20 wei to the rocket pool contract
        (bool success, ) = address(WETH_ADDRESS).call{value: 1e19}(abi.encodeWithSelector(WETH_DEPOSIT_SELECTOR));
        require(success, "WETH deposit failed");


        // add strategy to strategy manager
        strategyManager.setStrategyWhitelister(msg.sender);

        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = WETHStrategy;
        strategyManager.addStrategiesToDepositWhitelist(strategies);

        // Approve strategy manager to spend tsETH        
        WETH.approve(address(strategyManager), 1e30);
        strategyManager.depositIntoStrategy(WETHStrategy, WETH, 1e18);

        // register an operator
        DelegationManager delegation = DelegationManager(stdJson.readAddress(deployData, ".addresses.delegation"));
        delegation.unpause(0);
        delegation.registerAsOperator(IDelegationTerms(msg.sender));


        // Deploy LagrangeService
        Slasher slasher = Slasher(stdJson.readAddress(deployData, ".addresses.slasher"));
        LagrangeService service = new LagrangeService(slasher);

        // call optIntoSlashing on slasher
        slasher.unpause(0);
        slasher.optIntoSlashing(address(service));

        // register the service
        service.register(type(uint32).max);
        
        vm.stopBroadcast();

        // test slashing
        vm.prank(msg.sender);
        service.freezeOperator(msg.sender);
        require(service.isFrozen(msg.sender), "operator should be frozen");
    }
}
