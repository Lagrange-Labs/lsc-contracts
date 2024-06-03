// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {EmptyContract} from "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";
import "../contracts/protocol/LagrangeService.sol";
import "../contracts/protocol/LagrangeCommittee.sol";
import "../contracts/protocol/EvidenceVerifier.sol";
import "../contracts/protocol/VoteWeigher.sol";
import "../contracts/library/StakeManager.sol";
import {WETH9} from "../contracts/mock/WETH9.sol";

contract TestGas is Script {
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
    uint256 constant OPERATOR_COUNT = 1000;
    uint256 constant BLS_PUB_KEY_PER_OPERATOR = 2;

    function run() public {
        _deployLagrangeContracts();
        vm.startPrank(vm.addr(1));
        uint32 chainID = 1;
        lagrangeCommittee.registerChain(chainID, 0, 8000, 2000, 1, 2000, 5000);

        vm.roll(2000);
        console.log("testGasCalc", block.number);

        for (uint256 i; i < OPERATOR_COUNT; i++) {
            address operator = vm.addr(i + 100);
            uint256[2][] memory blsPubKeys = new uint256[2][](BLS_PUB_KEY_PER_OPERATOR);
            for (uint256 j; j < BLS_PUB_KEY_PER_OPERATOR; j++) {
                blsPubKeys[j][0] = 2 * (i * BLS_PUB_KEY_PER_OPERATOR + j) + 100;
                blsPubKeys[j][1] = 2 * (i * BLS_PUB_KEY_PER_OPERATOR + j) + 101;
            }

            lagrangeCommittee.addOperator(operator, operator, blsPubKeys);
            lagrangeCommittee.subscribeChain(operator, chainID);
        }

        vm.roll(7000);

        lagrangeCommittee.update(chainID, 1);
        vm.stopPrank();
    }

    function _deployLagrangeContracts() internal {
        address sender = vm.addr(1);
        vm.startPrank(sender);

        // deploy proxy admin for ability to upgrade proxy contracts
        proxyAdmin = new ProxyAdmin();
        token = new WETH9();

        // deploy upgradeable proxy contracts
        emptyContract = new EmptyContract();
        lagrangeCommittee =
            LagrangeCommittee(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        voteWeigher = address(new MockedVoteWeigher());
        stakeManager =
            StakeManager(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));
        evidenceVerifier =
            EvidenceVerifier(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));

        // deploy implementation contracts
        lagrangeCommitteeImp = new LagrangeCommittee(ILagrangeService(sender), IVoteWeigher(voteWeigher));
        stakeManagerImp = new StakeManager(sender);
        evidenceVerifierImp = new EvidenceVerifier(lagrangeCommittee, stakeManager);

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
}

contract MockedVoteWeigher {
    constructor() {}

    function weightOfOperator(uint8, /*quorumNumber*/ address /*operator*/ ) external pure returns (uint96) {
        return 6000;
    }
}
