// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LaunchToken} from "./LaunchToken.sol";
import {BondingCurve} from "./BondingCurve.sol";

contract LaunchpadFactory is ReentrancyGuard {
    // A launch is discoverable from this event without scanning storage.
    event TokenLaunched(
        address indexed token,
        address indexed curve,
        address indexed creator,
        uint256 supplyWholeTokens,
        uint256 createdAt
    );
    event FeesWithdrawn(address indexed recipient, uint256 amount);

    error ZeroAddress();
    error IncorrectFee(uint256 expected, uint256 received);
    error InvalidName();
    error InvalidSymbol();
    error InvalidMetadataURI();
    error InvalidSupply();
    error Unauthorized();
    error NoFeesToWithdraw();
    error FeeTransferFailed();

    // Limits data stored and copied during deployment. These are byte limits,
    // not character counts. The URI points to off-chain metadata.
    uint256 private constant MAX_NAME_BYTES = 64;
    uint256 private constant MAX_SYMBOL_BYTES = 16;
    uint256 private constant MAX_METADATA_URI_BYTES = 2048;

    // LaunchToken multiplies whole-token supply by 10^18. This bound prevents
    // that multiplication from overflowing. It is not an economic supply cap.
    uint256 private constant TOKEN_UNIT = 10 ** 18;
    uint256 private constant MAX_SAFE_SUPPLY_WHOLE_TOKENS =
        type(uint256).max / TOKEN_UNIT;

    // Data supplied by the creator for one launch.
    struct LaunchParams {
        string name;
        string symbol;
        string metadataURI;
        uint256 supplyWholeTokens;
    }

    // Registry data keyed by token address. The token itself exposes its name,
    // symbol, and total supply; the curve owns live price and bonding state.
    struct LaunchInfo {
        address curve;
        address creator;
        string metadataURI;
        uint256 createdAt;
    }

    mapping(address => LaunchInfo) private launchInfo;
    address[] private tokenList;

    // The configured fee is in wei. A fixed fee recipient avoids mutable
    // admin configuration in this first version.
    uint256 public immutable launchFee;
    address payable public immutable feeRecipient;

    // Fees are credited here during launch and withdrawn separately. This
    // avoids calling the recipient in the middle of creating a launch.
    uint256 public pendingFees;

    constructor(uint256 launchFee_, address payable feeRecipient_) {
        if (feeRecipient_ == address(0)) revert ZeroAddress();

        launchFee = launchFee_;
        feeRecipient = feeRecipient_;
    }

    function getLaunchInfo(
        address tokenAddress
    ) external view returns (LaunchInfo memory) {
        return launchInfo[tokenAddress];
    }

    function tokenCount() external view returns (uint256) {
        return tokenList.length;
    }

    function tokenAt(uint256 index) external view returns (address) {
        return tokenList[index];
    }

    // The caller pays exactly launchFee. A launch is atomic: if any deploy,
    // initialization, or registry write fails, the transaction and fee credit
    // both revert.
    function createLaunch(
        LaunchParams calldata launchParams_
    )
        external
        payable
        nonReentrant
        returns (address tokenAddress, address curveAddress)
    {
        if (msg.value != launchFee) {
            revert IncorrectFee(launchFee, msg.value);
        }

        _validateLaunchParams(launchParams_);

        // The curve is deployed first. The token constructor can then mint its
        // full supply directly to the curve, and the curve is wired afterward.
        BondingCurve curve = new BondingCurve(address(this));
        LaunchToken token = new LaunchToken(
            launchParams_.name,
            launchParams_.symbol,
            address(curve),
            launchParams_.supplyWholeTokens
        );
        curve.initialize(address(token));

        tokenAddress = address(token);
        curveAddress = address(curve);

        launchInfo[tokenAddress] = LaunchInfo({
            curve: curveAddress,
            creator: msg.sender,
            metadataURI: launchParams_.metadataURI,
            createdAt: block.timestamp
        });
        tokenList.push(tokenAddress);

        // msg.value equals launchFee due to the exact-fee check above.
        pendingFees += msg.value;

        emit TokenLaunched(
            tokenAddress,
            curveAddress,
            msg.sender,
            launchParams_.supplyWholeTokens,
            block.timestamp
        );
    }

    // Only the configured recipient can withdraw accumulated fees. Effects
    // happen before the external call; ReentrancyGuard adds a second defense.
    function withdrawFees() external nonReentrant {
        if (msg.sender != feeRecipient) revert Unauthorized();

        uint256 amount = pendingFees;
        if (amount == 0) revert NoFeesToWithdraw();

        pendingFees = 0;
        (bool success, ) = feeRecipient.call{value: amount}("");
        if (!success) revert FeeTransferFailed();

        emit FeesWithdrawn(feeRecipient, amount);
    }

    function _validateLaunchParams(
        LaunchParams calldata launchParams_
    ) private pure {
        uint256 nameLength = bytes(launchParams_.name).length;
        if (nameLength == 0 || nameLength > MAX_NAME_BYTES) {
            revert InvalidName();
        }

        uint256 symbolLength = bytes(launchParams_.symbol).length;
        if (symbolLength == 0 || symbolLength > MAX_SYMBOL_BYTES) {
            revert InvalidSymbol();
        }

        uint256 metadataLength = bytes(launchParams_.metadataURI).length;
        if (metadataLength == 0 || metadataLength > MAX_METADATA_URI_BYTES) {
            revert InvalidMetadataURI();
        }

        if (
            launchParams_.supplyWholeTokens == 0 ||
            launchParams_.supplyWholeTokens > MAX_SAFE_SUPPLY_WHOLE_TOKENS
        ) {
            revert InvalidSupply();
        }
    }
}
