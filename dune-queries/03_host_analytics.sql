-- =============================================================================
-- Host Performance Analytics
-- Top hosts, earnings, network counts
-- =============================================================================

-- Top 20 Hosts by Total Earnings
SELECT 
    host,
    COUNT(*) AS total_transactions,
    SUM(grossAmount) / 1e6 AS total_volume_usdt,
    SUM(hostAmount) / 1e6 AS total_earnings_usdt,
    AVG(grossAmount) / 1e6 AS avg_transaction_usdt,
    MIN(evt_block_time) AS first_transaction,
    MAX(evt_block_time) AS last_transaction
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 5 DESC
LIMIT 20;

-- Top 20 Hosts by Transaction Count
SELECT 
    host,
    COUNT(*) AS transaction_count,
    SUM(hostAmount) / 1e6 AS total_earnings_usdt,
    SUM(grossAmount) / 1e6 AS total_volume_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

-- Host Network Count (How many networks does each host have?)
SELECT 
    hostAddress,
    COUNT(*) AS network_count,
    MIN(evt_block_time) AS first_network,
    MAX(evt_block_time) AS most_recent
FROM ZaaNetNetwork_evt_NetworkRegistered
GROUP BY 1
ORDER BY 2 DESC;

-- Hosts with Most Active Networks
SELECT 
    hostAddress,
    COUNT(*) AS active_network_count
FROM ZaaNetNetwork_evt_NetworkStatusChanged
WHERE newStatus = true
GROUP BY 1
ORDER BY 2 DESC;

-- Host Earnings Over Time (Monthly)
SELECT 
    date_trunc('month', p.evt_block_time) AS month,
    p.host,
    SUM(p.hostAmount) / 1e6 AS monthly_earnings_usdt,
    COUNT(*) AS transaction_count
FROM ZaaNetPayment_evt_PaymentProcessed p
WHERE p.evt_block_time >= NOW() - INTERVAL '12 months'
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;

-- New Hosts Per Month
SELECT 
    date_trunc('month', evt_block_time) AS month,
    COUNT(DISTINCT host) AS new_hosts
FROM ZaaNetNetwork_evt_HostAdded
WHERE evt_block_time >= NOW() - INTERVAL '12 months'
GROUP BY 1
ORDER BY 1 DESC;

-- Host Voucher Registrations
SELECT 
    host,
    tier,
    SUM(voucherCount) AS total_vouchers,
    SUM(totalFee) / 1e6 AS total_fees_paid_usdt
FROM ZaaNetPayment_evt_HostVouchersRegistered
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- Host Price Distribution
SELECT 
    hostAddress,
    pricePerSession / 1e6 AS price_usdt,
    COUNT(*) AS network_count
FROM ZaaNetNetwork_evt_NetworkRegistered
GROUP BY 1, 2
ORDER BY 3 DESC;
