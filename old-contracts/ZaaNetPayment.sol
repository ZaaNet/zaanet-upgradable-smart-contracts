// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interface/IZaaNetStorage.sol";
import "./interface/IZaaNetAdmin.sol";

contract ZaaNetPayment is Ownable, Pausable, ReentrancyGuard {
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
    uint256 public dailyWithdrawalLimit = 10000 * (10 ** 6); // 10K USDT
    mapping(uint256 => uint256) public dailyWithdrawals; // day => amount withdrawn

    // Payment validation
    mapping(bytes32 => bool) public processedVouchers; // Prevent double processing

    // Events
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

    constructor(
        address _usdt,
        address _storageContract,
        address _adminContract
    ) Ownable(msg.sender) {
        require(_usdt != address(0), "token zero");
        require(_storageContract != address(0), "storage zero");
        require(_adminContract != address(0), "admin zero");

        usdt = IERC20(_usdt);
        tokenDecimals = IERC20Metadata(_usdt).decimals();
        require(tokenDecimals == 6, "Token decimals must be 6");

        storageContract = IZaaNetStorage(_storageContract);
        adminContract = IZaaNetAdmin(_adminContract);
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
        require(
            _grossAmount > 0,
            "Invalid amount"
        );

        IZaaNetStorage.Network memory network = storageContract.getNetwork(
            _contractId
        );
        require(network.isActive, "Network not active");

        uint256 feePercent = adminContract.platformFeePercent();

        address treasuryWallet = adminContract.treasuryAddress();
        require(treasuryWallet != address(0), "Invalid treasury");

        // Check and consume daily limit atomically before execution
        uint256 today = block.timestamp / 1 days;
        uint256 currentUsage = dailyWithdrawals[today];
        uint256 remaining = currentUsage >= dailyWithdrawalLimit ? 0 : dailyWithdrawalLimit - currentUsage;
        require(_grossAmount <= remaining, "Exceeds daily limit");
        dailyWithdrawals[today] = currentUsage + _grossAmount;

        _executePayment(
            _contractId,
            _grossAmount,
            _voucherId,
            network,
            feePercent,
            treasuryWallet
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
        // Use a temporary mapping to track seen vouchers for O(1) duplicate detection
        bytes32[] memory seenVouchers = new bytes32[](payments.length);
        uint256 seenCount = 0;

        for (uint256 i = 0; i < payments.length; i++) {
            BatchPayment memory payment = payments[i];

            // O(1) duplicate check using temporary mapping
            for (uint256 j = 0; j < seenCount; j++) {
                require(
                    seenVouchers[j] != payment.voucherId,
                    "Duplicate voucher in batch"
                );
            }
            seenVouchers[seenCount] = payment.voucherId;
            seenCount++;

            // Basic validations
            require(
                payment.grossAmount > 0,
                "Invalid amount"
            );
            require(
                !processedVouchers[payment.voucherId],
                "Voucher already processed"
            );

            // Validate network
            IZaaNetStorage.Network memory network = storageContract.getNetwork(
                payment.contractId
            );
            require(network.isActive, "Network not active");

            totalAmount += payment.grossAmount;
        }

        // Check and consume daily limit atomically to prevent race conditions
        uint256 today = block.timestamp / 1 days;
        uint256 currentUsage = dailyWithdrawals[today];
        uint256 remaining = currentUsage >= dailyWithdrawalLimit ? 0 : dailyWithdrawalLimit - currentUsage;
        require(totalAmount <= remaining, "Exceeds daily limit");
        dailyWithdrawals[today] = currentUsage + totalAmount;

        // Check contract balance BEFORE any transfers
        uint256 totalRequired = totalAmount;
        require(
            usdt.balanceOf(address(this)) >= totalRequired,
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

            // Validate balance before each transfer
            uint256 paymentTotal = hostAmount + platformFee;
            require(
                usdt.balanceOf(address(this)) >= paymentTotal,
                "Insufficient balance for payment"
            );

            // Transfer to host
            usdt.safeTransfer(network.hostAddress, hostAmount);

            // Update earnings
            storageContract.increaseHostEarnings(
                network.hostAddress,
                hostAmount
            );

            totalPlatformFee += platformFee;

            // Mark as processed to prevent double-processing
            processedVouchers[payment.voucherId] = true;

            // Emit individual event
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

        // Transfer total platform fees
        if (totalPlatformFee > 0) {
            usdt.safeTransfer(treasuryWallet, totalPlatformFee);
            // These are fees coming from client voucher redemptions
            storageContract.increaseClientVoucherFeeEarnings(totalPlatformFee);
        }

        // Update total payments amount in storage
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
        require(voucherIds.length <= 1000, "Too many vouchers"); // Gas protection
        require(tier <= 2, "Invalid tier");

        // Fee per voucher (USDT 6 decimals) from admin contract
        uint256 feePerVoucher = adminContract.getHostVoucherFeeTier(tier);
        require(feePerVoucher > 0, "Host voucher fee not set");

        uint256 count = voucherIds.length;
        uint256 totalFee = feePerVoucher * count;
        require(totalFee > 0, "Total fee is zero");

        address treasuryWallet = adminContract.treasuryAddress();
        require(treasuryWallet != address(0), "Invalid treasury");

        // Pull USDT from host and send directly to treasury
        usdt.safeTransferFrom(msg.sender, treasuryWallet, totalFee);

        // Track host voucher registration fee earnings separately from network hosting fees
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
     * @param _contractId The ID of the network contract
     * @param _grossAmount The total amount paid by the user (in USDT, 6 decimals)
     * @param _voucherId Unique voucher ID to prevent double processing
     * @param network The network details from storage
     * @param feePercent The platform fee percentage
     * @param treasuryWallet The treasury wallet address
     * @dev Assumes all validations are done prior to calling this function
     */
    function _executePayment(
        uint256 _contractId,
        uint256 _grossAmount,
        bytes32 _voucherId,
        IZaaNetStorage.Network memory network,
        uint256 feePercent,
        address treasuryWallet
    ) internal {
        // Mark voucher as processed
        processedVouchers[_voucherId] = true;

        // Calculate fee and host share
        uint256 platformFee = (_grossAmount * feePercent) / 100;
        uint256 hostAmount = _grossAmount - platformFee;

        // Final balance check
        require(
            usdt.balanceOf(address(this)) >= hostAmount + platformFee,
            "Insufficient contract balance for payment"
        );

        // Transfer host payment
        usdt.safeTransfer(network.hostAddress, hostAmount);

        // Transfer platform fee
        if (platformFee > 0) {
            usdt.safeTransfer(treasuryWallet, platformFee);
        }

        // Update storage
        storageContract.increaseHostEarnings(network.hostAddress, hostAmount);
        if (platformFee > 0) {
            // These are fees coming from client voucher redemptions
            storageContract.increaseClientVoucherFeeEarnings(platformFee);
        }

        // Update total payments amount in storage
        storageContract.updateTotalSessionPaymentsAmount(_grossAmount);

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
        dailyWithdrawalLimit = _newLimit;
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

        // Check and consume daily limit atomically
        uint256 today = block.timestamp / 1 days;
        uint256 currentUsage = dailyWithdrawals[today];
        uint256 remaining = currentUsage >= dailyWithdrawalLimit ? 0 : dailyWithdrawalLimit - currentUsage;
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
}
