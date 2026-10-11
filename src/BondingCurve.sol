// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

contract BondingCurve {
    error ZeroAddress();
    error AlreadyInitialized();
    error Unauthorized();

    address private immutable factoryAddress;
    address public tokenAddress;
    constructor(address factoryAddress_) {
        if (factoryAddress_ == address(0)) revert ZeroAddress();

        factoryAddress = factoryAddress_;
    }

    function initialize(address tokenAddress_) public {
        if (msg.sender != factoryAddress) revert Unauthorized();
        if (tokenAddress_ == address(0)) revert ZeroAddress();
        if (tokenAddress != address(0)) revert AlreadyInitialized();

        tokenAddress = tokenAddress_;
    }
}
