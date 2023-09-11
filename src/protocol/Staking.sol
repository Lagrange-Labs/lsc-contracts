// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {IStaking} from "../interfaces/IStaking.sol";

contract Staking is Initializable, OwnableUpgradeable, IStaking {
    address public AUTH;

    IERC20 public COLLATERAL_TOKEN;

    uint256 STAKE_AMOUNT = 32 * (10 ** 18);

    mapping(address => Staker) public stakerStatus;

    constructor() {
        _transferOwnership(msg.sender);
        _disableInitializers();
    }

    function initialize(
        address _auth,
        address _collateralToken
    ) external initializer {
        AUTH = _auth;
        COLLATERAL_TOKEN = IERC20(_collateralToken);
    }

    modifier onlyAuth() {
        require(
            msg.sender == AUTH,
            "Staking: Sender is not authorized to perform this action."
        );
        _;
    }

    function _deposit(address stakerAddr) internal onlyAuth {
        require(
            stakerStatus[stakerAddr].status == STATUS.STATUS_UNSTAKED ||
                uint256(stakerStatus[stakerAddr].status) == 0,
            "Staking: Address is already staked."
        );
        require(
            COLLATERAL_TOKEN.transferFrom(
                stakerAddr,
                address(this),
                STAKE_AMOUNT
            ),
            "Staking: Failed to transfer token."
        );

        stakerStatus[stakerAddr] = Staker({
            amount: STAKE_AMOUNT,
            startBlock: block.number,
            status: STATUS.STATUS_ACTIVE
        });
    }

    function register(address stakerAddr) external onlyAuth returns (bool) {
        require(
            stakerStatus[stakerAddr].status == STATUS.STATUS_UNSTAKED ||
                uint256(stakerStatus[stakerAddr].status) == 0,
            "Staking: Address is already staked."
        );
        require(
            COLLATERAL_TOKEN.balanceOf(stakerAddr) >= STAKE_AMOUNT,
            "Staking: Insufficient collateral"
        );
        _deposit(stakerAddr);
        return true;
    }

    function unstake(address stakerAddr) external onlyAuth {
        require(
            stakerStatus[stakerAddr].status == STATUS.STATUS_ACTIVE,
            "Staking: Address stake is not active."
        );
        stakerStatus[stakerAddr].status = STATUS.STATUS_PENDING_WITHDRAWAL;
    }

    function withdraw(address stakerAddr) external /*onlyAuth*/ {
        require(
            stakerStatus[stakerAddr].status == STATUS.STATUS_PENDING_WITHDRAWAL,
            "Staking: Address is not pending withdrawal."
        );
        require(
            COLLATERAL_TOKEN.transfer(stakerAddr, STAKE_AMOUNT),
            "Staking: Failed to transfer token."
        );
        stakerStatus[stakerAddr].amount = 0;
        stakerStatus[stakerAddr].status = STATUS.STATUS_UNSTAKED;
    }

    function slash(address stakerAddr) external onlyAuth {
        require(
            stakerStatus[stakerAddr].status == STATUS.STATUS_ACTIVE,
            "Staking: Address is not active."
        );
        stakerStatus[stakerAddr].status = STATUS.STATUS_SLASHED;
    }

    function getStakerStatus(
        address stakerAddr
    ) external view returns (Staker memory) {
        return stakerStatus[stakerAddr];
    }
}
