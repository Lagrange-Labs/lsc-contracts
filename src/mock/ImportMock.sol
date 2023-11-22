// SPDX-License-Identifier: UNLICENSED

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";
import {IStrategyManager} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";
import {IServiceManager} from "eigenlayer-contracts/interfaces/IServiceManager.sol";
import {EmptyContract} from "eigenlayer-contracts-test/mocks/EmptyContract.sol";
