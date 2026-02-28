// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./utils/ReentrancyGuardUpgradeable.sol";
import "./ZaaNetStorageV1.sol";

/**
 * @title ZaaNetAdminV1
 * @dev Upgradeable admin contract for ZaaNet platform - Version 1
 * @notice Manages fees, treasury, and administrative functions
 */
contract ZaaNetAdminV1 is
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // Maximum fees
    uint256 public constant MAX_PLATFORM_FEE = 20; // 20% maximum
    uint256 public constant MAX_HOSTING_FEE = 100 * (10 ** 6); // 100 USDT max
    uint256 public constant MAX_HOST_VOUCHER_FEE = 100 * (10 ** 6); // 100 USDT max per tier

    ZaaNetStorageV1 public storageContract;
    address public treasuryAddress; // Address to receive platform fees
    address public paymentAddress; // Address to make voucher payments
    uint256 public platformFeePercent; // Platform fee percentage (1-20%)
    uint256 public hostingFee; // Hosting fee in USDT (6 decimals)

    // Host voucher registration fee per voucher (USDT 6 decimals): tier 0 = hours (≤24h), tier 1 = days (≤30d), tier 2 = months (>30d)
    uint256 public hostVoucherFeeHours;
    uint256 public hostVoucherFeeDays;
    uint256 public hostVoucherFeeMonths;

    // Emergency controls
    bool public emergencyMode;
    mapping(address => bool) public emergencyOperators;

    // Time lock for emergency toggles - prevents rapid toggling
    uint256 public constant EMERGENCY_COOLDOWN = 1 hours;
    uint256 public lastEmergencyToggleTime;
    mapping(address => uint256) public lastEmergencyToggleBy;

    // Fee history for transparency
    struct FeeChange {
        uint256 oldFee;
        uint256 newFee;
        uint256 timestamp;
        address changedBy;
    }

    FeeChange[] public feeHistory;

    // Treasury change history
    struct TreasuryChange {
        address oldTreasury;
        address newTreasury;
        uint256 timestamp;
        address changedBy;
    }

    TreasuryChange[] public treasuryHistory;

    // Hosting fee history
    struct HostingFeeChange {
        uint256 oldFee;
        uint256 newFee;
        uint256 timestamp;
        address changedBy;
    }

    HostingFeeChange[] public hostingFeeHistory;

    // Events
    event PlatformFeeUpdated(
        uint256 indexed oldFee,
        uint256 indexed newFee,
        address indexed changedBy
    );
    event TreasuryUpdated(
        address indexed oldTreasury,
        address indexed newTreasury,
        address indexed changedBy
    );
    event HostingFeeUpdated(
        uint256 indexed oldFee,
        uint256 indexed newFee,
        address indexed changedBy
    );
    event HostVoucherFeeTierUpdated(
        uint8 indexed tier,
        uint256 indexed newFee,
        address indexed changedBy
    );
    event PaymentAddressUpdated(
        address indexed oldAddress,
        address indexed newAddress,
        address indexed changedBy
    );
    event AdminPaused(address indexed triggeredBy);
    event AdminUnpaused(address indexed triggeredBy);
    event EmergencyModeToggled(bool enabled, address indexed triggeredBy);
    event EmergencyOperatorUpdated(
        address indexed operator,
        bool status,
        address indexed updatedBy
    );
    event ContractsInitialized(
        address indexed storageContract,
        uint256 timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    /// @dev Required by UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(
        address _storageContract,
        address _treasuryAddress,
        address _paymentAddress,
        uint256 _platformFeePercent,
        uint256 _hostingFee
    ) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();

        // Initialize state variables
        emergencyMode = false;
        lastEmergencyToggleTime = 0;

        require(
            _treasuryAddress != address(0),
            "Treasury cannot be zero address"
        );
        require(
            _platformFeePercent <= MAX_PLATFORM_FEE,
            "Platform fee exceeds maximum"
        );
        require(
            _paymentAddress != address(0),
            "Payment address cannot be zero address"
        );
        require(_hostingFee <= MAX_HOSTING_FEE, "Hosting fee exceeds maximum");

        if (_storageContract != address(0)) {
            storageContract = ZaaNetStorageV1(_storageContract);
            emit ContractsInitialized(_storageContract, block.timestamp);
        }

        treasuryAddress = _treasuryAddress;
        paymentAddress = _paymentAddress;
        platformFeePercent = _platformFeePercent;
        hostingFee = _hostingFee;

        // Record initial settings
        feeHistory.push(
            FeeChange({
                oldFee: 0,
                newFee: _platformFeePercent,
                timestamp: block.timestamp,
                changedBy: msg.sender
            })
        );

        treasuryHistory.push(
            TreasuryChange({
                oldTreasury: address(0),
                newTreasury: _treasuryAddress,
                timestamp: block.timestamp,
                changedBy: msg.sender
            })
        );

        hostingFeeHistory.push(
            HostingFeeChange({
                oldFee: 0,
                newFee: _hostingFee,
                timestamp: block.timestamp,
                changedBy: msg.sender
            })
        );

        // Set owner as emergency operator
        emergencyOperators[msg.sender] = true;
        emit EmergencyOperatorUpdated(msg.sender, true, msg.sender);
    }

    modifier onlyEmergencyOperator() {
        require(
            emergencyOperators[msg.sender] || msg.sender == owner(),
            "Not emergency operator"
        );
        _;
    }

    modifier notInEmergencyMode() {
        require(!emergencyMode, "System in emergency mode");
        _;
    }

    function setPlatformFee(
        uint256 _newFeePercent
    ) external onlyOwner notInEmergencyMode {
        require(_newFeePercent <= MAX_PLATFORM_FEE, "Fee exceeds maximum");
        require(_newFeePercent != platformFeePercent, "Fee unchanged");

        uint256 oldFee = platformFeePercent;
        platformFeePercent = _newFeePercent;

        // Record fee change
        feeHistory.push(
            FeeChange({
                oldFee: oldFee,
                newFee: _newFeePercent,
                timestamp: block.timestamp,
                changedBy: msg.sender
            })
        );

        emit PlatformFeeUpdated(oldFee, _newFeePercent, msg.sender);
    }

    function setHostingFee(
        uint256 _newFee
    ) external onlyOwner notInEmergencyMode {
        require(_newFee <= MAX_HOSTING_FEE, "Fee exceeds maximum");
        require(_newFee != hostingFee, "Fee unchanged");

        uint256 oldFee = hostingFee;
        hostingFee = _newFee;

        // Record hosting fee change
        hostingFeeHistory.push(
            HostingFeeChange({
                oldFee: oldFee,
                newFee: _newFee,
                timestamp: block.timestamp,
                changedBy: msg.sender
            })
        );

        emit HostingFeeUpdated(oldFee, _newFee, msg.sender);
    }

    /// @notice Set host voucher registration fee for hours tier (≤24h), USDT 6 decimals
    function setHostVoucherFeeHours(
        uint256 _fee
    ) external onlyOwner notInEmergencyMode {
        require(_fee <= MAX_HOST_VOUCHER_FEE, "Fee exceeds maximum");
        hostVoucherFeeHours = _fee;
        emit HostVoucherFeeTierUpdated(0, _fee, msg.sender);
    }

    /// @notice Set host voucher registration fee for days tier (≤30d), USDT 6 decimals
    function setHostVoucherFeeDays(
        uint256 _fee
    ) external onlyOwner notInEmergencyMode {
        require(_fee <= MAX_HOST_VOUCHER_FEE, "Fee exceeds maximum");
        hostVoucherFeeDays = _fee;
        emit HostVoucherFeeTierUpdated(1, _fee, msg.sender);
    }

    /// @notice Set host voucher registration fee for months tier (>30d), USDT 6 decimals
    function setHostVoucherFeeMonths(
        uint256 _fee
    ) external onlyOwner notInEmergencyMode {
        require(_fee <= MAX_HOST_VOUCHER_FEE, "Fee exceeds maximum");
        hostVoucherFeeMonths = _fee;
        emit HostVoucherFeeTierUpdated(2, _fee, msg.sender);
    }

    function setTreasuryAddress(
        address _newTreasuryAddress
    ) external onlyOwner notInEmergencyMode {
        require(_newTreasuryAddress != address(0), "Invalid treasury address");
        require(_newTreasuryAddress != treasuryAddress, "Treasury unchanged");

        address oldTreasury = treasuryAddress;
        treasuryAddress = _newTreasuryAddress;

        // Record treasury change
        treasuryHistory.push(
            TreasuryChange({
                oldTreasury: oldTreasury,
                newTreasury: _newTreasuryAddress,
                timestamp: block.timestamp,
                changedBy: msg.sender
            })
        );

        emit TreasuryUpdated(oldTreasury, _newTreasuryAddress, msg.sender);
    }

    function setPaymentAddress(
        address _newPaymentAddress
    ) external onlyOwner notInEmergencyMode {
        require(_newPaymentAddress != address(0), "Invalid payment address");
        require(
            _newPaymentAddress != paymentAddress,
            "Payment address unchanged"
        );

        address oldPaymentAddress = paymentAddress;
        paymentAddress = _newPaymentAddress;
        emit PaymentAddressUpdated(
            oldPaymentAddress,
            _newPaymentAddress,
            msg.sender
        );
    }

    function pause() external onlyOwner {
        _pause();
        emit AdminPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit AdminUnpaused(msg.sender);
    }

    /// @notice Toggle emergency mode (stops most operations)
    /// @dev Has a cooldown to prevent rapid toggling
    function toggleEmergencyMode() external onlyEmergencyOperator {
        // Check cooldown - either global or per-operator
        uint256 lastToggle = lastEmergencyToggleBy[msg.sender];
        if (lastToggle == 0) {
            lastToggle = lastEmergencyToggleTime; // Fallback to global for backwards compatibility
        }
        require(
            block.timestamp >= lastToggle + EMERGENCY_COOLDOWN,
            "Emergency toggle on cooldown"
        );

        emergencyMode = !emergencyMode;
        lastEmergencyToggleTime = block.timestamp;
        lastEmergencyToggleBy[msg.sender] = block.timestamp;
        emit EmergencyModeToggled(emergencyMode, msg.sender);
    }

    /// @notice Add or remove emergency operators
    function setEmergencyOperator(
        address operator,
        bool status
    ) external onlyOwner {
        require(operator != address(0), "Invalid operator address");
        emergencyOperators[operator] = status;
        emit EmergencyOperatorUpdated(operator, status, msg.sender);
    }

    /// @notice Emergency function to deactivate a network
    function emergencyDeactivateNetwork(
        uint256 networkId
    ) external onlyEmergencyOperator {
        require(
            address(storageContract) != address(0),
            "Storage not initialized"
        );
        storageContract.emergencyDeactivateNetwork(networkId);
    }

    /// @notice Emergency function to set platform fee (bypasses normal restrictions)
    function emergencySetPlatformFee(
        uint256 _newFeePercent
    ) external onlyEmergencyOperator {
        require(_newFeePercent <= MAX_PLATFORM_FEE, "Fee exceeds maximum");
        uint256 oldFee = platformFeePercent;
        platformFeePercent = _newFeePercent;
        feeHistory.push(
            FeeChange({
                oldFee: oldFee,
                newFee: _newFeePercent,
                timestamp: block.timestamp,
                changedBy: msg.sender
            })
        );
        emit PlatformFeeUpdated(oldFee, _newFeePercent, msg.sender);
    }

    /// @notice Emergency function to set hosting fee (bypasses normal restrictions)
    function emergencySetHostingFee(
        uint256 _newFee
    ) external onlyEmergencyOperator {
        require(_newFee <= MAX_HOSTING_FEE, "Fee exceeds maximum");
        uint256 oldFee = hostingFee;
        hostingFee = _newFee;
        hostingFeeHistory.push(
            HostingFeeChange({
                oldFee: oldFee,
                newFee: _newFee,
                timestamp: block.timestamp,
                changedBy: msg.sender
            })
        );
        emit HostingFeeUpdated(oldFee, _newFee, msg.sender);
    }

    // --- View Functions ---

    /// @notice Expose admin address for other contracts (interface compatibility)
    function admin() external view returns (address) {
        return owner();
    }

    /// @notice Get fee change history
    function getFeeHistory() external view returns (FeeChange[] memory) {
        return feeHistory;
    }

    /// @notice Get treasury change history
    function getTreasuryHistory()
        external
        view
        returns (TreasuryChange[] memory)
    {
        return treasuryHistory;
    }

    /// @notice Get hosting fee change history
    function getHostingFeeHistory()
        external
        view
        returns (HostingFeeChange[] memory)
    {
        return hostingFeeHistory;
    }

    /// @notice Get current fee in basis points (for more precise calculations)
    function getPlatformFeeBasisPoints() external view returns (uint256) {
        return platformFeePercent * 100; // Convert percentage to basis points
    }

    /// @notice Calculate platform fee for a given amount
    function calculatePlatformFee(
        uint256 amount
    ) external view returns (uint256) {
        return (amount * platformFeePercent) / 100;
    }

    /// @notice Get comprehensive admin statistics
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
        )
    {
        totalFeeChanges = feeHistory.length;
        totalTreasuryChanges = treasuryHistory.length;
        totalHostingFeeChanges = hostingFeeHistory.length;
        isEmergencyMode = emergencyMode;
        currentPlatformFee = platformFeePercent;
        currentHostingFee = hostingFee;
        currentTreasury = treasuryAddress;
    }

    /// @notice Check if address is emergency operator
    function isEmergencyOperator(
        address operator
    ) external view returns (bool) {
        return emergencyOperators[operator];
    }

    /// @notice Get latest fee change details
    function getLatestFeeChange() external view returns (FeeChange memory) {
        require(feeHistory.length > 0, "No fee changes recorded");
        return feeHistory[feeHistory.length - 1];
    }

    /// @notice Get latest treasury change details
    function getLatestTreasuryChange()
        external
        view
        returns (TreasuryChange memory)
    {
        require(treasuryHistory.length > 0, "No treasury changes recorded");
        return treasuryHistory[treasuryHistory.length - 1];
    }

    /// @notice Get latest hosting fee change details
    function getLatestHostingFeeChange()
        external
        view
        returns (HostingFeeChange memory)
    {
        require(
            hostingFeeHistory.length > 0,
            "No hosting fee changes recorded"
        );
        return hostingFeeHistory[hostingFeeHistory.length - 1];
    }

    /// @notice Get all current fees and treasury in one call (gas efficient). Matches IZaaNetAdmin interface.
    function getCurrentFees()
        external
        view
        returns (
            uint256 platformFeePercentage,
            uint256 hostingFeeAmount,
            address currentTreasury
        )
    {
        return (platformFeePercent, hostingFee, treasuryAddress);
    }

    /// @notice Get host voucher registration fee for a tier (0 = hours, 1 = days, 2 = months). USDT 6 decimals.
    function getHostVoucherFeeTier(uint8 tier) external view returns (uint256) {
        if (tier == 0) return hostVoucherFeeHours;
        if (tier == 1) return hostVoucherFeeDays;
        if (tier == 2) return hostVoucherFeeMonths;
        revert("Invalid tier");
    }

    // --- Compatibility Functions (for interface alignment) ---

    /// @notice Alternative name for treasury address (interface compatibility)
    function treasury() external view returns (address) {
        return treasuryAddress;
    }

    /// @notice Alternative name for payment address (interface compatibility)
    function payment() external view returns (address) {
        return paymentAddress;
    }

    /// @notice Check if contract is paused (interface compatibility)
    function paused() public view override(PausableUpgradeable) returns (bool) {
        return super.paused();
    }

    // Storage gap for future upgrades
    uint256[50] private __gap;
}
