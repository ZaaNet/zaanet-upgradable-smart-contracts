// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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

    function processBatchPayments(BatchPayment[] calldata payments) external;

    // ========== View Functions ==========
    function isVoucherProcessed(
        bytes32 _voucherId
    ) external view returns (bool);

    function getTodayWithdrawals() external view returns (uint256);

    function getRemainingDailyLimit() external view returns (uint256);

    function contractTokenBalance() external view returns (uint256);

    // ========== Admin Functions ==========
    function setDailyWithdrawalLimit(uint256 _newLimit) external;

    // ========== Token Whitelist Functions ==========
    function addTokenToWhitelist(address _token) external;

    function removeTokenFromWhitelist(address _token) external;

    function isTokenWhitelisted(address _token) external view returns (bool);

    function getWhitelistedTokens() external view returns (address[] memory);

    function pause() external;

    function unpause() external;
}
