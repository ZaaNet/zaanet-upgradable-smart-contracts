// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IZaaNetStorage - Interface for ZaaNet Storage Contract (aligned with ZaaNetStorage.sol)
interface IZaaNetStorage {

    // ========== Structs ==========

    struct Network {
        uint256 id;
        address hostAddress;
        uint256 pricePerSession;
        string mongoDataId;
        bool isActive;
        uint256 createdAt;
        uint256 updatedAt;
    }

    // ========== Access Control ==========

    function setAllowedCaller(address _caller, bool status) external;
    function setAllowedCallers(address[] calldata _callers, bool status) external;

    // ========== Network Functions ==========

    function incrementNetworkId() external returns (uint256);
    function setNetwork(uint256 id, Network calldata network) external;
    function getNetwork(uint256 id) external view returns (Network memory);
    function getNetworksPaginated(uint256 offset, uint256 limit)
        external view returns (Network[] memory, uint256 total);
    function getHostNetworks(address hostAddress) external view returns (uint256[] memory);
    function networkIdCounter() external view returns (uint256);

    // ========== Earnings Functions ==========

    function increaseHostEarnings(address hostAddress, uint256 amount) external;
    function getHostEarnings(address hostAddress) external view returns (uint256);
    function increaseClientVoucherFeeEarnings(uint256 amount) external;
    function increaseHostVoucherFeeEarnings(uint256 amount) external;
    function updateTotalSessionPaymentsAmount(uint256 amount) external;
    function updateZaanetWithdrawalsAmount(uint256 amount) external;
    function updateZaanetHostingFeeEarnings(uint256 amount) external;

    // ========== Admin / Emergency ==========

    function emergencyDeactivateNetwork(uint256 networkId) external;
    function pause() external;
    function unpause() external;
}
