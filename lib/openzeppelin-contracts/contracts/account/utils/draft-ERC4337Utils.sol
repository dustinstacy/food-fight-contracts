// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (account/utils/draft-ERC4337Utils.sol)

pragma solidity ^0.8.28;

import {PackedUserOperation} from "../../interfaces/draft-IERC4337.sol";
import {Math} from "../../utils/math/Math.sol";
import {Packing} from "../../utils/Packing.sol";

/**
 * @dev Library with common ERC-4337 utility functions.
 *
 * See https://eips.ethereum.org/EIPS/eip-4337[ERC-4337].
 */
library ERC4337Utils {
    using Packing for *;

    /// @dev For simulation purposes, validateUserOp (and validatePaymasterUserOp) return this value on success.
    uint256 internal constant SIG_VALIDATION_SUCCESS = 0;

    /// @dev For simulation purposes, validateUserOp (and validatePaymasterUserOp) must return this value in case of signature failure, instead of revert.
    uint256 internal constant SIG_VALIDATION_FAILED = 1;

    /// @dev Parses the validation data into its components. See {packValidationData}.
    function parseValidationData(uint256 validationData)
        internal
        pure
        returns (address aggregator, uint48 validAfter, uint48 validUntil)
    {
        validAfter = uint48(bytes32(validationData).extract_32_6(0));
        validUntil = uint48(bytes32(validationData).extract_32_6(6));
        aggregator = address(bytes32(validationData).extract_32_20(12));
        if (validUntil == 0) validUntil = type(uint48).max;
    }

    /// @dev Packs the validation data into a single uint256. See {parseValidationData}.
    function packValidationData(address aggregator, uint48 validAfter, uint48 validUntil)
        internal
        pure
        returns (uint256)
    {
        return uint256(bytes6(validAfter).pack_6_6(bytes6(validUntil)).pack_12_20(bytes20(aggregator)));
    }

    /// @dev Same as {packValidationData}, but with a boolean signature success flag.
    function packValidationData(bool sigSuccess, uint48 validAfter, uint48 validUntil)
        internal
        pure
        returns (uint256)
    {
        return packValidationData(
            address(uint160(Math.ternary(sigSuccess, SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED))),
            validAfter,
            validUntil
        );
    }

    /**
     * @dev Combines two validation data into a single one.
     *
     * The `aggregator` is set to {SIG_VALIDATION_SUCCESS} if both are successful, while
     * the `validAfter` is the maximum and the `validUntil` is the minimum of both.
     */
    function combineValidationData(uint256 validationData1, uint256 validationData2) internal pure returns (uint256) {
        (address aggregator1, uint48 validAfter1, uint48 validUntil1) = parseValidationData(validationData1);
        (address aggregator2, uint48 validAfter2, uint48 validUntil2) = parseValidationData(validationData2);

        bool success = aggregator1 == address(uint160(SIG_VALIDATION_SUCCESS))
            && aggregator2 == address(uint160(SIG_VALIDATION_SUCCESS));
        uint48 validAfter = uint48(Math.max(validAfter1, validAfter2));
        uint48 validUntil = uint48(Math.min(validUntil1, validUntil2));
        return packValidationData(success, validAfter, validUntil);
    }

    /// @dev Returns the aggregator of the `validationData` and whether it is out of time range.
    function getValidationData(uint256 validationData)
        internal
        view
        returns (address aggregator, bool outOfTimeRange)
    {
        (address aggregator_, uint48 validAfter, uint48 validUntil) = parseValidationData(validationData);
        return (aggregator_, block.timestamp < validAfter || validUntil < block.timestamp);
    }

    /// @dev Computes the hash of a user operation for a given entrypoint and chainid.
    function hash(PackedUserOperation calldata self, address entrypoint, uint256 chainid)
        internal
        pure
        returns (bytes32)
    {
        bytes32 result = keccak256(
            abi.encode(
                keccak256(
                    abi.encode(
                        self.sender,
                        self.nonce,
                        keccak256(self.initCode),
                        keccak256(self.callData),
                        self.accountGasLimits,
                        self.preVerificationGas,
                        self.gasFees,
                        keccak256(self.paymasterAndData)
                    )
                ),
                entrypoint,
                chainid
            )
        );
        return result;
    }

    /// @dev Returns `factory` from the {PackedUserOperation}, or address(0) if the initCode is empty or not properly formatted.
    function factory(PackedUserOperation calldata self) internal pure returns (address) {
        return self.initCode.length < 20 ? address(0) : address(bytes20(self.initCode[0:20]));
    }

    /// @dev Returns `factoryData` from the {PackedUserOperation}, or empty bytes if the initCode is empty or not properly formatted.
    function factoryData(PackedUserOperation calldata self) internal pure returns (bytes calldata) {
        return self.initCode.length < 20 ? _emptyCalldataBytes() : self.initCode[20:];
    }

    /// @dev Returns `verificationGasLimit` from the {PackedUserOperation}.
    function verificationGasLimit(PackedUserOperation calldata self) internal pure returns (uint256) {
        return uint128(self.accountGasLimits.extract_32_16(0));
    }

    /// @dev Returns `callGasLimit` from the {PackedUserOperation}.
    function callGasLimit(PackedUserOperation calldata self) internal pure returns (uint256) {
        return uint128(self.accountGasLimits.extract_32_16(16));
    }

    /// @dev Returns the first section of `gasFees` from the {PackedUserOperation}.
    function maxPriorityFeePerGas(PackedUserOperation calldata self) internal pure returns (uint256) {
        return uint128(self.gasFees.extract_32_16(0));
    }

    /// @dev Returns the second section of `gasFees` from the {PackedUserOperation}.
    function maxFeePerGas(PackedUserOperation calldata self) internal pure returns (uint256) {
        return uint128(self.gasFees.extract_32_16(16));
    }

    /// @dev Returns the total gas price for the {PackedUserOperation} (ie. `maxFeePerGas` or `maxPriorityFeePerGas + basefee`).
    function gasPrice(PackedUserOperation calldata self) internal view returns (uint256) {
        unchecked {
            // Following values are "per gas"
            uint256 maxPriorityFee = maxPriorityFeePerGas(self);
            uint256 maxFee = maxFeePerGas(self);
            return Math.min(maxFee, maxPriorityFee + block.basefee);
        }
    }

    /// @dev Returns the first section of `paymasterAndData` from the {PackedUserOperation}.
    function paymaster(PackedUserOperation calldata self) internal pure returns (address) {
        return self.paymasterAndData.length < 52 ? address(0) : address(bytes20(self.paymasterAndData[0:20]));
    }

    /// @dev Returns the second section of `paymasterAndData` from the {PackedUserOperation}.
    function paymasterVerificationGasLimit(PackedUserOperation calldata self) internal pure returns (uint256) {
        return self.paymasterAndData.length < 52 ? 0 : uint128(bytes16(self.paymasterAndData[20:36]));
    }

    /// @dev Returns the third section of `paymasterAndData` from the {PackedUserOperation}.
    function paymasterPostOpGasLimit(PackedUserOperation calldata self) internal pure returns (uint256) {
        return self.paymasterAndData.length < 52 ? 0 : uint128(bytes16(self.paymasterAndData[36:52]));
    }

    /// @dev Returns the fourth section of `paymasterAndData` from the {PackedUserOperation}.
    function paymasterData(PackedUserOperation calldata self) internal pure returns (bytes calldata) {
        return self.paymasterAndData.length < 52 ? _emptyCalldataBytes() : self.paymasterAndData[52:];
    }

    // slither-disable-next-line write-after-write
    function _emptyCalldataBytes() private pure returns (bytes calldata result) {
        assembly ("memory-safe") {
            result.offset := 0
            result.length := 0
        }
    }
}
