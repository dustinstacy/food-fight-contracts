//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Step 1. Initialize the Battle
//       a. Create a new battle log
//       b. Add the players to the battle log
//          i. Players will have an address
//          ii. Players will have a list of NFTs
//          iii. Players will have a base health
//       c. Initialize the board
//          i. Create an empty grid based on the row and column count
//          ii. Store the row and column count in the battle log
//          iii. Set the first column to be controlled by player 1
//          iv. Set the last column to be controlled by player 2

// Step 2. Place an NFT on the board
//       a. Check if the player controls the cell
//       b. Check if the cell is empty
//       c. Place the NFT on the cell
//       d. Capture the next cell in front of the NFT if possible
//       e. Check players actions left

// Step 3. Move an NFT on the board
//       a. Check if the player controls the cell
//       b. Check if the cell is empty
//       c. Check if the cell is within the move range of the NFT
//       d. Move the NFT to the cell
//       e. Capture the next cell in front of the NFT if possible
//       f. Check players actions left

// Step 4. Attack an enemy NFT
//       a. Check if the cell is within the attack range of the NFT
//       b. Check if the cell is occupied by an enemy NFT
//       c. Calculate the attack using the BattleProccesor contract
//       d. Reduce the health of the defending NFT
//       e. Remove the defending NFT if health is less than or equal to 0
//       f. Check players actions left

// Step 5. Attack the enemy base
//       a. Check if the NFT is at the base (opposite side of the board)
//       b. Calculate the attack using the BattleProccesor contract
//       c. Reduce the health of the base
//       d. Remove the base if health is less than or equal to 0
//       e. Declare the player as the winner
//       f. If the base is not destroyed, check players actions left

// Step 6. End the turn
//       a. Check if the player has any actions left
//       b. Switch to the next player

// Step 7. End the game
//       a. Check if the base health of a player is less than or equal to 0
//       b. Declare the other player as the winner

/// @title Battle Contract
/// @notice This contract handles the battle setup, player actions, board management, and game logic.
contract Battle {
    ///////////////////////////////////////////////////////////
    ///                   VARIABLES                         ///
    ///////////////////////////////////////////////////////////

    struct NFT {
        address owner;
        uint256 tokenId;
        uint256 attack;
        uint256 health;
        Coordinates[] moveRange;
        Coordinates[] attackRange;
        uint256 xIndex;
        uint256 yIndex;
    }

    struct Coordinates {
        uint256 x;
        uint256 y;
    }

    struct Player {
        address playerAddress;
        NFT[] nfts;
        uint256 baseHealth;
    }

    struct Cell {
        NFT nft;
        bool p1Control;
        bool p2Control;
    }

    struct BattleLog {
        Player player1;
        Player player2;
        uint256 rowCount;
        uint256 columnCount;
        mapping(uint256 row => mapping(uint256 column => Cell)) board;
    }

    mapping(uint256 battleId => BattleLog) private battles;

    uint256 private battleId;

    ///////////////////////////////////////////////////////////
    ///                   CORE FUNCTIONS                    ///
    ///////////////////////////////////////////////////////////

    function InitializeBattle(address player1, address player2, uint256 rowCount, uint256 columnCount) external {
        // Create a new battle log
        BattleLog storage battle = battles[battleId];

        // Set the players
        battle.player1.playerAddress = player1;
        battle.player2.playerAddress = player2;

        // Initialize the board
        battle.rowCount = rowCount;
        battle.columnCount = columnCount;
        initializeBoard(battle, rowCount, columnCount);
    }

    function initializeBoard(BattleLog storage battle, uint256 rowCount, uint256 columnCount) internal {
        // Initialize the empty board
        for (uint256 x = 0; x < rowCount; x++) {
            for (uint256 y = 0; y < columnCount; y++) {
                battle.board[x][y].nft.owner = address(0);
                battle.board[x][y].p1Control = false;
            }
        }

        // Player 1 controls the first column to start
        for (uint256 i = 0; i < rowCount; i++) {
            battle.board[i][0].p1Control = true;
        }

        // Player 2 controls the last column to start
        for (uint256 i = 0; i < rowCount; i++) {
            battle.board[i][columnCount - 1].p2Control = true;
        }
    }

    function placeNFT(uint256 _battleId, uint256 nftIndex, uint256 x, uint256 y) external {
        // Get the battle
        BattleLog storage battle = battles[_battleId];

        // Get the current player
        Player storage currentPlayer = msg.sender == battle.player1.playerAddress ? battle.player1 : battle.player2;

        // Ensure that the current player controls the cell
        require(isControlledByPlayer(battle, x, y, currentPlayer), "This cell is not controlled by you.");

        // Ensure the cell is empty
        require(battle.board[x][y].nft.owner == address(0), "Cell is already occupied.");

        // Place the NFT
        NFT storage nft = currentPlayer.nfts[nftIndex];
        nft.xIndex = x;
        nft.yIndex = y;
        battle.board[x][y].nft = nft;

        // Capture the next cell in front of the NFT if possible (next row)
        if (x < battle.columnCount - 1) {
            if (
                currentPlayer.playerAddress == battle.player1.playerAddress
                    && battle.board[x + 1][y].nft.owner == address(0)
            ) {
                // Player 1 controls the cell
                battle.board[x + 1][y].p1Control = true;
            }
        }
    }

    // Helper function to check if the player controls the cell
    function isControlledByPlayer(BattleLog storage battle, uint256 x, uint256 y, Player storage player)
        private
        view
        returns (bool)
    {
        address player1Address = battles[battleId].player1.playerAddress;

        if (player.playerAddress == player1Address) {
            return battle.board[x][y].p1Control;
        } else {
            return battle.board[x][y].p2Control;
        }
    }

    function moveNFT(uint256 _battleId, uint256 nftIndex, uint256 x, uint256 y) external {
        // Check if the space is captured by the player
        // Check if the space is captured by the opponent
        // Check if the space is unoccupied
        // Check if the space is within the range of the NFT
        // Capture the space
        // Move the NFT to the space
    }

    function attackNFT(uint256 nftIndex, uint256 x, uint256 y) external {
        // Check if the space is within the range of the NFT
        // Check if the space is occupied by an NFT
        // Calculate the attack
        // Reduce the health of the defending NFT
        // Remove the defending NFT if health is less than or equal to 0
    }

    function attackBase(uint256 nftIndex) external {
        // Check if the NFT is at the base
        // Calculate the attack
        // Reduce the health of the base
        // Remove the base if health is less than or equal to 0
    }

    ///////////////////////////////////////////////////////////
    ///                   GETTERS                           ///
    ///////////////////////////////////////////////////////////

    function getPlayer1(uint256 _battleId) external view returns (Player memory) {
        return battles[_battleId].player1;
    }

    function getPlayer2(uint256 _battleId) external view returns (Player memory) {
        return battles[_battleId].player2;
    }

    function getCell(uint256 _battleId, uint256 x, uint256 y) external view returns (Cell memory) {
        return battles[_battleId].board[x][y];
    }
}
