// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import {LaunchToken} from "./LaunchToken.sol";

contract LaunchpadFactory {
    address[] tokens;
    uint256 launchFee;
    uint8 private constant MIN_PAIR_TOKEN_DECIMALS;
    uint8 private constant MIN_LAUNCH_SUPPLY;

    struct TokenParams {
        string name;
        string symbol;
    }

    constructor() {
        launchFee = 1.0; //some eth or something, maybe
    }
}
