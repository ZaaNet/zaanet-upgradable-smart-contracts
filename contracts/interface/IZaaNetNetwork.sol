// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IZaaNetStorage.sol";

interface IZaaNetNetwork {
    // ========== Network Management ==========
    function registerNetwork(
        uint256 pricePerSession,
        string memory mongoDataId,
        bool isActive
    ) external;

    function updateNetwork(
        uint256 networkId,
        uint256 pricePerSession,
        bool isActive
    ) external;

    function deactivateNetwork(uint256 networkId) external;

    // ========== View Functions ==========

    function getHostedNetworkById(
        uint256 networkId
    ) external view returns (IZaaNetStorage.Network memory);

    function getHostNetworks(
        address hostAddress
    ) external view returns (uint256[] memory);

    function getActiveHostNetworks(
        address hostAddress
    ) external view returns (IZaaNetStorage.Network[] memory);

    // ========== Gas-Optimized View Functions ==========

    function getActiveHostNetworks(
        address hostAddress,
        uint256 offset,
        uint256 limit
    ) external view returns (IZaaNetStorage.Network[] memory);

    function getActiveHostNetworkCount(
        address hostAddress
    ) external view returns (uint256 count);

    function isRegisteredHost(address hostAddress) external view returns (bool);

    function getHostStats(
        address hostAddress
    )
        external
        view
        returns (
            uint256 totalNetworks,
            uint256 activeNetworks,
            uint256 totalEarnings
        );

    function getNetworksPaginated(
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (IZaaNetStorage.Network[] memory networks, uint256 totalCount);

    function getAllActiveNetworks()
        external
        view
        returns (IZaaNetStorage.Network[] memory);

    function getCurrentHostingFee() external view returns (uint256);

    function getTreasuryAddress() external view returns (address);

    function getContractStats() external view returns (uint256 totalNetworks);

    // ========== Admin Functions ==========

    function setAdminContract(address newAdminContract) external;

    function setUsdtContract(address newUsdt) external;

    function pause() external;

    function unpause() external;
}
