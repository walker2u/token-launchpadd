// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LaunchToken is ERC20 {
    error ZeroAddress();

    constructor(
        string memory name_,
        string memory symbol_,
        address curve_,
        uint256 supply_
    ) ERC20(name_, symbol_) {
        if (curve_ == address(0)) revert ZeroAddress();
        if (bytes(name_).length == 0 || bytes(symbol_).length == 0)
            revert("Name or Symbol is Empty!");
        if (supply_ <= 0) revert("Supply must be greater than zero!");

        _mint(curve_, supply_ * 10 ** 18);
    }
}
