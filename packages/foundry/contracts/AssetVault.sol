//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title AssetVault
/// @notice This contract handles user asset storage.
/// @notice Users must have a balance of a given asset to perform certain actions.
contract AssetVault is IERC1155Receiver {
    ///////////////////////////////////////////////////////////
    ///                      ERRORS                         ///
    ///////////////////////////////////////////////////////////

    /// @notice Thrown when the length of the tokenIds and amounts arrays are different.
    error AssetVaultArraysLengthMismatch(uint256 tokenIdsLength, uint256 amountsLength);

    /// @notice Thrown when the user lacks the required balance to perform an action.
    error AssetVaultInsufficientBalance(address caller, uint256 balance, uint256 amount, uint256 tokenId);

    ///////////////////////////////////////////////////////////
    ///                    EVENTS                           ///
    ///////////////////////////////////////////////////////////

    /// @notice Emitted when IGC is deposited into the contract.
    event IGCDeposited(address from, uint256 amount);

    /// @notice Emitted when assets are deposited into the contract.
    event AssetsDeposited(address from, uint256[] tokenIds, uint256[] amounts);

    /// @notice Emitted when IGC is withdrawn from the contract.
    event IGCWithdrawn(address to, uint256 amount);

    /// @notice Emitted when assets are withdrawn from the contract.
    event AssetsWithdrawn(address to, uint256[] tokenIds, uint256[] amounts);

    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mapping of a user to their balances of each token ID.
    mapping(address user => mapping(uint256 tokenId => uint256 balance)) private balances;

    /// @notice Instance of the ERC1155 contract that is responsible for minting assets.
    IERC1155 private factory;

    /// @notice The token ID of the IGC token.
    uint8 private igcTokenId = 0;

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Construct the AssetVault contract.
    /// @param _factory The address of the ERC1155 contract that is responsible for minting assets.
    constructor(address _factory) {
        factory = IERC1155(_factory);
    }

    ///////////////////////////////////////////////////////////
    ///                   DEPOSIT FUNCTIONS                 ///
    ///////////////////////////////////////////////////////////

    /// @notice Deposit IGC into the contract.
    /// @param amount The amount of IGC to deposit.
    /// @dev Will throw an error when the user lacks the required balance to deposit the IGC. (ERC1155InsufficientBalance).
    function depositIGC(uint256 amount) external {
        factory.safeTransferFrom(msg.sender, address(this), igcTokenId, amount, "");

        balances[msg.sender][igcTokenId] += amount;

        emit IGCDeposited(msg.sender, amount);
    }

    /// @notice Deposit assets into a contract.
    /// @param tokenIds The token IDs of the assets to deposit.
    /// @param amounts The amounts of the assets to deposit.
    /// @dev Will throw an error when the user lacks the required balance to deposit the assets.(ERC1155InsufficientBalance).
    /// @dev Will throw an error when the length of the tokenIds and amounts arrays are different. (ERC1155InvalidArrayLength).
    function depositAssets(uint256[] memory tokenIds, uint256[] memory amounts) external {
        factory.safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, "");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            balances[msg.sender][tokenIds[i]] += amounts[i];
        }

        emit AssetsDeposited(msg.sender, tokenIds, amounts);
    }

    ///////////////////////////////////////////////////////////
    ///                   WITHDRAW FUNCTIONS                ///
    ///////////////////////////////////////////////////////////

    /// @notice Withdraw IGC to a target address.
    /// @param to The address to withdraw the IGC to.
    /// @param amount The amount of IGC to withdraw.
    function withdrawIGC(address to, uint256 amount) external {
        if (balances[msg.sender][igcTokenId] < amount) {
            revert AssetVaultInsufficientBalance(msg.sender, balances[msg.sender][igcTokenId], amount, igcTokenId);
        }

        balances[msg.sender][igcTokenId] -= amount;

        factory.safeTransferFrom(address(this), to, igcTokenId, amount, "");

        emit IGCWithdrawn(to, amount);
    }

    /// @notice Withdraw assets to a target address.
    /// @param to The address to withdraw the assets to.
    /// @param tokenIds The token IDs of the assets to withdraw.
    /// @param amounts The amounts of the assets to withdraw.
    function withdrawAssets(address to, uint256[] memory tokenIds, uint256[] memory amounts) external {
        if (tokenIds.length != amounts.length) {
            revert AssetVaultArraysLengthMismatch(tokenIds.length, amounts.length);
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (balances[msg.sender][tokenIds[i]] < amounts[i]) {
                revert AssetVaultInsufficientBalance(
                    msg.sender, balances[msg.sender][tokenIds[i]], amounts[i], tokenIds[i]
                );
            }

            balances[msg.sender][tokenIds[i]] -= amounts[i];
        }

        factory.safeBatchTransferFrom(address(this), to, tokenIds, amounts, "");

        emit AssetsWithdrawn(to, tokenIds, amounts);
    }

    ///////////////////////////////////////////////////////////
    ///                  LOCK FUNCTIONS                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Lock assets in the contract.
    /// @param account The address of the account to lock the assets for.
    /// @param tokenId The token IDs of the assets to lock.
    /// @dev Also used as a mechanism to permanently remove assets from a user balance based on the outcome of an action i.e. a swap.
    //!! Consider making a batch version of this function.
    function lockAsset(address account, uint256 tokenId) external {
        balances[account][tokenId] -= 1;
    }

    /// @notice Unlock assets in the contract.
    /// @param account The address of the account to unlock the assets for.
    /// @param tokenId The token IDs of the assets to unlock.
    /// @dev Also used as a mechanism to permanently add assets to a user balance based on the outcome of an action i.e. a swap.
    //!! Consider making a batch version of this function.
    function unlockAsset(address account, uint256 tokenId) external {
        balances[account][tokenId] += 1;
    }

    ///////////////////////////////////////////////////////////
    ///                   VIEW FUNCTIONS                    ///
    ///////////////////////////////////////////////////////////

    /// @notice Get the balance of a user for a specific token ID.
    /// @param user The address of the user.
    /// @param tokenId The token ID to get the balance of.
    /// @return balance The balance of the user for the token ID.
    function balanceOf(address user, uint256 tokenId) external view returns (uint256 balance) {
        return balances[user][tokenId];
    }

    /// @notice Get the address of the factory contract.
    /// @return factoryAddress The address of the factory contract.
    function getFactoryAddress() external view returns (address factoryAddress) {
        return address(factory);
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

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
