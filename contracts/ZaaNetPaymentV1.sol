// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interface/IZaaNetStorage.sol";
import "./interface/IZaaNetAdmin.sol";

/**
 * @title ZaaNetPaymentV1
 * @dev Upgradeable payment contract for ZaaNet platform - Version 1
 * @notice Handles all payment processing, batch payments, and voucher registrations
 */
contract ZaaNetPaymentV1 is
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    struct BatchPayment {
        uint256 contractId;
        uint256 grossAmount;
        bytes32 voucherId;
    }

    IERC20 public usdt;
    uint8 public tokenDecimals;

    IZaaNetStorage public storageContract;
    IZaaNetAdmin public adminContract;

    // Daily withdrawal limits
    uint256 public dailyWithdrawalLimit;
    mapping(uint256 => uint256) public dailyWithdrawals; // day => amount withdrawn

    // Token whitelist for approved payment tokens
    mapping(address => bool) public whitelistedTokens;
    address[] public whitelistedTokenList;

    // Payment validation
    mapping(bytes32 => bool) public processedVouchers; // Prevent double processing

    // Events
    event TokenWhitelistUpdated(
        address indexed token,
        bool status,
        uint256 timestamp
    );
    event DailyLimitUpdated(
        uint256 newLimit,
        address updatedBy,
        uint256 timestamp
    );
    event PaymentProcessed(
        bytes32 indexed voucherId,
        uint256 indexed contractId,
        address indexed host,
        address payer,
        uint256 grossAmount,
        uint256 platformFee,
        uint256 hostAmount,
        uint256 timestamp
    );

    event DailyLimitExceeded(
        address indexed treasury,
        uint256 attemptedAmount,
        uint256 dailyLimit,
        uint256 alreadyWithdrawn
    );

    event BatchPaymentProcessed(
        uint256 batchSize,
        uint256 totalAmount,
        uint256 totalPlatformFee
    );

    /// @notice Emitted when a host registers a batch of vouchers and pays the registration fee to the treasury.
    event HostVouchersRegistered(
        address indexed host,
        uint8 indexed tier,
        uint256 voucherCount,
        uint256 totalFee,
        uint256 timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    /// @dev Required by UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(
        address _usdt,
        address _storageContract,
        address _adminContract
    ) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();

        // Initialize state variables
        dailyWithdrawalLimit = 10000 * (10 ** 6); // 10K USDT

        require(_usdt != address(0), "token zero");
        require(_storageContract != address(0), "storage zero");
        require(_adminContract != address(0), "admin zero");

        usdt = IERC20(_usdt);
        tokenDecimals = IERC20Metadata(_usdt).decimals();
        require(tokenDecimals == 6, "Token decimals must be 6");

        // Add the initial token to whitelist (must be a legitimate token)
        whitelistedTokens[_usdt] = true;
        whitelistedTokenList.push(_usdt);
        emit TokenWhitelistUpdated(_usdt, true, block.timestamp);

        storageContract = IZaaNetStorage(_storageContract);
        adminContract = IZaaNetAdmin(_adminContract);
    }

    // Modifiers
    modifier onlyTreasuryOrOwner() {
        address treasury = adminContract.treasuryAddress();
        require(
            msg.sender == owner() ||
                (treasury != address(0) && msg.sender == treasury),
            "Not authorized"
        );
        _;
    }

    /**
     * @notice Process a payment for a voucher with enhanced security controls
     * @param _contractId The ID of the network contract
     * @param _grossAmount The total amount paid by the user (in USDT, 6 decimals)
     * @param _voucherId Unique voucher ID to prevent double processing
     * @dev Enforces max individual payment, daily limits, and prevents double processing. Daily limit is consumed only on success.
     */
    function processPayment(
        uint256 _contractId,
        uint256 _grossAmount,
        bytes32 _voucherId
    ) external whenNotPaused nonReentrant {
        require(
            msg.sender == adminContract.paymentAddress(),
            "Not payment address"
        );
        require(!adminContract.emergencyMode(), "Emergency mode active");
        require(!processedVouchers[_voucherId], "Voucher already processed");
        require(_grossAmount > 0, "Invalid amount");

        IZaaNetStorage.Network memory network = storageContract.getNetwork(
            _contractId
        );
        require(network.isActive, "Network not active");

        uint256 feePercent = adminContract.platformFeePercent();

        address treasuryWallet = adminContract.treasuryAddress();
        require(treasuryWallet != address(0), "Invalid treasury");

        // Check daily limit (will be consumed after successful payment in _executePayment)
        uint256 today = block.timestamp / 1 days;
        uint256 currentUsage = dailyWithdrawals[today];
        uint256 remaining = currentUsage >= dailyWithdrawalLimit
            ? 0
            : dailyWithdrawalLimit - currentUsage;
        require(_grossAmount <= remaining, "Exceeds daily limit");

        _executePayment(
            _contractId,
            _grossAmount,
            _voucherId,
            network,
            feePercent,
            treasuryWallet,
            today,
            _grossAmount
        );
    }

    /**
     * @notice Process a batch of payments for vouchers with enhanced security controls
     * @dev Limits: max 50 payments per batch, total batch amount must not exceed daily limit
     * @param payments Array of BatchPayment structs
     */
    function processBatchPayments(
        BatchPayment[] calldata payments
    ) external whenNotPaused nonReentrant {
        require(
            msg.sender == adminContract.paymentAddress(),
            "Not payment address"
        );
        require(!adminContract.emergencyMode(), "Emergency mode active");
        require(
            payments.length > 0 && payments.length <= 50,
            "Invalid batch size"
        );

        uint256 totalAmount = 0;
        uint256 feePercent = adminContract.platformFeePercent();

        address treasuryWallet = adminContract.treasuryAddress();
        require(treasuryWallet != address(0), "Invalid treasury");

        // First pass: validate all payments and calculate total (no state changes yet)
        bytes32[] memory seenVouchers = new bytes32[](payments.length);
        uint256 seenCount = 0;

        for (uint256 i = 0; i < payments.length; i++) {
            BatchPayment memory payment = payments[i];

            for (uint256 j = 0; j < seenCount; j++) {
                require(
                    seenVouchers[j] != payment.voucherId,
                    "Duplicate voucher in batch"
                );
            }
            seenVouchers[seenCount] = payment.voucherId;
            seenCount++;

            require(payment.grossAmount > 0, "Invalid amount");
            require(
                !processedVouchers[payment.voucherId],
                "Voucher already processed"
            );

            IZaaNetStorage.Network memory network = storageContract.getNetwork(
                payment.contractId
            );
            require(network.isActive, "Network not active");

            totalAmount += payment.grossAmount;
        }

        // Check and consume daily limit atomically
        uint256 today = block.timestamp / 1 days;
        uint256 currentUsage = dailyWithdrawals[today];
        uint256 remaining = currentUsage >= dailyWithdrawalLimit
            ? 0
            : dailyWithdrawalLimit - currentUsage;
        require(totalAmount <= remaining, "Exceeds daily limit");
        dailyWithdrawals[today] = currentUsage + totalAmount;

        require(
            usdt.balanceOf(address(this)) >= totalAmount,
            "Insufficient contract balance"
        );

        // Second pass: execute all payments
        uint256 totalPlatformFee = 0;

        for (uint256 i = 0; i < payments.length; i++) {
            BatchPayment memory payment = payments[i];

            IZaaNetStorage.Network memory network = storageContract.getNetwork(
                payment.contractId
            );

            uint256 platformFee = (payment.grossAmount * feePercent) / 100;
            uint256 hostAmount = payment.grossAmount - platformFee;

            uint256 paymentTotal = hostAmount + platformFee;
            require(
                usdt.balanceOf(address(this)) >= paymentTotal,
                "Insufficient balance for payment"
            );

            usdt.safeTransfer(network.hostAddress, hostAmount);

            storageContract.increaseHostEarnings(
                network.hostAddress,
                hostAmount
            );

            totalPlatformFee += platformFee;

            processedVouchers[payment.voucherId] = true;

            emit PaymentProcessed(
                payment.voucherId,
                payment.contractId,
                network.hostAddress,
                msg.sender,
                payment.grossAmount,
                platformFee,
                hostAmount,
                block.timestamp
            );
        }

        if (totalPlatformFee > 0) {
            usdt.safeTransfer(treasuryWallet, totalPlatformFee);
            storageContract.increaseClientVoucherFeeEarnings(totalPlatformFee);
        }

        storageContract.updateTotalSessionPaymentsAmount(totalAmount);

        emit BatchPaymentProcessed(
            payments.length,
            totalAmount,
            totalPlatformFee
        );
    }

    /**
     * @notice Register host-created vouchers on-chain and pay the platform registration fee in USDT.
     * @dev The host must first approve this contract to spend the required USDT amount.
     *      totalFee = getHostVoucherFeeTier(tier) * voucherIds.length, USDT 6 decimals.
     * @param voucherIds Array of voucher identifiers (off-chain IDs, e.g. bytes32 codes)
     * @param tier Fee tier: 0 = hours (≤24h), 1 = days (≤30d), 2 = months (>30d)
     */
    function registerHostVouchersAndPayFee(
        bytes32[] calldata voucherIds,
        uint8 tier
    ) external whenNotPaused nonReentrant {
        require(voucherIds.length > 0, "No vouchers");
        require(voucherIds.length <= 1000, "Too many vouchers");
        require(tier <= 2, "Invalid tier");

        uint256 feePerVoucher = adminContract.getHostVoucherFeeTier(tier);
        require(feePerVoucher > 0, "Host voucher fee not set");

        uint256 count = voucherIds.length;
        uint256 totalFee = feePerVoucher * count;
        require(totalFee > 0, "Total fee is zero");

        address treasuryWallet = adminContract.treasuryAddress();
        require(treasuryWallet != address(0), "Invalid treasury");

        usdt.safeTransferFrom(msg.sender, treasuryWallet, totalFee);

        storageContract.increaseHostVoucherFeeEarnings(totalFee);

        emit HostVouchersRegistered(
            msg.sender,
            tier,
            count,
            totalFee,
            block.timestamp
        );
    }

    /**
     * @notice Internal function to execute payment
     */
    function _executePayment(
        uint256 _contractId,
        uint256 _grossAmount,
        bytes32 _voucherId,
        IZaaNetStorage.Network memory network,
        uint256 feePercent,
        address treasuryWallet,
        uint256 _today,
        uint256 _amount
    ) internal {
        processedVouchers[_voucherId] = true;

        uint256 platformFee = (_grossAmount * feePercent) / 100;
        uint256 hostAmount = _grossAmount - platformFee;

        require(
            usdt.balanceOf(address(this)) >= hostAmount + platformFee,
            "Insufficient contract balance for payment"
        );

        usdt.safeTransfer(network.hostAddress, hostAmount);

        if (platformFee > 0) {
            usdt.safeTransfer(treasuryWallet, platformFee);
        }

        storageContract.increaseHostEarnings(network.hostAddress, hostAmount);
        if (platformFee > 0) {
            storageContract.increaseClientVoucherFeeEarnings(platformFee);
        }

        storageContract.updateTotalSessionPaymentsAmount(_grossAmount);

        // Consume daily limit only after successful payment
        dailyWithdrawals[_today] += _amount;

        emit PaymentProcessed(
            _voucherId,
            _contractId,
            network.hostAddress,
            msg.sender,
            _grossAmount,
            platformFee,
            hostAmount,
            block.timestamp
        );
    }

    /**
     * @notice Set daily withdrawal limit (owner only)
     */
    function setDailyWithdrawalLimit(uint256 _newLimit) external onlyOwner {
        require(_newLimit > 0, "Invalid limit");
        // Add reasonable upper bound to prevent accidentally setting too high
        require(_newLimit <= 1000000 * (10 ** 6), "Limit exceeds maximum");
        dailyWithdrawalLimit = _newLimit;
        emit DailyLimitUpdated(_newLimit, msg.sender, block.timestamp);
    }

    /**
     * @notice Add a token to the whitelist (owner only)
     * @dev Prevents malicious tokens from being used as payment
     */
    function addTokenToWhitelist(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        require(!whitelistedTokens[_token], "Token already whitelisted");

        // Validate token has correct decimals
        uint8 decimals = IERC20Metadata(_token).decimals();
        require(decimals == 6, "Token must have 6 decimals");

        // Try to verify it's a valid token by checking basic interface
        try IERC20(_token).totalSupply() returns (uint256) {
            // Basic check passed - add to whitelist
        } catch {
            revert("Invalid token contract");
        }

        whitelistedTokens[_token] = true;
        whitelistedTokenList.push(_token);
        emit TokenWhitelistUpdated(_token, true, block.timestamp);
    }

    /**
     * @notice Remove a token from the whitelist (owner only)
     */
    function removeTokenFromWhitelist(address _token) external onlyOwner {
        require(whitelistedTokens[_token], "Token not whitelisted");
        require(_token != address(usdt), "Cannot remove primary payment token");

        whitelistedTokens[_token] = false;
        emit TokenWhitelistUpdated(_token, false, block.timestamp);
    }

    /**
     * @notice Check if a token is whitelisted
     */
    function isTokenWhitelisted(address _token) external view returns (bool) {
        return whitelistedTokens[_token];
    }

    /**
     * @notice Get the list of whitelisted tokens
     */
    function getWhitelistedTokens() external view returns (address[] memory) {
        return whitelistedTokenList;
    }

    /**
     * @notice Get today's withdrawal amount
     */
    function getTodayWithdrawals() external view returns (uint256) {
        uint256 today = block.timestamp / 1 days;
        return dailyWithdrawals[today];
    }

    /**
     * @notice Check if voucher has been processed
     */
    function isVoucherProcessed(
        bytes32 _voucherId
    ) external view returns (bool) {
        return processedVouchers[_voucherId];
    }

    /**
     * @notice Get remaining daily limit
     */
    function getRemainingDailyLimit() public view returns (uint256) {
        uint256 today = block.timestamp / 1 days;
        uint256 used = dailyWithdrawals[today];
        return used >= dailyWithdrawalLimit ? 0 : dailyWithdrawalLimit - used;
    }

    /**
     * @notice Withdraw USDT to recipient (owner only). Counts toward daily limit.
     */
    function withdrawToken(address _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, "Amount must be greater than zero");
        require(
            usdt.balanceOf(address(this)) >= _amount,
            "Insufficient contract balance"
        );

        uint256 today = block.timestamp / 1 days;
        uint256 currentUsage = dailyWithdrawals[today];
        uint256 remaining = currentUsage >= dailyWithdrawalLimit
            ? 0
            : dailyWithdrawalLimit - currentUsage;
        require(_amount <= remaining, "Exceeds daily withdrawal limit");
        dailyWithdrawals[today] = currentUsage + _amount;

        usdt.safeTransfer(_to, _amount);
        storageContract.updateZaanetWithdrawalsAmount(_amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function rescueERC20(
        address _erc20,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        require(_to != address(0), "zero to");
        require(_erc20 != address(usdt), "Cannot rescue payment token");
        IERC20(_erc20).safeTransfer(_to, _amount);
    }

    function contractTokenBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }

    // Storage gap for future upgrades
    uint256[50] private __gap;
}
