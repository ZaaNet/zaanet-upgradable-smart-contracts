// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ZaaNetStorage is Ownable, Pausable, ReentrancyGuard {
    struct Network {
        uint256 id;
        address hostAddress;
        uint256 pricePerSession;
        string mongoDataId;
        bool isActive;
        uint256 createdAt;
        uint256 updatedAt;
    }

    // Tracking variables
    mapping(address => bool) public allowedCallers; // Addresses allowed to call storage functions
    uint256 public networkIdCounter; // Counter for network IDs
    uint256 public totalSessionPaymentsAmount = 0; // Total amount processed through payments
    uint256 public zaanetWithdrawalsAmount = 0; // Total amount processed through withdrawals
    uint256 public zaanetHostingFeeEarnings = 0; // Total amount processed through network hosting fees

    // Voucher-related earnings
    uint256 public clientVoucherFeeEarnings = 0; // Total earnings from client voucher usage (redemptions)
    uint256 public hostVoucherFeeEarnings = 0; // Total earnings from host voucher registration fees

    // Mappings for data management
    mapping(uint256 => Network) public networks;
    mapping(address => uint256) public hostEarnings;
    mapping(address => uint256[]) public hostNetworkIds;
    mapping(uint256 => bool) public networkExists;

    modifier onlyAllowed() {
        require(
            allowedCallers[msg.sender] || msg.sender == owner(),
            "Not authorized"
        );
        _;
    }

    modifier whenStorageNotPaused() {
        require(!paused(), "Storage paused");
        _;
    }

    event AllowedCallerUpdated(address indexed caller, bool status);
    event NetworkStored(
        uint256 indexed id,
        address indexed hostAddress,
        uint256 pricePerSession
    );
    event NetworkUpdated(uint256 indexed id, address indexed hostAddress);
    event SessionStored(
        uint256 indexed sessionId,
        address indexed paymentAddress,
        uint256 amount
    );
    event HostEarningsUpdated(address indexed hostAddress, uint256 totalEarned);
    event ClientVoucherFeeEarningsUpdated(uint256 totalEarned);
    event HostVoucherFeeEarningsUpdated(uint256 totalEarned);

    // --- Constructor ---
    constructor() Ownable(msg.sender) {}

    // --- Caller Management ---
    function setAllowedCaller(address _caller, bool status) external onlyOwner {
        require(_caller != address(0), "Invalid caller address");
        allowedCallers[_caller] = status;
        emit AllowedCallerUpdated(_caller, status);
    }

    // Batch set allowed callers for initial setup
    function setAllowedCallers(
        address[] calldata _callers,
        bool status
    ) external onlyOwner {
        require(_callers.length <= 100, "Too many callers"); // Gas protection
        for (uint256 i = 0; i < _callers.length; i++) {
            require(_callers[i] != address(0), "Invalid caller address");
            allowedCallers[_callers[i]] = status;
            emit AllowedCallerUpdated(_callers[i], status);
        }
    }

    // --- Network Functions ---
    function incrementNetworkId()
        external
        onlyAllowed
        whenStorageNotPaused
        returns (uint256)
    {
        return ++networkIdCounter;
    }

    function setNetwork(
        uint256 id,
        Network calldata net
    ) external onlyAllowed whenStorageNotPaused nonReentrant {
        require(id > 0, "Invalid network ID");
        require(net.id == id, "Mismatched network ID");
        require(net.hostAddress != address(0), "Invalid host address");
        require(net.pricePerSession <= 50000000, "Price exceeds maximum"); // Allows zero for free sessions
        require(bytes(net.mongoDataId).length > 0, "MongoDataID required");

        bool isNewNetwork = !networkExists[id];

        if (!isNewNetwork) {
            require(
                networks[id].hostAddress == net.hostAddress,
                "Host change not allowed"
            );
        }

        networks[id] = Network({
            id: id,
            hostAddress: net.hostAddress,
            pricePerSession: net.pricePerSession,
            mongoDataId: net.mongoDataId,
            isActive: net.isActive,
            createdAt: isNewNetwork ? block.timestamp : networks[id].createdAt,
            updatedAt: block.timestamp
        });

        if (isNewNetwork) {
            networkExists[id] = true;
            hostNetworkIds[net.hostAddress].push(id);
            emit NetworkStored(id, net.hostAddress, net.pricePerSession);
        } else {
            emit NetworkUpdated(id, net.hostAddress);
        }
    }

    function getNetwork(uint256 id) external view returns (Network memory) {
        require(networkExists[id], "Network does not exist");
        return networks[id];
    }

    /// @notice Returns only networks that exist (networkExists[id]); total is networkIdCounter.
    function getNetworksPaginated(
        uint256 offset,
        uint256 limit
    ) external view returns (Network[] memory, uint256 total) {
        total = networkIdCounter;
        if (total == 0 || offset >= total) {
            return (new Network[](0), total);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        // First pass: count existing networks in range [offset+1, end] (IDs start at 1)
        uint256 existingCount = 0;
        for (uint256 i = offset; i < end; i++) {
            if (networkExists[i + 1]) {
                existingCount++;
            }
        }

        Network[] memory result = new Network[](existingCount);
        uint256 idx = 0;
        for (uint256 i = offset; i < end; i++) {
            uint256 networkId = i + 1; // Networks start at ID 1
            if (networkExists[networkId]) {
                result[idx] = networks[networkId];
                idx++;
            }
        }
        return (result, total);
    }

    function getHostNetworks(
        address hostAddress
    ) external view returns (uint256[] memory) {
        return hostNetworkIds[hostAddress];
    }

    // --- Earnings ---
    function increaseHostEarnings(
        address hostAddress,
        uint256 amount
    ) external onlyAllowed whenStorageNotPaused nonReentrant {
        require(hostAddress != address(0), "Invalid host address");
        require(amount > 0, "Amount must be greater than 0");

        hostEarnings[hostAddress] += amount;
        emit HostEarningsUpdated(hostAddress, hostEarnings[hostAddress]);
    }

    function getHostEarnings(
        address hostAddress
    ) external view returns (uint256) {
        return hostEarnings[hostAddress];
    }

    /// @notice Increase total earnings from client voucher usage (voucher redemptions)
    function increaseClientVoucherFeeEarnings(
        uint256 amount
    ) external onlyAllowed whenStorageNotPaused nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        clientVoucherFeeEarnings += amount;
        emit ClientVoucherFeeEarningsUpdated(clientVoucherFeeEarnings);
    }

    /// @notice Increase total earnings from host voucher registration fees
    function increaseHostVoucherFeeEarnings(
        uint256 amount
    ) external onlyAllowed whenStorageNotPaused nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        hostVoucherFeeEarnings += amount;
        emit HostVoucherFeeEarningsUpdated(hostVoucherFeeEarnings);
    }

    function updateTotalSessionPaymentsAmount(
        uint256 amount
    ) external onlyAllowed whenStorageNotPaused nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        totalSessionPaymentsAmount += amount;
    }

    function updateZaanetWithdrawalsAmount(
        uint256 amount
    ) external onlyAllowed whenStorageNotPaused nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        zaanetWithdrawalsAmount += amount;
    }

    function updateZaanetHostingFeeEarnings(
        uint256 amount
    ) external onlyAllowed whenStorageNotPaused nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        zaanetHostingFeeEarnings += amount;
    }

    // Emergency function to deactivate a network (callable by owner or allowed callers e.g. Admin)
    function emergencyDeactivateNetwork(uint256 networkId) external onlyAllowed {
        require(networkExists[networkId], "Network does not exist");
        if (!networks[networkId].isActive) {
            return; // Already inactive, no need to emit again
        }
        networks[networkId].isActive = false;
        networks[networkId].updatedAt = block.timestamp;
        emit NetworkUpdated(networkId, networks[networkId].hostAddress);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
