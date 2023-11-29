// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {EmptyContract} from "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";

import "src/protocol/LagrangeService.sol";
import "src/protocol/LagrangeServiceManager.sol";
import "src/protocol/LagrangeCommittee.sol";
import "src/library/StakeManager.sol";
import "src/library/HermezHelpers.sol";

import {Verifier} from "src/library/slashing_single/verifier.sol";
import {ISlashingSingleVerifier} from "src/interfaces/ISlashingSingleVerifier.sol";

import {WETH9} from "src/mock/WETH9.sol";

// This contract is used to deploy LagrangeService contract to the testnet
contract LagrangeDeployer is Test {
    LagrangeService public lagrangeService;
    LagrangeService public lagrangeServiceImp;
    LagrangeServiceManager public lagrangeServiceManager;
    LagrangeServiceManager public lagrangeServiceManagerImp;
    LagrangeCommittee public lagrangeCommittee;
    LagrangeCommittee public lagrangeCommitteeImp;
    StakeManager public stakeManager;
    StakeManager public stakeManagerImp;
    EvidenceVerifier public evidenceVerifier;

    WETH9 public token;
    ProxyAdmin public proxyAdmin;
    EmptyContract public emptyContract;

    uint32 public constant CHAIN_ID = 1337;
    uint256 public constant START_EPOCH = 30;
    uint256 public constant EPOCH_PERIOD = 70;
    uint256 public constant FREEZE_DURATION = 10;

    function setUp() public {
        _deployLagrangeContracts();
        _registerChain();
    }

    function testDeploy() public view {
        console.log("LagrangeServiceManager: ", address(lagrangeServiceManager));
    }

    function _deployLagrangeContracts() internal {
        address sender = vm.addr(1);
        vm.startPrank(sender);

        // deploy proxy admin for ability to upgrade proxy contracts
        proxyAdmin = new ProxyAdmin();
        token = new WETH9();

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
        stakeManager = StakeManager(
            address(
                new TransparentUpgradeableProxy(
                        address(emptyContract),
                        address(proxyAdmin),
                        ""
                    )
            )
        );

        // deploy implementation contracts
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
        lagrangeServiceImp = new LagrangeService(
            lagrangeCommittee,
            lagrangeServiceManager
        );

        // upgrade proxy contracts
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))),
            address(lagrangeCommitteeImp),
            abi.encodeWithSelector(
                LagrangeCommittee.initialize.selector,
                sender,
                new PoseidonUnit1(),
                new PoseidonUnit2(),
                new PoseidonUnit3(),
                new PoseidonUnit4(),
                new PoseidonUnit5(),
                new PoseidonUnit6()
            )
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeServiceManager))),
            address(lagrangeServiceManagerImp),
            abi.encodeWithSelector(LagrangeServiceManager.initialize.selector, sender)
        );

        evidenceVerifier = new EvidenceVerifier();

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeService))),
            address(lagrangeServiceImp),
            abi.encodeWithSelector(LagrangeService.initialize.selector, sender, evidenceVerifier)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(stakeManager))),
            address(stakeManagerImp),
            abi.encodeWithSelector(StakeManager.initialize.selector, sender)
        );

        vm.stopPrank();
    }

    function _registerChain() internal {
        vm.roll(START_EPOCH);
        vm.startPrank(vm.addr(1));

        // register chains
        lagrangeCommittee.registerChain(CHAIN_ID, EPOCH_PERIOD, FREEZE_DURATION);
        lagrangeCommittee.registerChain(CHAIN_ID + 1, EPOCH_PERIOD * 2, FREEZE_DURATION * 2);
        // register token multiplier
        stakeManager.setTokenMultiplier(address(token), 1e9);
        // register quorum
        uint8[] memory quorumIndexes = new uint8[](1);
        quorumIndexes[0] = 0;
        stakeManager.setQuorumIndexes(1, quorumIndexes);

        vm.stopPrank();
    }
}
