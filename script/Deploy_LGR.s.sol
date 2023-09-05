pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";
import {IStrategyManager} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";
import {IServiceManager} from "eigenlayer-contracts/interfaces/IServiceManager.sol";
import {EmptyContract} from "eigenlayer-contracts-test/mocks/EmptyContract.sol";

import {LagrangeService} from "src/protocol/LagrangeService.sol";
import {LagrangeServiceManager} from "src/protocol/LagrangeServiceManager.sol";
import {LagrangeCommittee} from "src/protocol/LagrangeCommittee.sol";

import {EvidenceVerifier} from "src/library/EvidenceVerifier.sol";
import {OptimismVerifier} from "src/library/OptimismVerifier.sol";
import {ArbitrumVerifier} from "src/library/ArbitrumVerifier.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IOutbox} from "src/mock/arbitrum/IOutbox.sol";
import {Outbox} from "src/mock/arbitrum/Outbox.sol";
import {L2OutputOracle} from "src/mock/optimism/L2OutputOracle.sol";
import {IL2OutputOracle} from "src/mock/optimism/IL2OutputOracle.sol";

contract Deploy is Script, Test {
    string public deployDataPath =
        //string(bytes("script/output/deployed_mock.json"));
        string(bytes("script/output/M1_deployment_data.json"));
    string public poseidonDataPath =
        string(bytes("script/output/deployed_poseidon.json"));
    string public serviceDataPath =
        string(bytes("config/LagrangeService.json"));

    address slasherAddress;
    address strategyManagerAddress;

    // Lagrange Contracts
    ProxyAdmin public proxyAdmin;
    LagrangeCommittee public lagrangeCommittee;
    LagrangeCommittee public lagrangeCommitteeImp;
    LagrangeService public lagrangeService;
    LagrangeService public lagrangeServiceImp;
    LagrangeServiceManager public lagrangeServiceManager;
    LagrangeServiceManager public lagrangeServiceManagerImp;

    EmptyContract public emptyContract;

    EvidenceVerifier public evidenceVerifier;
    OptimismVerifier public optimismVerifier;
    ArbitrumVerifier public arbitrumVerifier;

    function run() public {
        string memory deployData = vm.readFile(deployDataPath);
        string memory configData = vm.readFile(serviceDataPath);
        slasherAddress = stdJson.readAddress(deployData, ".addresses.slasher");
        strategyManagerAddress = stdJson.readAddress(
            deployData,
            ".addresses.strategyManager"
        );

        vm.startBroadcast(msg.sender);

        // deploy proxy admin for ability to upgrade proxy contracts
        proxyAdmin = new ProxyAdmin();

        // deploy upgradeable proxy contracts
        emptyContract = new EmptyContract();
        lagrangeCommittee = LagrangeCommittee(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        lagrangeService = LagrangeService(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        lagrangeServiceManager = LagrangeServiceManager(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );

        // deploy implementation contracts
        string memory poseidonData = vm.readFile(poseidonDataPath);
        lagrangeCommitteeImp = new LagrangeCommittee(
            lagrangeService,
            lagrangeServiceManager,
            IStrategyManager(strategyManagerAddress)
        );
        lagrangeServiceManagerImp = new LagrangeServiceManager(
            ISlasher(slasherAddress),
            lagrangeCommittee,
            lagrangeService
        );

        lagrangeServiceImp = new LagrangeService(
            lagrangeCommittee,
            lagrangeServiceManager
        );

        // L2 Settlement - Interface

        IL2OutputOracle opt_L2OutputOracle = IL2OutputOracle(
            stdJson.readAddress(configData, ".settlement.opt_l2outputoracle")
        );
        IOutbox arb_Outbox = IOutbox(
            stdJson.readAddress(configData, ".settlement.arb_outbox")
        );

        // L2 Settlement - Mock

        //Outbox outbox = new Outbox();
        //IOutbox arb_Outbox = IOutbox(outbox.address);

        //L2OutputOracle l2oo = new L2OutputOracle();
        //IL2OutputOracle opt_L2OutputOracle = IL2OutputOracle(l2oo.address);

        // deploy evidence verifier

        arbitrumVerifier = new ArbitrumVerifier(arb_Outbox);
        optimismVerifier = new OptimismVerifier(opt_L2OutputOracle);
        //evidenceVerifier = new EvidenceVerifier();

        lagrangeServiceImp.setOptAddr(optimismVerifier);
        lagrangeServiceImp.setArbAddr(arbitrumVerifier);

        // upgrade proxy contracts
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))),
            address(lagrangeCommitteeImp),
            abi.encodeWithSelector(
                LagrangeCommittee.initialize.selector,
                msg.sender,
                stdJson.readAddress(poseidonData, ".1"),
                stdJson.readAddress(poseidonData, ".2"),
                stdJson.readAddress(poseidonData, ".3"),
                stdJson.readAddress(poseidonData, ".4"),
                stdJson.readAddress(poseidonData, ".5"),
                stdJson.readAddress(poseidonData, ".6")
            )
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(
                payable(address(lagrangeServiceManager))
            ),
            address(lagrangeServiceManagerImp),
            abi.encodeWithSelector(
                LagrangeServiceManager.initialize.selector,
                msg.sender
            )
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeService))),
            address(lagrangeServiceImp),
            abi.encodeWithSelector(
                LagrangeService.initialize.selector,
                msg.sender
            )
        );

        // opt into the lagrange service manager
        ISlasher(slasherAddress).optIntoSlashing(
            address(lagrangeServiceManager)
        );
        vm.stopBroadcast();

        // write deployment data to file
        string memory parent_object = "parent object";
        string memory deployed_addresses = "addresses";
        vm.serializeAddress(
            deployed_addresses,
            "proxyAdmin",
            address(proxyAdmin)
        );
        vm.serializeAddress(
            deployed_addresses,
            "lagrangeCommitteeImp",
            address(lagrangeCommitteeImp)
        );
        vm.serializeAddress(
            deployed_addresses,
            "lagrangeCommittee",
            address(lagrangeCommittee)
        );
        vm.serializeAddress(
            deployed_addresses,
            "lagrangeServiceImp",
            address(lagrangeServiceImp)
        );
        vm.serializeAddress(
            deployed_addresses,
            "lagrangeService",
            address(lagrangeService)
        );
        vm.serializeAddress(
            deployed_addresses,
            "lagrangeServiceManagerImp",
            address(lagrangeServiceManagerImp)
        );
        string memory deployed_output = vm.serializeAddress(
            deployed_addresses,
            "lagrangeServiceManager",
            address(lagrangeServiceManager)
        );
        string memory finalJson = vm.serializeString(
            parent_object,
            deployed_addresses,
            deployed_output
        );
        vm.writeJson(finalJson, "script/output/deployed_lgr.json");
    }
}
