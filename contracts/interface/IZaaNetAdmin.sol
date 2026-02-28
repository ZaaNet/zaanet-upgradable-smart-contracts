// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IZaaNetAdmin - Interface for ZaaNet Admin Contract
interface IZaaNetAdmin {
    // ========== Admin Functions ==========

    function setPlatformFee(uint256 _newFeePercent) external;

    function setHostingFee(uint256 _newFee) external;

    function setHostVoucherFeeHours(uint256 _fee) external;

    function setHostVoucherFeeDays(uint256 _fee) external;

    function setHostVoucherFeeMonths(uint256 _fee) external;

    function setTreasuryAddress(address _newTreasury) external;

    function setPaymentAddress(address _newPaymentAddress) external;

    function setEmergencyOperator(address operator, bool status) external;

    function pause() external;

    function unpause() external;

    function toggleEmergencyMode() external;

    function emergencyDeactivateNetwork(uint256 networkId) external;

    function emergencySetPlatformFee(uint256 _newFeePercent) external;

    function emergencySetHostingFee(uint256 _newFee) external;

    // ========== View Functions ==========

    function platformFeePercent() external view returns (uint256);

    function paymentAddress() external view returns (address);

    function hostingFee() external view returns (uint256);

    function getHostVoucherFeeTier(uint8 tier) external view returns (uint256);

    function treasuryAddress() external view returns (address);

    function treasury() external view returns (address);

    function owner() external view returns (address);

    function admin() external view returns (address);

    function paused() external view returns (bool);

    function emergencyMode() external view returns (bool);

    function isEmergencyOperator(address operator) external view returns (bool);

    function calculatePlatformFee(
        uint256 amount
    ) external view returns (uint256);

    function getPlatformFeeBasisPoints() external view returns (uint256);

    function getCurrentFees()
        external
        view
        returns (
            uint256 platformFeePercentage,
            uint256 hostingFeeAmount,
            address treasury
        );

    function getAdminStats()
        external
        view
        returns (
            uint256 totalFeeChanges,
            uint256 totalTreasuryChanges,
            uint256 totalHostingFeeChanges,
            bool isEmergencyMode,
            uint256 currentPlatformFee,
            uint256 currentHostingFee,
            address currentTreasury
        );
}
