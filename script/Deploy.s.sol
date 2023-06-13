pragma solidity =0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategy.sol";
import {StrategyManager} from "eigenlayer-contracts/core/StrategyManager.sol";
import {IDelegationTerms} from "eigenlayer-contracts/interfaces/IDelegationTerms.sol";
import {IServiceManager} from "eigenlayer-contracts/interfaces/IServiceManager.sol";
import {DelegationManager} from "eigenlayer-contracts/core/DelegationManager.sol";

import {Slasher} from "eigenlayer-contracts/core/Slasher.sol";
import {LagrangeServiceManager} from "src/protocol/LagrangeServiceManager.sol";
import {LagrangeService} from "src/protocol/LagrangeService.sol";
import {LagrangeCommittee} from "src/protocol/LagrangeCommittee.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Deploy is Script, Test {
    string public deployDataPath =
        string(
            bytes(
                "lib/eigenlayer-contracts/script/output/M1_deployment_data.json"
            )
        );
    string public poseidonDataPath =
        string(
            bytes(
                "util/output/poseidonAddresses.json"
            )
        );
    string public serviceDataPath =
        string(
            bytes(
                "config/LagrangeService.json"
            )
        );
        
    address WETHStrategyAddress;
    address IServiceManagerAddress;
    
    function deployLagrangeCommittee() public returns (LagrangeCommittee) {
        string memory poseidonData = vm.readFile(poseidonDataPath);
        // Load Poseidon contract addresses
        address poseidon2 = stdJson.readAddress(poseidonData, ".2");
        address poseidon3 = stdJson.readAddress(poseidonData, ".3");
        address poseidon4 = stdJson.readAddress(poseidonData, ".4");
        // Initialize and deploy LagrangeCommittee
        LagrangeCommittee lagrangeCommittee = new LagrangeCommittee(poseidon2,poseidon3,poseidon4);
        console.log("LagrangeCommittee deployed at: ", address(lagrangeCommittee));
        
        return lagrangeCommittee;
    }

    function deployLagrangeService(LagrangeCommittee lagrangeCommittee) public {
        string memory deployData = vm.readFile(deployDataPath);
        string memory serviceData = vm.readFile(serviceDataPath);

	address[] memory sequencerAddresses = stdJson.readAddressArray(serviceData, ".SequencerAddresses");
	uint256 optID = stdJson.readUint(serviceData, ".ChainIDs.optimism");
	uint256 arbID = stdJson.readUint(serviceData, ".ChainIDs.arbitrum");
	uint256 baseID = stdJson.readUint(serviceData, ".ChainIDs.base");
	
        address WETHStractegyAddress = stdJson.readAddress(deployData, ".addresses.strategies.['Wrapped Ether']");
        IStrategy WETHStrategy = IStrategy(WETHStractegyAddress);

        StrategyManager strategyManager = StrategyManager(stdJson.readAddress(deployData, ".addresses.strategyManager"));
        // Load Dependencies
        //IServiceManager ServiceManager = 
        //
        // Deploy LagrangeService
        
        Slasher slasher = Slasher(
            stdJson.readAddress(deployData, ".addresses.slasher")
        );
        LagrangeServiceManager serviceMgr = new LagrangeServiceManager(slasher);
        console.log("LagrangeServiceManager deployed at: ", address(serviceMgr));
        LagrangeService service = new LagrangeService(serviceMgr,lagrangeCommittee,strategyManager,WETHStrategy);
        //service.initialize(lagrangeCommittee/*, serviceManager, wethStrategy*/);
        console.log("LagrangeService deployed at: ", address(service));

        // call optIntoSlashing on slasher
//        slasher.unpause(0);
//        slasher.optIntoSlashing(address(service));

        // register the service
	for(uint32 i = 0; i < sequencerAddresses.length; i++) {
	    service.addSequencer(sequencerAddresses[i]);
            lagrangeCommittee.addSequencer(sequencerAddresses[i]);
	    /*
            service.register(optID, 1, "", 100800);
            service.register(arbID, 1, "", 100800);
            service.register(baseID, 1, "", 100800);
	    */
	}
    }

    function run() public {
        vm.startBroadcast(msg.sender);

	LagrangeCommittee lagrangeCommittee = deployLagrangeCommittee();
	deployLagrangeService(lagrangeCommittee);

        vm.stopBroadcast();
    }
}
