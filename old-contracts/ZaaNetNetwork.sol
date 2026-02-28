// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ZaaNetStorage.sol";
import "./interface/IZaaNetAdmin.sol";

contract ZaaNetNetwork is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    ZaaNetStorage public storageContract;
    IZaaNetAdmin public adminContract;
    IERC20 public usdt;

    // Constants for validation (updated for 6-decimal USDT)
    uint256 public constant MAX_PRICE_PER_SESSION = 50000000; // 50 USDT (6 decimals)
    uint256 public constant MIN_PRICE_PER_SESSION = 100; // 0.0001 USDT minimum to prevent abuse
    uint256 public constant MAX_MONGO_DATA_LENGTH = 200; // Reasonable limit for data ID

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

    constructor(
        address _storageContract,
        address _adminContract,
        address _usdt
    ) Ownable(msg.sender) {
        require(
            _storageContract != address(0),
            "Invalid storage contract address"
        );
        require(_adminContract != address(0), "Invalid admin contract address");
        require(_usdt != address(0), "Invalid USDT contract address");

        storageContract = ZaaNetStorage(_storageContract);
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

        // Get hosting fee from admin contract
        uint256 hostingFee = adminContract.hostingFee();

        // Request a new ID from storage FIRST (before any payments)
        uint256 networkId = storageContract.incrementNetworkId();

        // Save the network details into storage
        // If this fails, no fee has been paid yet
        storageContract.setNetwork(
            networkId,
            ZaaNetStorage.Network({
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
            storageContract.updateZaanetHostingFeeEarnings(hostingFee);

            emit HostingFeePaid(msg.sender, hostingFee, block.timestamp);
        }

        // Enhanced event with hosting fee information
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
        ZaaNetStorage.Network memory network = storageContract.getNetwork(
            _networkId
        );
        require(network.hostAddress == sender, "Only host can update");
        require(
            _pricePerSession >= 0 &&
            _pricePerSession >= MIN_PRICE_PER_SESSION &&
                _pricePerSession <= MAX_PRICE_PER_SESSION,
            "Price out of allowed range"
        ); // Allowing zero price for free sessions

        // Store old values for events
        uint256 oldPrice = network.pricePerSession;
        bool oldStatus = network.isActive;

        storageContract.setNetwork(
            _networkId,
            ZaaNetStorage.Network({
                id: _networkId,
                hostAddress: sender,
                pricePerSession: _pricePerSession,
                mongoDataId: network.mongoDataId, // Keep existing metadata
                isActive: _isActive,
                createdAt: network.createdAt, // Keep original creation time
                updatedAt: block.timestamp
            })
        );

        // Emit detailed events for better tracking
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
    function deactivateNetwork(uint256 _networkId) external whenNotPaused nonReentrant {
        require(!adminContract.emergencyMode(), "Emergency mode active");
        ZaaNetStorage.Network memory network = storageContract.getNetwork(
            _networkId
        );
        require(network.hostAddress == msg.sender, "Only host can deactivate");
        require(network.isActive, "Network already inactive");

        _updateNetwork(_networkId, network.pricePerSession, false, msg.sender);
    }

    /// @notice Get full network details from storage
    function getHostedNetworkById(
        uint256 _networkId
    ) external view returns (ZaaNetStorage.Network memory) {
        return storageContract.getNetwork(_networkId);
    }

    /// @notice Get all network IDs registered by a host
    function getHostNetworks(
        address hostAddress
    ) external view returns (uint256[] memory) {
        return hostNetworks[hostAddress];
    }

    /// @notice Get active networks for a host
    function getActiveHostNetworks(
        address hostAddress
    ) external view returns (ZaaNetStorage.Network[] memory) {
        uint256[] memory networkIds = hostNetworks[hostAddress];
        uint256 activeCount = 0;

        // First pass: count active networks
        for (uint256 i = 0; i < networkIds.length; i++) {
            ZaaNetStorage.Network memory network = storageContract.getNetwork(
                networkIds[i]
            );
            if (network.isActive) {
                activeCount++;
            }
        }

        // Second pass: populate active networks
        ZaaNetStorage.Network[]
            memory activeNetworks = new ZaaNetStorage.Network[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < networkIds.length; i++) {
            ZaaNetStorage.Network memory network = storageContract.getNetwork(
                networkIds[i]
            );
            if (network.isActive) {
                activeNetworks[index] = network;
                index++;
            }
        }

        return activeNetworks;
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

        // Count active networks
        uint256[] memory networkIds = hostNetworks[hostAddress];
        for (uint256 i = 0; i < networkIds.length; i++) {
            ZaaNetStorage.Network memory network = storageContract.getNetwork(
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
        returns (ZaaNetStorage.Network[] memory networks, uint256 totalCount)
    {
        return storageContract.getNetworksPaginated(offset, limit);
    }

    /// @notice Get all active networks (limited to prevent gas issues)
    function getAllActiveNetworks()
        external
        view
        returns (ZaaNetStorage.Network[] memory)
    {
        (ZaaNetStorage.Network[] memory allNetworks, ) = storageContract
            .getNetworksPaginated(0, 100);
        uint256 activeCount = 0;

        // Count active networks first
        for (uint256 i = 0; i < allNetworks.length; i++) {
            if (allNetworks[i].isActive) {
                activeCount++;
            }
        }

        // Create properly sized array and populate with active networks
        ZaaNetStorage.Network[]
            memory activeNetworks = new ZaaNetStorage.Network[](activeCount);
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
}
