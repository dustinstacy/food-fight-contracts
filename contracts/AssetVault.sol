//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AssetFactory} from "./AssetFactory.sol";

/// @title AssetVault
/// @notice This contract handles user asset storage.
/// @notice Users must have a balance of a given asset to perform certain actions.
contract AssetVault is IERC1155Receiver, Ownable, ReentrancyGuard {
    ///////////////////////////////////////////////////////////
    ///                   STATE VARIABLES                   ///
    ///////////////////////////////////////////////////////////

    /// @notice Mapping of a user to their balances of each token ID.
    mapping(address user => mapping(uint256 assetId => uint256 balance)) private balances;

    /// @notice Mapping of approved callers.
    mapping(address => bool) private approvedCallers;

    /// @notice Instance of the AssetFactory contract that is responsible for minting assets.
    AssetFactory private immutable FACTORY;

    /// @notice The token ID of the IGC token.
    uint8 private immutable IGC_TOKEN_ID;

    ///////////////////////////////////////////////////////////
    ///                       EVENTS                        ///
    ///////////////////////////////////////////////////////////

    /// @notice Emitted when a caller is approved to perform actions on a lock function.
    event ApprovedCaller(address caller);

    /// @notice Emitted when assets are deposited into the contract.
    event AssetsDeposited(address from, uint256[] assetIds, uint256[] amounts);

    /// @notice Emitted when assets are locked in the contract.
    event AssetLocked(address account, uint256 assetId, uint256 amount);

    /// @notice Emitted when assets are unlocked in the contract.
    event AssetUnlocked(address account, uint256 assetId, uint256 amount);

    /// @notice Emitted when assets are withdrawn from the contract.
    event AssetsWithdrawn(address to, uint256[] assetIds, uint256[] amounts);

    /// @notice Emitted when IGC is deposited into the contract.
    event IGCDeposited(address from, uint256 amount);

    /// @notice Emitted when IGC is withdrawn from the contract.
    event IGCWithdrawn(address to, uint256 amount);

    /// @notice Emitted when a caller is revoked from performing actions on a lock function.
    event RevokedCaller(address caller);

    ///////////////////////////////////////////////////////////
    ///                       ERRORS                        ///
    ///////////////////////////////////////////////////////////

    /// @notice Thrown when the length of the assetIds and amounts arrays are different.
    error AssetVaultArraysLengthMismatch(uint256 assetIdsLength, uint256 amountsLength);

    /// @notice Thrown when the user lacks the required balance to perform an action.
    error AssetVaultInsufficientBalance(
        address caller,
        uint256 balance,
        uint256 amount,
        uint256 assetId
    );

    /// @notice Thrown when the caller is not approved to perform an action.
    error AssetVaultUnauthorizedCaller(address caller);

    /////////////////////////////////////////////////////////////
    ///                      MODIFIERS                        ///
    /////////////////////////////////////////////////////////////

    /// @notice Modifier to restrict access to approved callers.
    modifier onlyApprovedCaller() {
        if (!getIsApprovedCaller(msg.sender)) {
            revert AssetVaultUnauthorizedCaller(msg.sender);
        }
        _;
    }

    ///////////////////////////////////////////////////////////
    ///                     CONSTRUCTOR                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Construct the AssetVault contract.
    /// @param _factory The address of the ERC1155 contract that is responsible for minting assets.
    /// @param _initialOwner The address of the owner of the contract.
    constructor(address _factory, address _initialOwner) Ownable(_initialOwner) {
        FACTORY = AssetFactory(_factory);
        IGC_TOKEN_ID = FACTORY.getIGCTokenId();
    }

    ///////////////////////////////////////////////////////////
    ///                   DEPOSIT FUNCTIONS                 ///
    ///////////////////////////////////////////////////////////

    /// @notice Deposit IGC into the contract.
    /// @param amount The amount of IGC to deposit.
    /// @dev Will throw an error when the user lacks the required balance to deposit the IGC. (ERC1155InsufficientBalance).
    function depositIGC(uint256 amount) external nonReentrant {
        FACTORY.safeTransferFrom(msg.sender, address(this), IGC_TOKEN_ID, amount, "");

        balances[msg.sender][IGC_TOKEN_ID] += amount;

        emit IGCDeposited(msg.sender, amount);
    }

    /// @notice Deposit assets into a contract.
    /// @param assetIds The token IDs of the assets to deposit.
    /// @param amounts The amounts of the assets to deposit.
    /// @dev Will throw an error when the user lacks the required balance to deposit the assets.(ERC1155InsufficientBalance).
    /// @dev Will throw an error when the length of the assetIds and amounts arrays are different. (ERC1155InvalidArrayLength).
    function depositAssets(
        uint256[] memory assetIds,
        uint256[] memory amounts
    ) external nonReentrant {
        FACTORY.safeBatchTransferFrom(msg.sender, address(this), assetIds, amounts, "");

        for (uint256 i = 0; i < assetIds.length; i++) {
            balances[msg.sender][assetIds[i]] += amounts[i];
        }

        emit AssetsDeposited(msg.sender, assetIds, amounts);
    }

    ///////////////////////////////////////////////////////////
    ///                   WITHDRAW FUNCTIONS                ///
    ///////////////////////////////////////////////////////////

    /// @notice Withdraw IGC to a target address.
    /// @param to The address to withdraw the IGC to.
    /// @param amount The amount of IGC to withdraw.
    function withdrawIGC(address to, uint256 amount) external {
        if (balances[msg.sender][IGC_TOKEN_ID] < amount) {
            revert AssetVaultInsufficientBalance(
                msg.sender,
                balances[msg.sender][IGC_TOKEN_ID],
                amount,
                IGC_TOKEN_ID
            );
        }

        balances[msg.sender][IGC_TOKEN_ID] -= amount;

        FACTORY.safeTransferFrom(address(this), to, IGC_TOKEN_ID, amount, "");

        emit IGCWithdrawn(to, amount);
    }

    /// @notice Withdraw assets to a target address.
    /// @param to The address to withdraw the assets to.
    /// @param assetIds The token IDs of the assets to withdraw.
    /// @param amounts The amounts of the assets to withdraw.
    function withdrawAssets(
        address to,
        uint256[] memory assetIds,
        uint256[] memory amounts
    ) external {
        if (assetIds.length != amounts.length) {
            revert AssetVaultArraysLengthMismatch(assetIds.length, amounts.length);
        }

        for (uint256 i = 0; i < assetIds.length; i++) {
            if (balances[msg.sender][assetIds[i]] < amounts[i]) {
                revert AssetVaultInsufficientBalance(
                    msg.sender,
                    balances[msg.sender][assetIds[i]],
                    amounts[i],
                    assetIds[i]
                );
            }

            balances[msg.sender][assetIds[i]] -= amounts[i];
        }

        FACTORY.safeBatchTransferFrom(address(this), to, assetIds, amounts, "");

        emit AssetsWithdrawn(to, assetIds, amounts);
    }

    ///////////////////////////////////////////////////////////
    ///                  LOCK FUNCTIONS                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Lock assets in the contract.
    /// @param account The address of the account to lock the assets for.
    /// @param assetId The token IDs of the assets to lock.
    /// @param amount The amount of the assets to lock.
    /// @dev Also used as a mechanism to permanently remove assets from a user balance based on the outcome of an action i.e. a trade.
    function lockAsset(
        address account,
        uint256 assetId,
        uint256 amount
    ) external onlyApprovedCaller {
        if (balances[account][assetId] < amount) {
            revert AssetVaultInsufficientBalance(
                account,
                balances[account][assetId],
                amount,
                assetId
            );
        }

        balances[account][assetId] -= amount;

        emit AssetLocked(account, assetId, amount);
    }

    /// @notice Unlock assets in the contract.
    /// @param account The address of the account to unlock the assets for.
    /// @param assetId The token IDs of the assets to unlock.
    /// @param amount The amount of the assets to unlock.
    /// @dev Also used as a mechanism to permanently add assets to a user balance based on the outcome of an action i.e. a trade.
    function unlockAsset(
        address account,
        uint256 assetId,
        uint256 amount
    ) external onlyApprovedCaller {
        if (FACTORY.balanceOf(address(this), assetId) < amount) {
            revert AssetVaultInsufficientBalance(
                address(this),
                FACTORY.balanceOf(address(this), assetId),
                amount,
                assetId
            );
        }

        balances[account][assetId] += amount;

        emit AssetUnlocked(account, assetId, amount);
    }

    ///////////////////////////////////////////////////////////
    ///                  ACCESS CONTROL                     ///
    ///////////////////////////////////////////////////////////

    /// @notice Approve a caller to perform actions on behalf of a user.
    /// @param caller The address of the caller to approve.
    function approveCaller(address caller) external onlyOwner {
        approvedCallers[caller] = true;

        emit ApprovedCaller(caller);
    }

    /// @notice Revoke approval for a caller to perform actions on behalf of a user.
    /// @param caller The address of the caller to revoke approval for.
    function revokeCaller(address caller) external onlyOwner {
        approvedCallers[caller] = false;

        emit RevokedCaller(caller);
    }

    ///////////////////////////////////////////////////////////
    ///                   VIEW FUNCTIONS                    ///
    ///////////////////////////////////////////////////////////

    /// @notice Get the balance of a user for a specific token ID.
    /// @param user The address of the user.
    /// @param assetId The token ID to get the balance of.
    /// @return balance The balance of the user for the token ID.
    function balanceOf(address user, uint256 assetId) public view returns (uint256 balance) {
        return balances[user][assetId];
    }

    /// @notice Get the factory contract address.
    /// @return factoryAddress The address of the assets contract.
    function getAssetFactoryAddress() public view returns (address factoryAddress) {
        return address(FACTORY);
    }

    /// @notice Get the IGC token ID.
    /// @return IGC_TOKEN_ID The token ID of the IGC token.
    function getIGCTokenId() public view returns (uint8) {
        return IGC_TOKEN_ID;
    }

    /// @notice Get the approved caller status.
    /// @param caller The address of the caller.
    /// @return approved The approved caller status.
    function getIsApprovedCaller(address caller) public view returns (bool approved) {
        return approvedCallers[caller];
    }

    /////////////////////////////////////////////////////////////
    ///               ERC1155 RECEIVER FUNCTIONS              ///
    /////////////////////////////////////////////////////////////

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*id*/,
        uint256 /*value*/,
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155BatchReceived(
        address /*operator*/,
        address /*from*/,
        uint256[] memory /*ids*/,
        uint256[] memory /*values*/,
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return
            bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    /////////////////////////////////////////////////////////////
    ///               IERC165 INTERFACE FUNCTIONS             ///
    /////////////////////////////////////////////////////////////

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}
