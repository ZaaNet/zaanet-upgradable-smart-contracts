// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IZaaNetPayment - Interface for ZaaNet Payment Contract
interface IZaaNetPayment {
    struct BatchPayment {
        uint256 contractId;
        uint256 grossAmount;
        bytes32 voucherId;
    }

    // ========== Payment Management ==========
    function processPayment(
        uint256 _contractId,
        uint256 _grossAmount,
        bytes32 _voucherId
    ) external;

    function processBatchPayments(
        BatchPayment[] calldata payments
    ) external;

    // ========== View Functions ==========
    function isVoucherProcessed(bytes32 _voucherId) external view returns (bool);
    function getTodayWithdrawals() external view returns (uint256);
    function getRemainingDailyLimit() external view returns (uint256);
    function contractTokenBalance() external view returns (uint256);

    // ========== Admin Functions ==========
    function setDailyWithdrawalLimit(uint256 _newLimit) external;
    function pause() external;
    function unpause() external;
}