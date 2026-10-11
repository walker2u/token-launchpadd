// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {LaunchToken} from "../src/LaunchToken.sol";

contract LaunchTokenTest is Test {
    function testInitialSupply() public {
        address curve = makeAddr("Curve");
        uint256 supply = 1000000;
        uint256 totalAmount = supply * 10 ** 18;

        LaunchToken token = new LaunchToken("TestToken", "TT", curve, supply);

        assertEq(token.totalSupply(), totalAmount);
        assertEq(token.balanceOf(curve), totalAmount);
    }

    function testRejectsZeroCurve() public {
        address curve = address(0);
        uint256 supply = 1000000;

        vm.expectRevert(LaunchToken.ZeroAddress.selector);
        new LaunchToken("TestToken", "TT", curve, supply);
    }

    function testRejectsZeroSupply() public {
        address curve = makeAddr("Curve");
        uint256 supply = 0;

        vm.expectRevert("Supply must be greater than zero!");
        new LaunchToken("TestToken", "TT", curve, supply);
    }
}
