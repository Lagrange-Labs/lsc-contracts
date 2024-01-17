pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISlasher} from "eigenlayer-contracts/src/contracts/interfaces/ISlasher.sol";
import {IStrategyManager} from "eigenlayer-contracts/src/contracts/interfaces/IStrategyManager.sol";
import {EmptyContract} from "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";
import {IServiceManager} from "eigenlayer-middleware/interfaces/IServiceManager.sol";

import {LagrangeService} from "../contracts/protocol/LagrangeService.sol";
import {LagrangeServiceManager} from "../contracts/protocol/LagrangeServiceManager.sol";
import {LagrangeCommittee} from "../contracts/protocol/LagrangeCommittee.sol";
import {EvidenceVerifier} from "../contracts/protocol/EvidenceVerifier.sol";

import {IStakeManager} from "../contracts/interfaces/IStakeManager.sol";
import {IVoteWeigher} from "../contracts/interfaces/IVoteWeigher.sol";

import {VoteWeigherBaseMock} from "../contracts/mock/VoteWeigherBaseMock.sol";
import {StakeManager} from "../contracts/library/StakeManager.sol";

import {ISlashingSingleVerifier} from "../contracts/interfaces/ISlashingSingleVerifier.sol";
import {Verifier} from "../contracts/library/slashing_single/verifier.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IOutbox} from "../contracts/mock/arbitrum/IOutbox.sol";
import {Outbox} from "../contracts/mock/arbitrum/Outbox.sol";
import {L2OutputOracle} from "../contracts/mock/optimism/L2OutputOracle.sol";
import {IL2OutputOracle} from "../contracts/mock/optimism/IL2OutputOracle.sol";

contract Deploy is Script, Test {
    string public deployDataPath = string(bytes("script/output/deployed_mock.json"));
    string public serviceDataPath = string(bytes("config/LagrangeService.json"));

    address public slasherAddress;
    address public strategyManagerAddress;

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
    EvidenceVerifier public evidenceVerifier;
    EvidenceVerifier public evidenceVerifierImp;

    EmptyContract public emptyContract;

    function run() public {
        string memory configData = vm.readFile(serviceDataPath);

        bool isNative = stdJson.readBool(configData, ".isNative");
        bool isMock = stdJson.readBool(configData, ".isMock");

        if (!isMock) {
            deployDataPath = string(bytes("script/output/M1_deployment_data.json"));
        }
        string memory deployData = vm.readFile(deployDataPath);

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
        evidenceVerifier = EvidenceVerifier(
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
        evidenceVerifierImp = new EvidenceVerifier(
            lagrangeCommittee,
            lagrangeServiceManager
        );

        // upgrade proxy contracts
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))),
            address(lagrangeCommitteeImp),
            abi.encodeWithSelector(LagrangeCommittee.initialize.selector, msg.sender)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeServiceManager))),
            address(lagrangeServiceManagerImp),
            abi.encodeWithSelector(LagrangeServiceManager.initialize.selector, msg.sender)
        );

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeService))),
            address(lagrangeServiceImp),
            abi.encodeWithSelector(LagrangeService.initialize.selector, msg.sender, evidenceVerifier)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(evidenceVerifier))),
            address(evidenceVerifierImp),
            abi.encodeWithSelector(EvidenceVerifier.initialize.selector, msg.sender)
        );

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
        vm.serializeAddress(deployed_addresses, "evidenceVerifier", address(evidenceVerifier));
        vm.serializeAddress(deployed_addresses, "evidenceVerifierImp", address(evidenceVerifierImp));

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
