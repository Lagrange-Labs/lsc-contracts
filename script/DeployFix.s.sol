pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {EmptyContract} from "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";

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
    ProxyAdmin public proxyAdmin;
    StakeManager public stakeManager;
    StakeManager public stakeManagerImp;

    function run() public {
        vm.startBroadcast();

        proxyAdmin = ProxyAdmin(0x6a13c6f84439C75C2aE7Dd556f5511E394797dFA);
        stakeManager = StakeManager(0x5C2E5b6d53660D6428dB802021d419B01fCf4a31);
        stakeManagerImp = StakeManager(0x3C9A2719166f36B07DB0ABe448fe4a6fb7F1a40c);

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(stakeManager))),
            address(stakeManagerImp),
            abi.encodeWithSelector(StakeManager.initialize.selector, msg.sender)
        );

        vm.stopBroadcast();
    }
}
