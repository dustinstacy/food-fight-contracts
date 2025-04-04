//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// BattlePassStaking contract where users can stake their tokens and earn rewards.

// The rewards are distributed from a reward pool that is funded by the BattlePass contract.

// The reward pool is funded through BattlePass fees and yield farming rewards.

// Users can stake their tokens for a certain period of time, and they will earn rewards based on the amount of tokens they have
// staked and the duration of the stake.

// Users can unstake their tokens after the set period, but they will lose
// any rewards that they have not claimed.

// Users can claim their rewards at any time, and they will be
// transferred to their wallet.

// The BattlePass contract can also set the reward distribution rate, which determines how much of the reward pool is distributed
// to stakers each day.

// The BattlePass contract can also set the minimum stake amount, the minimum stake duration, and the maximum stake duration.

// The BattlePass contract can also set the early unstake penalty, which is a percentage of the staked amount that is deducted
// if the user unstakes before the minimum stake duration.
