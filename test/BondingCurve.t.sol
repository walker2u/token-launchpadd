// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {LaunchpadFactory} from "../src/LaunchpadFactory.sol";

contract BondingCurveTest is Test {
    function testNonFactory() public {
        address factory = makeAddr("factory");
        address token = makeAddr("token");

        BondingCurve curve = new BondingCurve(factory);
        vm.expectRevert(BondingCurve.Unauthorized.selector);
        curve.initialize(token);
    }

    function testFactoryCanInitialize() public {
        address factory = makeAddr("factory");
        address token = makeAddr("token");

        BondingCurve curve = new BondingCurve(factory);

        vm.prank(factory);
        curve.initialize(token);

        assertEq(curve.tokenAddress(), token);
    }

    function testFactoryCannotInitializeTwice() public {
        address factory = makeAddr("factory");
        address token = makeAddr("token");

        BondingCurve curve = new BondingCurve(factory);

        vm.prank(factory);
        curve.initialize(token);

        vm.expectRevert(BondingCurve.AlreadyInitialized.selector);
        vm.prank(factory);
        curve.initialize(token);
    }
}
