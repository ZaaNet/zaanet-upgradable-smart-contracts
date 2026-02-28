-- =============================================================================
-- Security & Audit Trail
-- Emergency events, admin actions, governance
-- =============================================================================

-- Emergency Mode Toggle History
SELECT 
    evt_block_time,
    evt_tx_hash,
    enabled AS emergency_active,
    triggeredBy AS operator
FROM ZaaNetAdmin_evt_EmergencyModeToggled
ORDER BY evt_block_time DESC;

-- Contract Pause/Unpause History
SELECT 
    'Pause' AS action,
    evt_block_time,
    evt_tx_hash,
    triggeredBy AS operator
FROM ZaaNetAdmin_evt_AdminPaused

UNION ALL

SELECT 
    'Unpause' AS action,
    evt_block_time,
    evt_tx_hash,
    triggeredBy AS operator
FROM ZaaNetAdmin_evt_AdminUnpaused

ORDER BY evt_block_time DESC;

-- Fee Change History
SELECT 
    'Platform Fee' AS fee_type,
    evt_block_time,
    evt_tx_hash,
    oldFee AS old_value,
    newFee AS new_value,
    changedBy AS operator
FROM ZaaNetAdmin_evt_PlatformFeeUpdated

UNION ALL

SELECT 
    'Hosting Fee' AS fee_type,
    evt_block_time,
    evt_tx_hash,
    oldFee AS old_value,
    newFee AS new_value,
    changedBy AS operator
FROM ZaaNetAdmin_evt_HostingFeeUpdated

ORDER BY evt_block_time DESC;

-- Treasury Address Changes
SELECT 
    evt_block_time,
    evt_tx_hash,
    oldTreasury,
    newTreasury,
    changedBy AS operator
FROM ZaaNetAdmin_evt_TreasuryUpdated
ORDER BY evt_block_time DESC;

-- Payment Address Changes
SELECT 
    evt_block_time,
    evt_tx_hash,
    oldAddress AS old_payment_address,
    newAddress AS new_payment_address,
    changedBy AS operator
FROM ZaaNetAdmin_evt_PaymentAddressUpdated
ORDER BY evt_block_time DESC;

-- Emergency Operator Changes
SELECT 
    evt_block_time,
    evt_tx_hash,
    operator,
    status AS is_authorized,
    updatedBy AS changed_by
FROM ZaaNetAdmin_evt_EmergencyOperatorUpdated
ORDER BY evt_block_time DESC;

-- Network Emergency Deactivations
-- Note: This requires tracking emergencyDeactivateNetwork calls
-- If implemented in ZaaNetStorage

-- Daily Limit Exceeded Events
SELECT 
    evt_block_time,
    evt_tx_hash,
    treasury,
    attemptedAmount / 1e6 AS attempted_usdt,
    dailyLimit / 1e6 AS limit_usdt,
    alreadyWithdrawn / 1e6 AS already_used_usdt
FROM ZaaNetPayment_evt_DailyLimitExceeded
ORDER BY evt_block_time DESC;

-- Unauthorized Access Attempts (If logged)
-- Note: Would require custom events for failed access attempts

-- Contract Initialization
SELECT 
    evt_block_time,
    evt_tx_hash,
    storageContract,
    timestamp AS init_timestamp
FROM ZaaNetAdmin_evt_ContractsInitialized
ORDER BY evt_block_time DESC;

-- Security Summary Dashboard
SELECT 
    'Emergency Modes' AS metric,
    COUNT(*) AS count
FROM ZaaNetAdmin_evt_EmergencyModeToggled

UNION ALL

SELECT 
    'Pause Events' AS metric,
    COUNT(*) AS count
FROM ZaaNetAdmin_evt_AdminPaused

UNION ALL

SELECT 
    'Fee Changes' AS metric,
    COUNT(*) AS count
FROM ZaaNetAdmin_evt_PlatformFeeUpdated

UNION ALL

SELECT 
    'Treasury Changes' AS metric,
    COUNT(*) AS count
FROM ZaaNetAdmin_evt_TreasuryUpdated

UNION ALL

SELECT 
    'Operator Changes' AS metric,
    COUNT(*) AS count
FROM ZaaNetAdmin_evt_EmergencyOperatorUpdated;

-- Last 30 Days Security Activity
SELECT 
    date_trunc('day', evt_block_time) AS day,
    'Emergency' AS event_type,
    COUNT(*) AS count
FROM ZaaNetAdmin_evt_EmergencyModeToggled
WHERE evt_block_time >= NOW() - INTERVAL '30 days'
GROUP BY 1

UNION ALL

SELECT 
    date_trunc('day', evt_block_time) AS day,
    'Pause' AS event_type,
    COUNT(*) AS count
FROM ZaaNetAdmin_evt_AdminPaused
WHERE evt_block_time >= NOW() - INTERVAL '30 days'
GROUP BY 1

ORDER BY 1 DESC;
