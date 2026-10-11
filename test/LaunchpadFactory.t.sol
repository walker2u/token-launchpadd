// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {LaunchpadFactory} from "../src/LaunchpadFactory.sol";
import {LaunchToken} from "../src/LaunchToken.sol";
import {BondingCurve} from "../src/BondingCurve.sol";

contract TestLaunchpadFactory is Test {
    LaunchpadFactory public factory;
    address payable public feeRecipient;
    uint256 public constant LAUNCH_FEE = 0.01 ether;

    function setUp() public {
        feeRecipient = payable(makeAddr("feeRecipient"));
        factory = new LaunchpadFactory(LAUNCH_FEE, feeRecipient);
    }

    /// @notice Tests the end-to-end launch flow successfully
    function test_SuccessfulLaunchIntegration() public {
        // Arrange
        address creator = makeAddr("creator");
        vm.deal(creator, 1 ether);

        string memory name = "Meme Token";
        string memory symbol = "MEME";
        string memory metadataURI = "ipfs://QmTestMetadataURI";
        uint256 supplyWholeTokens = 1_000_000;

        LaunchpadFactory.LaunchParams memory params = LaunchpadFactory
            .LaunchParams({
                name: name,
                symbol: symbol,
                metadataURI: metadataURI,
                supplyWholeTokens: supplyWholeTokens
            });

        // Act
        vm.prank(creator);
        (address tokenAddress, address curveAddress) = factory.createLaunch{
            value: LAUNCH_FEE
        }(params);

        // Assert 1: Factory records the token, creator, curve, and metadata URI correctly
        LaunchpadFactory.LaunchInfo memory info = factory.getLaunchInfo(
            tokenAddress
        );
        assertEq(info.creator, creator, "Creator should be recorded correctly");
        assertEq(info.curve, curveAddress, "Curve address should match");
        assertEq(
            info.metadataURI,
            metadataURI,
            "Metadata URI should match supplied URI"
        );
        assertEq(factory.tokenCount(), 1, "Token count should be 1");
        assertEq(
            factory.tokenAt(0),
            tokenAddress,
            "Token list should contain the token"
        );

        // Assert 2: The bonding curve's tokenAddress points to the token
        assertEq(
            BondingCurve(curveAddress).tokenAddress(),
            tokenAddress,
            "Bonding curve tokenAddress should point to the token"
        );

        // Assert 3: The full token supply is held by the curve
        uint256 expectedSupply = supplyWholeTokens * 10 ** 18;
        assertEq(
            LaunchToken(tokenAddress).balanceOf(curveAddress),
            expectedSupply,
            "Curve should hold the full token supply"
        );

        // Assert 4: The launch fee is credited to pendingFees
        assertEq(
            factory.pendingFees(),
            LAUNCH_FEE,
            "Launch fee should be credited to pendingFees"
        );
    }

    /// @notice Tests that only feeRecipient can withdraw fees, transfers funds, and resets pendingFees
    function test_FeeWithdrawal() public {
        // Arrange: Create a launch to accrue pending fees
        address creator = makeAddr("creator");
        vm.deal(creator, 1 ether);

        LaunchpadFactory.LaunchParams memory params = LaunchpadFactory
            .LaunchParams({
                name: "Meme Token",
                symbol: "MEME",
                metadataURI: "ipfs://QmTestMetadataURI",
                supplyWholeTokens: 1_000_000
            });

        vm.prank(creator);
        factory.createLaunch{value: LAUNCH_FEE}(params);

        assertEq(factory.pendingFees(), LAUNCH_FEE, "Fees should be accrued");

        // Assert 1: Non-recipient cannot withdraw (unauthorized)
        address unauthorizedUser = makeAddr("randomUser");
        vm.prank(unauthorizedUser);
        vm.expectRevert(LaunchpadFactory.Unauthorized.selector);
        factory.withdrawFees();

        // Act: feeRecipient withdraws fees
        uint256 recipientBalanceBefore = feeRecipient.balance;

        vm.prank(feeRecipient);
        factory.withdrawFees();

        // Assert 2: Funds are transferred and pendingFees is reset to zero
        assertEq(
            feeRecipient.balance,
            recipientBalanceBefore + LAUNCH_FEE,
            "Recipient should receive the fees"
        );
        assertEq(
            factory.pendingFees(),
            0,
            "pendingFees should be reset to zero"
        );
    }
}
