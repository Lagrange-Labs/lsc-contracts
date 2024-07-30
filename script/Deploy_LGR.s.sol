pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {EmptyContract} from "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";

import {LagrangeService} from "../contracts/protocol/LagrangeService.sol";
import {LagrangeServiceTestnet} from "../contracts/protocol/testnet/LagrangeServiceTestnet.sol"; // for sepolia
import {VoteWeigher} from "../contracts/protocol/VoteWeigher.sol";
import {LagrangeCommittee} from "../contracts/protocol/LagrangeCommittee.sol";
import {LagrangeCommitteeTestnet} from "../contracts/protocol/testnet/LagrangeCommitteeTestnet.sol"; // for holesky
import {EvidenceVerifier} from "../contracts/protocol/EvidenceVerifier.sol";

import {IStakeManager} from "../contracts/interfaces/IStakeManager.sol";
import {IVoteWeigher} from "../contracts/interfaces/IVoteWeigher.sol";

import {EigenAdapter} from "../contracts/library/EigenAdapter.sol";
import {StakeManager} from "../contracts/library/StakeManager.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IOutbox} from "../contracts/mock/arbitrum/IOutbox.sol";
import {Outbox} from "../contracts/mock/arbitrum/Outbox.sol";
import {L2OutputOracle} from "../contracts/mock/optimism/L2OutputOracle.sol";
import {IL2OutputOracle} from "../contracts/mock/optimism/IL2OutputOracle.sol";

