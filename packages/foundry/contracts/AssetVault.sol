//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract AssetVault is IERC1155Receiver {
    ///////////////////////////////////////////////////////////
    ///                      ERRORS                         ///
    ///////////////////////////////////////////////////////////

    /// Emitted when the token IDs and amounts arrays have different lengths.
    error AssetVaultArraysLengthMismatch(uint256 tokenIdsLength, uint256 amountsLength);

    /// Emitted when the caller tries to withdraw more assets than they own.
    error AssetVaultInsufficientBalance(address caller, uint256 balance, uint256 amount, uint256 tokenId);

    ///////////////////////////////////////////////////////////
    ///                    EVENTS                           ///
    ///////////////////////////////////////////////////////////

    // Emitted when assets are withdrawn from the contract.
    event AssetsWithdrawn(address to, uint256[] tokenIds, uint256[] amounts);

    // Emitted when IGC is withdrawn from the contract.
    event IGCWithdrawn(address to, uint256 amount);

    // Emitted when assets are deposited into the contract.
    event AssetsDeposited(address from, uint256[] tokenIds, uint256[] amounts);

    // Emitted when IGC is deposited into the contract.
    event IGCDeposited(address from, uint256 amount);

    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    mapping(address user => mapping(uint256 tokenId => uint256 balance)) private balances;

    uint8 private igcTokenId = 0;
    IERC1155 private assetsContract;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    constructor(address _assetsContract) {
        assetsContract = IERC1155(_assetsContract);
    }

    ///////////////////////////////////////////////////////////
    ///                   DEPOSIT FUNCTIONS                 ///
    ///////////////////////////////////////////////////////////

    /// @notice Deposit IGC into the contract
    /// @param amount The amount of IGC to deposit
    /// @dev Will throw an error if the user doesn't have enough IGC (ERC1155InsufficientBalance)
    function depositIGC(uint256 amount) external {
        // Transfer the IGC to the contract
        assetsContract.safeTransferFrom(msg.sender, address(this), igcTokenId, amount, "");

        // Update the user's balance
        balances[msg.sender][igcTokenId] += amount;

        emit IGCDeposited(msg.sender, amount);
    }

    /// @notice Deposit assets into a contract
    /// @param tokenIds The token IDs of the assets to deposit
    /// @param amounts The amounts of the assets to deposit
    /// @dev Will throw an error if the user doesn't have enough assets (ERC1155InsufficientBalance)
    /// @dev Will throw an error if the tokenIds and amounts arrays are different lengths (ERC1155ArraysLengthMismatch)
    function depositAssets(uint256[] memory tokenIds, uint256[] memory amounts) external {
        // Transfer the assets to the contract
        assetsContract.safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, "");

        // Update the user's balances
        for (uint256 i = 0; i < tokenIds.length; i++) {
            balances[msg.sender][tokenIds[i]] += amounts[i];
        }

        emit AssetsDeposited(msg.sender, tokenIds, amounts);
    }

    ///////////////////////////////////////////////////////////
    ///                   WITHDRAW FUNCTIONS                ///
    ///////////////////////////////////////////////////////////

    /// @notice Withdraw IGC to a target address
    /// @param to The address to withdraw the IGC to
    /// @param amount The amount of IGC to withdraw
    function withdrawIGC(address to, uint256 amount) external {
        // Check if the user has enough IGC in their balance
        if (balances[msg.sender][igcTokenId] < amount) {
            revert AssetVaultInsufficientBalance(msg.sender, balances[msg.sender][igcTokenId], amount, igcTokenId);
        }

        // Update the user's balance
        balances[msg.sender][igcTokenId] -= amount;

        // Transfer the IGC to the user
        assetsContract.safeTransferFrom(address(this), to, igcTokenId, amount, "");

        emit IGCWithdrawn(to, amount);
    }

    /// @notice Withdraw assets to a target address
    /// @param to The address to withdraw the assets to
    /// @param tokenIds The token IDs of the assets to withdraw
    /// @param amounts The amounts of the assets to withdraw
    function withdrawAssets(address to, uint256[] memory tokenIds, uint256[] memory amounts) external {
        // Check if the tokenIds and amounts arrays are the same length
        if (tokenIds.length != amounts.length) {
            revert AssetVaultArraysLengthMismatch(tokenIds.length, amounts.length);
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Check if the user has enough of the assets in their balances
            if (balances[msg.sender][tokenIds[i]] < amounts[i]) {
                revert AssetVaultInsufficientBalance(
                    msg.sender, balances[msg.sender][tokenIds[i]], amounts[i], tokenIds[i]
                );
            }
        }

        // Update the user's balances
        for (uint256 i = 0; i < tokenIds.length; i++) {
            balances[msg.sender][tokenIds[i]] -= amounts[i];
        }

        // Transfer the assets to the user
        assetsContract.safeBatchTransferFrom(address(this), to, tokenIds, amounts, "");

        emit AssetsWithdrawn(to, tokenIds, amounts);
    }

    /////////////////////////////////////////////////////////////
    ///               ERC1155 RECEIVER FUNCTIONS              ///
    /////////////////////////////////////////////////////////////

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(
        address, /*operator*/
        address, /*from*/
        uint256, /*id*/
        uint256, /*value*/
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155BatchReceived(
        address, /*operator*/
        address, /*from*/
        uint256[] memory, /*ids*/
        uint256[] memory, /*values*/
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    /////////////////////////////////////////////////////////////
    ///               IERC165 INTERFACE FUNCTIONS             ///
    /////////////////////////////////////////////////////////////

    // Implement supportsInterface
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
