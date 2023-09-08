// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INativeStaking {
    enum STATUS {
        STATUS_NULL,
        STATUS_ACTIVE, 
        STATUS_PENDING_WITHDRAWAL, 
        STATUS_UNSTAKED, 
        STATUS_SLASHED 
    }
    
    struct Staker {
        uint256 amount;
        uint256 startBlock;
        STATUS status;
    }
    
    function AUTH() external view returns (address);
    function COLLATERAL_TOKEN() external view returns (IERC20);
    
    function initialize(address _auth, address _collateralToken) external;
    function register(address stakerAddr) external returns (bool);
    function unstake(address stakerAddr) external;
    function withdraw(address stakerAddr) external;
    function slash(address stakerAddr) external;
    function getStakerStatus(address stakerAddr) external view returns (Staker memory);
}

