// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {INativeStaking} from "../interfaces/INativeStaking.sol";

contract Staking is
    Initializable,
    OwnableUpgradeable,
    INativeStaking
{
    address public AUTH;

    IERC20 public COLLATERAL_TOKEN;
    
    uint256 STAKE_AMOUNT;

    mapping(address => Staker) public stakerStatus;

    constructor() {
        STAKE_AMOUNT = 32 * (10 ** 18);
    }

    function initialize(address _auth, address _collateralToken) external onlyOwner {
        AUTH = _auth;
        COLLATERAL_TOKEN = IERC20(_collateralToken);
    }

    modifier onlyAuth() {
        require(msg.sender == AUTH, "NativeStaking: Sender is not authorized to perform this action.");
        _;
    }

    function _deposit(address stakerAddr) internal onlyAuth {
        require(stakerStatus[stakerAddr].status == STATUS.STATUS_UNSTAKED || uint256(stakerStatus[stakerAddr].status) == 0, "NativeStaking: Address is already staked.");
        require(COLLATERAL_TOKEN.transferFrom(stakerAddr, address(this), STAKE_AMOUNT), "NativeStaking: Failed to transfer token.");

        stakerStatus[stakerAddr] = Staker({
            amount: STAKE_AMOUNT,
            startBlock: block.number,
            status: STATUS.STATUS_ACTIVE
        });
    }

    function register(address stakerAddr) external onlyAuth returns (bool) {
        require(stakerStatus[stakerAddr].status == STATUS.STATUS_UNSTAKED || uint256(stakerStatus[stakerAddr].status) == 0, "NativeStaking: Address is already staked.");
        require(COLLATERAL_TOKEN.balanceOf(stakerAddr) >= STAKE_AMOUNT, "NativeStaking: Insufficient collateral");
        _deposit(stakerAddr);
        return true;
    }

    function unstake(address stakerAddr) external onlyAuth {
        require(stakerStatus[stakerAddr].status == STATUS.STATUS_ACTIVE, "NativeStaking: Address stake is not active.");
        stakerStatus[stakerAddr].status = STATUS.STATUS_PENDING_WITHDRAWAL;
    }

    function withdraw(address stakerAddr) external onlyAuth {
        require(stakerStatus[stakerAddr].status == STATUS.STATUS_PENDING_WITHDRAWAL, "NativeStaking: Address is not pending withdrawal.");
        require(COLLATERAL_TOKEN.transfer(stakerAddr, STAKE_AMOUNT), "NativeStaking: Failed to transfer token.");
        stakerStatus[stakerAddr].amount = 0;
        stakerStatus[stakerAddr].status = STATUS.STATUS_UNSTAKED;
    }

    function slash(address stakerAddr) external onlyAuth {
        require(stakerStatus[stakerAddr].status == STATUS.STATUS_ACTIVE, "NativeStaking: Address is not active.");
        stakerStatus[stakerAddr].status = STATUS.STATUS_SLASHED;
    }

    function getStakerStatus(address stakerAddr) external view returns (Staker memory) {
        return stakerStatus[stakerAddr];
    }
}

