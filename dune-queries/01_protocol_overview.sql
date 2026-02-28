-- =============================================================================
-- Protocol Overview Dashboard Query
-- Shows key metrics: Total Volume, Networks, Hosts, Fees
-- =============================================================================

-- Total Payment Volume (All Time)
SELECT 
    SUM(grossAmount) / 1e6 AS total_volume_usdt
FROM ZaaNetPayment_evt_PaymentProcessed;

-- Total Networks Registered
SELECT 
    COUNT(DISTINCT networkId) AS total_networks
FROM ZaaNetNetwork_evt_NetworkRegistered;

-- Total Unique Hosts
SELECT 
    COUNT(DISTINCT hostAddress) AS total_hosts
FROM ZaaNetNetwork_evt_NetworkRegistered;

-- Total Host Earnings (All Time)
SELECT 
    SUM(hostAmount) / 1e6 AS total_host_earnings_usdt
FROM ZaaNetPayment_evt_PaymentProcessed;

-- Total Platform Fees Collected
SELECT 
    SUM(platformFee) / 1e6 AS total_platform_fees_usdt
FROM ZaaNetPayment_evt_PaymentProcessed;

-- Current Active Networks (last 30 days activity)
SELECT 
    COUNT(DISTINCT contractId) AS active_networks_30d
FROM ZaaNetPayment_evt_PaymentProcessed
WHERE evt_block_time >= NOW() - INTERVAL '30 days';

-- Total Vouchers Registered by Hosts
SELECT 
    SUM(voucherCount) AS total_vouchers_registered
FROM ZaaNetPayment_evt_HostVouchersRegistered;

-- Network Registration Trend (Last 30 Days)
SELECT 
    date_trunc('day', evt_block_time) AS day,
    COUNT(*) AS new_networks
FROM ZaaNetNetwork_evt_NetworkRegistered
WHERE evt_block_time >= NOW() - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1 DESC;

-- Emergency Mode History
SELECT 
    evt_block_time,
    enabled,
    triggeredBy
FROM ZaaNetAdmin_evt_EmergencyModeToggled
ORDER BY evt_block_time DESC;

-- Contract Pause History
SELECT 
    'Paused' AS action,
    evt_block_time,
    triggeredBy
FROM ZaaNetAdmin_evt_AdminPaused
UNION ALL
SELECT 
    'Unpaused' AS action,
    evt_block_time,
    triggeredBy
FROM ZaaNetAdmin_evt_AdminUnpaused
ORDER BY evt_block_time DESC;
