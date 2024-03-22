// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {EmptyContract} from "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";

import "../../contracts/protocol/LagrangeService.sol";
import "../../contracts/protocol/LagrangeCommittee.sol";
import "../../contracts/protocol/EvidenceVerifier.sol";
import "../../contracts/protocol/VoteWeigher.sol";
import "../../contracts/library/StakeManager.sol";
import {ILagrangeService} from "../../contracts/interfaces/ILagrangeService.sol";

import {WETH9} from "../../contracts/mock/WETH9.sol";

// This contract is used to deploy LagrangeService contract to the testnet
contract LagrangeDeployer is Test {
    LagrangeService public lagrangeService;
    LagrangeService public lagrangeServiceImp;
    LagrangeCommittee public lagrangeCommittee;
    LagrangeCommittee public lagrangeCommitteeImp;
    StakeManager public stakeManager;
    StakeManager public stakeManagerImp;
    EvidenceVerifier public evidenceVerifier;
    EvidenceVerifier public evidenceVerifierImp;
    address public voteWeigher;
    VoteWeigher public voteWeigherImp;

    WETH9 public token;
    ProxyAdmin public proxyAdmin;
    EmptyContract public emptyContract;

    uint32 public constant CHAIN_ID = 1337;
    uint256 public constant START_EPOCH = 30;
    uint256 public constant EPOCH_PERIOD = 70;
    uint256 public constant FREEZE_DURATION = 10;

    function setUp() public {
        _deployLagrangeContracts();
        // _registerChain();
    }

    function testDeploy() public view {
        console.log("LagrangeService: ", address(lagrangeService));
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
        voteWeigher = address(new MockedVoteWeigher());
        stakeManager = StakeManager(
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

        // deploy implementation contracts
        lagrangeCommitteeImp = new LagrangeCommittee(
                ILagrangeService(sender),
                IVoteWeigher(voteWeigher)
            );
        stakeManagerImp = new StakeManager(
                sender
            );
        evidenceVerifierImp = new EvidenceVerifier(
            lagrangeCommittee,
            stakeManager
        );

        // upgrade proxy contracts
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(lagrangeCommittee))),
            address(lagrangeCommitteeImp),
            abi.encodeWithSelector(LagrangeCommittee.initialize.selector, sender)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(stakeManager))),
            address(stakeManagerImp),
            abi.encodeWithSelector(StakeManager.initialize.selector, sender)
        );
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(evidenceVerifier))),
            address(evidenceVerifierImp),
            abi.encodeWithSelector(StakeManager.initialize.selector, sender)
        );

        vm.stopPrank();
    }

    // function _registerChain() internal {
    //     vm.roll(START_EPOCH);
    //     vm.startPrank(vm.addr(1));

    //     // register chains
    //     lagrangeCommittee.registerChain(CHAIN_ID, EPOCH_PERIOD, FREEZE_DURATION, 0);
    //     lagrangeCommittee.registerChain(CHAIN_ID + 1, EPOCH_PERIOD * 2, FREEZE_DURATION * 2, 0);
    //     // register token multiplier
    //     IVoteWeigher.TokenMultiplier[] memory multipliers = new IVoteWeigher.TokenMultiplier[](1);
    //     multipliers[0] = IVoteWeigher.TokenMultiplier(address(token), 1e9);
    //     voteWeigher.addQuorumMultiplier(0, multipliers);

    //     // add tokens to whitelist
    //     address[] memory tokens = new address[](1);
    //     tokens[0] = address(token);
    //     stakeManager.addTokensToWhitelist(tokens);

    //     vm.stopPrank();
    // }
}


contract MockedVoteWeigher {
    constructor() {}

    function weightOfOperator(
        uint8 quorumNumber,
        address operator
    ) external returns (uint96) {
        return 6000;
    }
}