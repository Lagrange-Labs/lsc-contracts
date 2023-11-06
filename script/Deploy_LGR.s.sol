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

import {IStakeManager} from "src/interfaces/IStakeManager.sol";
import {IVoteWeigher} from "src/interfaces/IVoteWeigher.sol";

import {VoteWeigherBaseMock} from "src/mock/VoteWeigherBaseMock.sol";
import {StakeManager} from "src/library/StakeManager.sol";
import {EvidenceVerifier} from "src/library/EvidenceVerifier.sol";
import {OptimismVerifier} from "src/library/OptimismVerifier.sol";
import {ArbitrumVerifier} from "src/library/ArbitrumVerifier.sol";

import {ISlashingSingleVerifier} from "src/interfaces/ISlashingSingleVerifier.sol";
import {Verifier} from "src/library/slashing_single/verifier.sol";

import {SlashingAggregateVerifierTriage} from "src/library/SlashingAggregateVerifierTriage.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IOutbox} from "src/mock/arbitrum/IOutbox.sol";
import {Outbox} from "src/mock/arbitrum/Outbox.sol";
import {L2OutputOracle} from "src/mock/optimism/L2OutputOracle.sol";
import {IL2OutputOracle} from "src/mock/optimism/IL2OutputOracle.sol";

contract Deploy is Script, Test {
    string public deployDataPath = string(bytes("script/output/deployed_mock.json"));
    //string(bytes("script/output/M1_deployment_data.json"));
    string public poseidonDataPath = string(bytes("script/output/deployed_poseidon.json"));
    string public serviceDataPath = string(bytes("config/LagrangeService.json"));

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
    StakeManager public stakeManager;
    StakeManager public stakeManagerImp;
    VoteWeigherBaseMock public voteWeigher;
    VoteWeigherBaseMock public voteWeigherImp;

    EmptyContract public emptyContract;

    EvidenceVerifier public evidenceVerifier;
    OptimismVerifier public optimismVerifier;
    ArbitrumVerifier public arbitrumVerifier;
    Verifier public verifier;

    SlashingAggregateVerifierTriage public AggVerify;
    SlashingAggregateVerifierTriage public AggVerifyImp;

    Outbox public outbox;
    L2OutputOracle public l2oo;

    function run() public {
        string memory deployData = vm.readFile(deployDataPath);
        string memory configData = vm.readFile(serviceDataPath);

        bool isNative = stdJson.readBool(configData, ".isNative");

        if (!isNative) {
            slasherAddress = stdJson.readAddress(deployData, ".addresses.slasher");
            strategyManagerAddress = stdJson.readAddress(deployData, ".addresses.strategyManager");
        }

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

        AggVerify = SlashingAggregateVerifierTriage(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );

        if (isNative) {
            stakeManager = StakeManager(
                address(
                    new TransparentUpgradeableProxy(
                        address(emptyContract),
                        address(proxyAdmin),
                        ""
                    )
                )
            );
        } else {
            voteWeigher = VoteWeigherBaseMock(
                address(
                    new TransparentUpgradeableProxy(
                        address(emptyContract),
                        address(proxyAdmin),
                        ""
                    )
                )
            );
        }
        // deploy implementation contracts
        string memory poseidonData = vm.readFile(poseidonDataPath);
        if (isNative) {
            lagrangeCommitteeImp = new LagrangeCommittee(
                lagrangeService,
                IVoteWeigher(stakeManager)
            );
            lagrangeServiceManagerImp = new LagrangeServiceManager(
                IStakeManager(stakeManager),
                lagrangeCommittee,
                lagrangeService
            );
            stakeManagerImp = new StakeManager(
                address(lagrangeServiceManager),
                5
            );
        } else {
            lagrangeCommitteeImp = new LagrangeCommittee(
                lagrangeService,
                IVoteWeigher(address(voteWeigher))
            );
            lagrangeServiceManagerImp = new LagrangeServiceManager(
                IStakeManager(slasherAddress),
                lagrangeCommittee,
                lagrangeService
            );
            voteWeigherImp = new VoteWeigherBaseMock(
                IServiceManager(address(lagrangeServiceManager)),
                IStrategyManager(strategyManagerAddress)
            );
        }
        lagrangeServiceImp = new LagrangeService(
            lagrangeCommittee,
            lagrangeServiceManager
        );

        verifier = new Verifier();
        AggVerifyImp = new SlashingAggregateVerifierTriage(address(0));

        outbox = new Outbox();
        IL2OutputOracle opt_L2OutputOracle =
            IL2OutputOracle(stdJson.readAddress(configData, ".settlement.opt_l2outputoracle"));
        //L2OutputOracle l2oo = new L2OutputOracle();
        //IL2OutputOracle opt_L2OutputOracle = IL2OutputOracle(l2oo.address);
        //IOutbox arb_Outbox = IOutbox(stdJson.readAddress(configData, ".settlement.arb_outbox"));
        IOutbox arb_Outbox = IOutbox(address(outbox));

        // deploy evidence verifier
        arbitrumVerifier = new ArbitrumVerifier(outbox);
        optimismVerifier = new OptimismVerifier(opt_L2OutputOracle);

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
            TransparentUpgradeableProxy(payable(address(lagrangeServiceManager))),
            address(lagrangeServiceManagerImp),
            abi.encodeWithSelector(LagrangeServiceManager.initialize.selector, msg.sender)
        );

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(AggVerify))),
            address(AggVerifyImp),
            abi.encodeWithSelector(SlashingAggregateVerifierTriage.initialize.selector, msg.sender)
        );

        evidenceVerifier = new EvidenceVerifier(address(verifier));

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeService))),
            address(lagrangeServiceImp),
            abi.encodeWithSelector(LagrangeService.initialize.selector, msg.sender, AggVerify, evidenceVerifier)
        );

        EvidenceVerifier ev = lagrangeService.evidenceVerifier();
        ev.setOptAddr(optimismVerifier);
        ev.setArbAddr(arbitrumVerifier);

        if (isNative) {
            proxyAdmin.upgradeAndCall(
                TransparentUpgradeableProxy(payable(address(stakeManager))),
                address(stakeManagerImp),
                abi.encodeWithSelector(StakeManager.initialize.selector, msg.sender)
            );
        } else {
            proxyAdmin.upgradeAndCall(
                TransparentUpgradeableProxy(payable(address(voteWeigher))),
                address(voteWeigherImp),
                abi.encodeWithSelector(VoteWeigherBaseMock.initialize.selector, msg.sender)
            );

            // opt into the lagrange service manager
            ISlasher(slasherAddress).optIntoSlashing(address(lagrangeServiceManager));
        }

        vm.stopBroadcast();

        // write deployment data to file
        string memory parent_object = "parent object";
        string memory deployed_addresses = "addresses";

        vm.serializeAddress(deployed_addresses, "proxyAdmin", address(proxyAdmin));
        vm.serializeAddress(deployed_addresses, "lagrangeCommitteeImp", address(lagrangeCommitteeImp));
        vm.serializeAddress(deployed_addresses, "lagrangeCommittee", address(lagrangeCommittee));
        vm.serializeAddress(deployed_addresses, "lagrangeServiceImp", address(lagrangeServiceImp));
        vm.serializeAddress(deployed_addresses, "lagrangeService", address(lagrangeService));
        vm.serializeAddress(deployed_addresses, "lagrangeServiceManagerImp", address(lagrangeServiceManagerImp));
        vm.serializeAddress(deployed_addresses, "AggVerify", address(AggVerify));
        vm.serializeAddress(deployed_addresses, "AggVerifyImp", address(AggVerifyImp));

        if (isNative) {
            vm.serializeAddress(deployed_addresses, "stakeManager", address(stakeManager));
            vm.serializeAddress(deployed_addresses, "stakeManagerImp", address(stakeManagerImp));
        } else {
            vm.serializeAddress(deployed_addresses, "voteWeigher", address(voteWeigher));
            vm.serializeAddress(deployed_addresses, "voteWeigherImp", address(voteWeigherImp));
        }
        string memory deployed_output =
            vm.serializeAddress(deployed_addresses, "lagrangeServiceManager", address(lagrangeServiceManager));
        string memory finalJson = vm.serializeString(parent_object, deployed_addresses, deployed_output);
        vm.writeJson(finalJson, "script/output/deployed_lgr.json");
    }
}
