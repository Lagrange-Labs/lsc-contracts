pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {EmptyContract} from "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";

import {LagrangeService} from "../contracts/protocol/LagrangeService.sol";
import {VoteWeigher} from "../contracts/protocol/VoteWeigher.sol";
import {LagrangeCommittee} from "../contracts/protocol/LagrangeCommittee.sol";
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
    string public deployDataPath = string(bytes("script/output/deployed_mock.json"));
    string public serviceDataPath = string(bytes("config/LagrangeService.json"));

    address public delegationManagerAddress;

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

        if (!isMock) {
            deployDataPath = string(bytes("script/output/M1_deployment_data.json"));
        }
        string memory deployData = vm.readFile(deployDataPath);

        if (!isNative) {
            delegationManagerAddress = stdJson.readAddress(deployData, ".addresses.delegationManager");
        }

        address avsDirectoryAddress = stdJson.readAddress(deployData, ".addresses.avsDirectory");

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
        lagrangeCommitteeImp = new LagrangeCommittee(lagrangeService, IVoteWeigher(voteWeigher));
        if (isNative) {
            voteWeigherImp = new VoteWeigher(IStakeManager(stakeManager));
            lagrangeServiceImp =
            new LagrangeService(lagrangeCommittee, IStakeManager(stakeManager), avsDirectoryAddress, IVoteWeigher(voteWeigher));
            stakeManagerImp = new StakeManager(address(lagrangeService));
            evidenceVerifierImp = new EvidenceVerifier(lagrangeCommittee, IStakeManager(stakeManager));
        } else {
            voteWeigherImp = new VoteWeigher(IStakeManager(eigenAdapter));
            lagrangeServiceImp =
            new LagrangeService(lagrangeCommittee, IStakeManager(eigenAdapter), avsDirectoryAddress, IVoteWeigher(voteWeigher));
            eigenAdapterImp = new EigenAdapter(address(lagrangeService), IDelegationManager(delegationManagerAddress));
            evidenceVerifierImp = new EvidenceVerifier(lagrangeCommittee, IStakeManager(eigenAdapter));
        }

        // upgrade proxy contracts
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))),
            address(lagrangeCommitteeImp),
            abi.encodeWithSelector(LagrangeCommittee.initialize.selector, msg.sender)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeService))),
            address(lagrangeServiceImp),
            abi.encodeWithSelector(LagrangeService.initialize.selector, msg.sender)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(evidenceVerifier))),
            address(evidenceVerifierImp),
            abi.encodeWithSelector(EvidenceVerifier.initialize.selector, msg.sender)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(voteWeigher))),
            address(voteWeigherImp),
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
                TransparentUpgradeableProxy(payable(address(eigenAdapter))),
                address(eigenAdapterImp),
                abi.encodeWithSelector(EigenAdapter.initialize.selector, msg.sender)
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
