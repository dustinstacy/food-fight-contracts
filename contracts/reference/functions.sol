// /// @notice Withdraws the balance of the contract to the owner.
// /// @param to The address to send the funds to.
// /// @param amount The amount of funds to send.
// function withdraw(address to, uint256 amount) external onlyOwner {
//     // If no address is provided, send the funds to the owner.
//     if (to == address(0)) {
//         to = owner();
//     }

//     uint256 balance = address(this).balance;

//     if (amount > balance) {
//         revert AssetFactoryWithdrawalExceedsBalance(amount, balance);
//     }

//     (bool success,) = to.call{ value: amount }("");
//     if (!success) {
//         revert AssetFactoryWithdrawalFailed(to, amount);
//     }

//     emit Withdrawal(to, amount);
// }
