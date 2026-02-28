// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ZaaNetStorageV1.sol";
import "./interface/IZaaNetAdmin.sol";

/**
 * @title ZaaNetNetworkV1
 * @dev Upgradeable network contract for ZaaNet platform - Version 1
 * @notice Handles network registration, updates, and host management
 */
contract ZaaNetNetworkV1 is
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    ZaaNetStorageV1 public storageContract;
    IZaaNetAdmin public adminContract;
    IERC20 public usdt;

    // Constants for validation (updated for 6-decimal USDT)
    uint256 public constant MAX_PRICE_PER_SESSION = 50000000; // 50 USDT (6 decimals)
    uint256 public constant MIN_PRICE_PER_SESSION = 100; // 0.0001 USDT minimum to prevent abuse
    uint256 public constant MAX_MONGO_DATA_LENGTH = 200; // Reasonable limit for data ID

    // Gas limit protections
    uint256 public constant MAX_NETWORKS_PER_HOST = 100; // Maximum networks a single host can have
    uint256 public constant MAX_BATCH_SIZE = 50; // Maximum batch operations

    mapping(address => bool) public isHost;
    mapping(address => uint256[]) private hostNetworks;
    mapping(uint256 => address) public networkToHost; // For quick lookups

    // Rate limiting
    mapping(address => uint256) public lastRegistrationTime;
    uint256 public constant REGISTRATION_COOLDOWN = 1 minutes;

    // Enhanced events
    event NetworkRegistered(
        uint256 indexed networkId,
        address indexed hostAddress,
        string mongoDataId,
        uint256 pricePerSession,
        bool isActive,
        uint256 hostingFeePaid,
        uint256 timestamp
    );

    event HostingFeePaid(
        address indexed host,
        uint256 amount,
        uint256 timestamp
    );

    event NetworkUpdated(
        uint256 indexed networkId,
        address indexed hostAddress,
        uint256 pricePerSession,
        string mongoDataId,
        bool isActive
    );

    event NetworkPriceUpdated(
        uint256 indexed networkId,
        uint256 oldPrice,
        uint256 newPrice
    );

    event NetworkStatusChanged(
        uint256 indexed networkId,
        bool oldStatus,
        bool newStatus
    );

    event HostAdded(address indexed host);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    /// @dev Required by UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(
        address _storageContract,
        address _adminContract,
        address _usdt
    ) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();

        require(
            _storageContract != address(0),
            "Invalid storage contract address"
        );
        require(_adminContract != address(0), "Invalid admin contract address");
        require(_usdt != address(0), "Invalid USDT contract address");

        storageContract = ZaaNetStorageV1(_storageContract);
        adminContract = IZaaNetAdmin(_adminContract);
        usdt = IERC20(_usdt);
    }

    /// @notice Register a new network with mongoDataID and pay hosting fee
    function registerNetwork(
        uint256 _pricePerSession,
        string memory _mongoDataId,
        bool _isActive
    ) external whenNotPaused nonReentrant {
        require(!adminContract.emergencyMode(), "Emergency mode active");
        require(
            block.timestamp >=
                lastRegistrationTime[msg.sender] + REGISTRATION_COOLDOWN,
            "Registration cooldown active"
        );
        require(
            _pricePerSession >= MIN_PRICE_PER_SESSION &&
                _pricePerSession <= MAX_PRICE_PER_SESSION,
            "Price out of allowed range"
        );
        require(
            bytes(_mongoDataId).length > 0 &&
                bytes(_mongoDataId).length <= MAX_MONGO_DATA_LENGTH,
            "Invalid MongoDataID length"
        );

        // Check host network limit to prevent gas exhaustion attacks
        require(
            !storageContract.hasReachedNetworkLimit(msg.sender),
            "Host has reached maximum network limit"
        );

        // Get hosting fee from admin contract
        uint256 hostingFee = adminContract.hostingFee();

        // Request a new ID from storage FIRST (before any payments)
        uint256 networkId = storageContract.incrementNetworkId();

        // Save the network details into storage
        storageContract.setNetwork(
            networkId,
            ZaaNetStorageV1.Network({
                id: networkId,
                hostAddress: msg.sender,
                pricePerSession: _pricePerSession,
                mongoDataId: _mongoDataId,
                isActive: _isActive,
                createdAt: block.timestamp,
                updatedAt: block.timestamp
            })
        );

        hostNetworks[msg.sender].push(networkId);
        networkToHost[networkId] = msg.sender;
        lastRegistrationTime[msg.sender] = block.timestamp;

        if (!isHost[msg.sender]) {
            isHost[msg.sender] = true;
            emit HostAdded(msg.sender);
        }

        // Collect hosting fee AFTER successful network registration
        if (hostingFee > 0) {
            address treasuryAddress = adminContract.treasuryAddress();
            require(treasuryAddress != address(0), "Treasury not configured");

            require(
                usdt.balanceOf(msg.sender) >= hostingFee,
                "Insufficient USDT balance for hosting fee"
            );
            require(
                usdt.allowance(msg.sender, address(this)) >= hostingFee,
                "Hosting fee not approved"
            );

            // Transfer hosting fee to treasury
            usdt.safeTransferFrom(msg.sender, treasuryAddress, hostingFee);

            // Increase ZaaNet total hosting fee earnings in storage
            storageContract.updateTotalHostingFeeAmount(hostingFee);

            emit HostingFeePaid(msg.sender, hostingFee, block.timestamp);
        }

        emit NetworkRegistered(
            networkId,
            msg.sender,
            _mongoDataId,
            _pricePerSession,
            _isActive,
            hostingFee,
            block.timestamp
        );
    }

    /// @notice Internal function to update network details
    function _updateNetwork(
        uint256 _networkId,
        uint256 _pricePerSession,
        bool _isActive,
        address sender
    ) internal {
        ZaaNetStorageV1.Network memory network = storageContract.getNetwork(
            _networkId
        );
        require(network.hostAddress == sender, "Only host can update");
        require(
            _pricePerSession >= 0 &&
                _pricePerSession >= MIN_PRICE_PER_SESSION &&
                _pricePerSession <= MAX_PRICE_PER_SESSION,
            "Price out of allowed range"
        );

        uint256 oldPrice = network.pricePerSession;
        bool oldStatus = network.isActive;

        storageContract.setNetwork(
            _networkId,
            ZaaNetStorageV1.Network({
                id: _networkId,
                hostAddress: sender,
                pricePerSession: _pricePerSession,
                mongoDataId: network.mongoDataId,
                isActive: _isActive,
                createdAt: network.createdAt,
                updatedAt: block.timestamp
            })
        );

        if (oldPrice != _pricePerSession) {
            emit NetworkPriceUpdated(_networkId, oldPrice, _pricePerSession);
        }
        if (oldStatus != _isActive) {
            emit NetworkStatusChanged(_networkId, oldStatus, _isActive);
        }

        emit NetworkUpdated(
            _networkId,
            sender,
            _pricePerSession,
            network.mongoDataId,
            _isActive
        );
    }

    /// @notice Update existing network with new details
    function updateNetwork(
        uint256 _networkId,
        uint256 _pricePerSession,
        bool _isActive
    ) external whenNotPaused nonReentrant {
        require(!adminContract.emergencyMode(), "Emergency mode active");
        _updateNetwork(_networkId, _pricePerSession, _isActive, msg.sender);
    }

    /// @notice Deactivate a network (soft delete)
    function deactivateNetwork(
        uint256 _networkId
    ) external whenNotPaused nonReentrant {
        require(!adminContract.emergencyMode(), "Emergency mode active");
        ZaaNetStorageV1.Network memory network = storageContract.getNetwork(
            _networkId
        );
        require(network.hostAddress == msg.sender, "Only host can deactivate");
        require(network.isActive, "Network already inactive");

        _updateNetwork(_networkId, network.pricePerSession, false, msg.sender);
    }

    /// @notice Get full network details from storage
    function getHostedNetworkById(
        uint256 _networkId
    ) external view returns (ZaaNetStorageV1.Network memory) {
        return storageContract.getNetwork(_networkId);
    }

    /// @notice Get all network IDs registered by a host
    function getHostNetworks(
        address hostAddress
    ) external view returns (uint256[] memory) {
        return hostNetworks[hostAddress];
    }

    /// @notice Get active networks for a host with pagination
    /// @param hostAddress The host's address
    /// @param offset Starting index for pagination
    /// @param limit Maximum number of networks to return
    function getActiveHostNetworks(
        address hostAddress,
        uint256 offset,
        uint256 limit
    ) external view returns (ZaaNetStorageV1.Network[] memory) {
        uint256[] memory networkIds = hostNetworks[hostAddress];

        // Apply gas limit protection
        if (limit > MAX_BATCH_SIZE) {
            limit = MAX_BATCH_SIZE;
        }

        // First pass: count active networks within range
        uint256 activeCount = 0;
        uint256 endIndex = offset + limit;
        if (endIndex > networkIds.length) {
            endIndex = networkIds.length;
        }

        for (uint256 i = offset; i < endIndex; i++) {
            ZaaNetStorageV1.Network memory network = storageContract.getNetwork(
                networkIds[i]
            );
            if (network.isActive) {
                activeCount++;
            }
        }

        // Second pass: collect active networks
        ZaaNetStorageV1.Network[]
            memory activeNetworks = new ZaaNetStorageV1.Network[](activeCount);
        uint256 index = 0;
        for (uint256 i = offset; i < endIndex; i++) {
            ZaaNetStorageV1.Network memory network = storageContract.getNetwork(
                networkIds[i]
            );
            if (network.isActive) {
                activeNetworks[index] = network;
                index++;
            }
        }

        return activeNetworks;
    }

    /// @notice Get total active network count for a host (gas efficient)
    function getActiveHostNetworkCount(
        address hostAddress
    ) external view returns (uint256 count) {
        uint256[] memory networkIds = hostNetworks[hostAddress];
        for (uint256 i = 0; i < networkIds.length; i++) {
            ZaaNetStorageV1.Network memory network = storageContract.getNetwork(
                networkIds[i]
            );
            if (network.isActive) {
                count++;
            }
        }
    }

    /// @notice Public method to check if an address is a registered host
    function isRegisteredHost(
        address hostAddress
    ) external view returns (bool) {
        return isHost[hostAddress];
    }

    /// @notice Get host statistics
    function getHostStats(
        address hostAddress
    )
        external
        view
        returns (
            uint256 totalNetworks,
            uint256 activeNetworks,
            uint256 totalEarnings
        )
    {
        totalNetworks = hostNetworks[hostAddress].length;
        totalEarnings = storageContract.getHostEarnings(hostAddress);

        uint256[] memory networkIds = hostNetworks[hostAddress];
        for (uint256 i = 0; i < networkIds.length; i++) {
            ZaaNetStorageV1.Network memory network = storageContract.getNetwork(
                networkIds[i]
            );
            if (network.isActive) {
                activeNetworks++;
            }
        }
    }

    /// @notice Retrieve networks with pagination (gas-optimized)
    function getNetworksPaginated(
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (ZaaNetStorageV1.Network[] memory networks, uint256 totalCount)
    {
        return storageContract.getNetworksPaginated(offset, limit);
    }

    /// @notice Get all active networks (limited to prevent gas issues)
    function getAllActiveNetworks()
        external
        view
        returns (ZaaNetStorageV1.Network[] memory)
    {
        (ZaaNetStorageV1.Network[] memory allNetworks, ) = storageContract
            .getNetworksPaginated(0, 100);
        uint256 activeCount = 0;

        for (uint256 i = 0; i < allNetworks.length; i++) {
            if (allNetworks[i].isActive) {
                activeCount++;
            }
        }

        ZaaNetStorageV1.Network[]
            memory activeNetworks = new ZaaNetStorageV1.Network[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allNetworks.length; i++) {
            if (allNetworks[i].isActive) {
                activeNetworks[index] = allNetworks[i];
                index++;
            }
        }

        return activeNetworks;
    }

    /// @notice Get current hosting fee
    function getCurrentHostingFee() external view returns (uint256) {
        return adminContract.hostingFee();
    }

    /// @notice Get treasury address
    function getTreasuryAddress() external view returns (address) {
        return adminContract.treasuryAddress();
    }

    // --- Admin Functions ---

    /// @notice Update admin contract address (owner only)
    function setAdminContract(address _newAdminContract) external onlyOwner {
        require(_newAdminContract != address(0), "Invalid admin contract");
        adminContract = IZaaNetAdmin(_newAdminContract);
    }

    /// @notice Update USDT contract address (owner only)
    function setUsdtContract(address _newUsdt) external onlyOwner {
        require(_newUsdt != address(0), "Invalid USDT contract");
        usdt = IERC20(_newUsdt);
    }

    /// @notice Emergency pause (only owner)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause (only owner)
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Get contract statistics
    function getContractStats() external view returns (uint256 totalNetworks) {
        totalNetworks = storageContract.networkIdCounter();
    }

    // Storage gap for future upgrades
    uint256[50] private __gap;
}