contract Deploy is Script, Test {
    string public deployMockDataPath = string(bytes("script/output/deployed_mock.json"));
    string public deployDataPath = string(bytes("script/output/M1_deployment_data.json"));
    string public serviceDataPath = string(bytes("config/LagrangeService.json"));

    address public ownerMultisig;
    address public delegationManagerAddress;
    address public avsDirectoryAddress;

    // Lagrange Contracts
    ProxyAdmin public proxyAdmin;
    LagrangeCommittee public lagrangeCommittee;
    LagrangeCommittee public lagrangeCommitteeImp;
    LagrangeService public lagrangeService;
    LagrangeService public lagrangeServiceImp;
    VoteWeigher public voteWeigher;
    VoteWeigher public voteWeigherImp;
    StakeManager public stakeManager;
    StakeManager public stakeManagerImp;
    EigenAdapter public eigenAdapter;
    EigenAdapter public eigenAdapterImp;
    EvidenceVerifier public evidenceVerifier;
    EvidenceVerifier public evidenceVerifierImp;

    EmptyContract public emptyContract;

    function run() public {
        string memory configData = vm.readFile(serviceDataPath);

        bool isNative = stdJson.readBool(configData, ".isNative");
        bool isMock = stdJson.readBool(configData, ".isMock");

        ownerMultisig = stdJson.readAddress(configData, ".ownerMultisig");

        console.log("ChainID: ", block.chainid);

        if (block.chainid == 1337 || block.chainid == 11155111) {
            // local
            if (isMock) {
                string memory deployData = vm.readFile(deployMockDataPath);
                delegationManagerAddress = stdJson.readAddress(deployData, ".addresses.delegationManager");
                avsDirectoryAddress = stdJson.readAddress(deployData, ".addresses.avsDirectory");
            } else {
                string memory deployData = vm.readFile(deployDataPath);
                if (!isNative) {
                    delegationManagerAddress = stdJson.readAddress(deployData, ".addresses.delegation");
                }
                avsDirectoryAddress = stdJson.readAddress(deployData, ".addresses.avsDirectory");
            }
            console.log(delegationManagerAddress, avsDirectoryAddress);

            ownerMultisig = msg.sender;
        } else if (block.chainid == 1) {
            // mainnet
            if (!isNative) {
                delegationManagerAddress = stdJson.readAddress(configData, ".eigenlayer_addresses.mainnet.delegation");
            }
            avsDirectoryAddress = stdJson.readAddress(configData, ".eigenlayer_addresses.mainnet.avsDirectory");
            console.log(delegationManagerAddress, avsDirectoryAddress);
        } else if (block.chainid == 17000) {
            // holesky
            if (!isNative) {
                delegationManagerAddress = stdJson.readAddress(configData, ".eigenlayer_addresses.holesky.delegation");
            }
            avsDirectoryAddress = stdJson.readAddress(configData, ".eigenlayer_addresses.holesky.avsDirectory");
            console.log(delegationManagerAddress, avsDirectoryAddress);
        }

        vm.startBroadcast(msg.sender);

        // deploy proxy admin for ability to upgrade proxy contracts
        proxyAdmin = new ProxyAdmin();

        // deploy upgradeable proxy contracts
        emptyContract = new EmptyContract();
        lagrangeCommittee =
            LagrangeCommittee(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        lagrangeService =
            LagrangeService(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        evidenceVerifier =
            EvidenceVerifier(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        voteWeigher =
            VoteWeigher(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        if (isNative) {
            stakeManager =
                StakeManager(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        } else {
            eigenAdapter =
                EigenAdapter(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        }
        // deploy implementation contracts
        if (block.chainid == 17000) {
            lagrangeCommitteeImp =
                LagrangeCommittee(address(new LagrangeCommitteeTestnet(lagrangeService, IVoteWeigher(voteWeigher))));
        } else {
            lagrangeCommitteeImp = new LagrangeCommittee(lagrangeService, IVoteWeigher(voteWeigher));
        }
        if (isNative) {
            voteWeigherImp = new VoteWeigher(IStakeManager(stakeManager));
            if (block.chainid == 11155111) {
                lagrangeServiceImp = LagrangeService(
                    address(
                        new LagrangeServiceTestnet(
                            lagrangeCommittee,
                            IStakeManager(stakeManager),
                            avsDirectoryAddress,
                            IVoteWeigher(voteWeigher)
                        )
                    )
                );
            } else {
                lagrangeServiceImp = new LagrangeService(
                    lagrangeCommittee, IStakeManager(stakeManager), avsDirectoryAddress, IVoteWeigher(voteWeigher)
                );
            }
            stakeManagerImp = new StakeManager(address(lagrangeService));
            evidenceVerifierImp = new EvidenceVerifier(lagrangeCommittee, IStakeManager(stakeManager));
        } else {
            voteWeigherImp = new VoteWeigher(IStakeManager(eigenAdapter));
            if (block.chainid == 11155111) {
                lagrangeServiceImp = LagrangeService(
                    address(
                        new LagrangeServiceTestnet(
                            lagrangeCommittee,
                            IStakeManager(eigenAdapter),
                            avsDirectoryAddress,
                            IVoteWeigher(voteWeigher)
                        )
                    )
                );
            } else {
                lagrangeServiceImp = new LagrangeService(
                    lagrangeCommittee, IStakeManager(eigenAdapter), avsDirectoryAddress, IVoteWeigher(voteWeigher)
                );
            }
            eigenAdapterImp = new EigenAdapter(address(lagrangeService), IDelegationManager(delegationManagerAddress));
            evidenceVerifierImp = new EvidenceVerifier(lagrangeCommittee, IStakeManager(eigenAdapter));
        }

        // upgrade proxy contracts
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))),
            address(lagrangeCommitteeImp),
            abi.encodeWithSelector(LagrangeCommittee.initialize.selector, ownerMultisig)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeService))),
            address(lagrangeServiceImp),
            abi.encodeWithSelector(LagrangeService.initialize.selector, ownerMultisig)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(evidenceVerifier))),
            address(evidenceVerifierImp),
            abi.encodeWithSelector(EvidenceVerifier.initialize.selector, ownerMultisig)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(voteWeigher))),
            address(voteWeigherImp),
            abi.encodeWithSelector(EvidenceVerifier.initialize.selector, ownerMultisig)
        );
        if (isNative) {
            proxyAdmin.upgradeAndCall(
                TransparentUpgradeableProxy(payable(address(stakeManager))),
                address(stakeManagerImp),
                abi.encodeWithSelector(StakeManager.initialize.selector, ownerMultisig)
            );
        } else {
            proxyAdmin.upgradeAndCall(
                TransparentUpgradeableProxy(payable(address(eigenAdapter))),
                address(eigenAdapterImp),
                abi.encodeWithSelector(EigenAdapter.initialize.selector, ownerMultisig)
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
        vm.serializeAddress(deployed_addresses, "evidenceVerifier", address(evidenceVerifier));
        vm.serializeAddress(deployed_addresses, "evidenceVerifierImp", address(evidenceVerifierImp));
        vm.serializeAddress(deployed_addresses, "voteWeigher", address(voteWeigher));

        if (isNative) {
            vm.serializeAddress(deployed_addresses, "stakeManager", address(stakeManager));
            vm.serializeAddress(deployed_addresses, "stakeManagerImp", address(stakeManagerImp));
        } else {
            vm.serializeAddress(deployed_addresses, "stakeManager", address(eigenAdapter));
            vm.serializeAddress(deployed_addresses, "stakeManagerImp", address(eigenAdapterImp));
        }
        string memory deployed_output =
            vm.serializeAddress(deployed_addresses, "voteWeigherImp", address(voteWeigherImp));
        string memory finalJson = vm.serializeString(parent_object, deployed_addresses, deployed_output);
        vm.writeJson(finalJson, "script/output/deployed_lgr.json");
    }
}
