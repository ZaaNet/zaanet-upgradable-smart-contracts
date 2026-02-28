-- =============================================================================
-- Voucher Analytics
-- Voucher registrations, tiers, usage patterns
-- =============================================================================

-- Voucher Registrations by Tier
SELECT 
    tier,
    SUM(voucherCount) AS total_vouchers,
    COUNT(*) AS registration_events,
    SUM(totalFee) / 1e6 AS total_fees_usdt,
    AVG(totalFee) / 1e6 AS avg_fees_per_registration
FROM ZaaNetPayment_evt_HostVouchersRegistered
GROUP BY 1
ORDER BY 1;

-- Voucher Registrations Over Time
SELECT 
    date_trunc('day', evt_block_time) AS day,
    tier,
    SUM(voucherCount) AS vouchers_registered,
    SUM(totalFee) / 1e6 AS fees_usdt
FROM ZaaNetPayment_evt_HostVouchersRegistered
WHERE evt_block_time >= NOW() - INTERVAL '30 days'
GROUP BY 1, 2
ORDER BY 1 DESC, 2;

-- Voucher Tier Distribution (Pie Chart)
SELECT 
    CASE tier
        WHEN 0 THEN 'Hours (≤24h)'
        WHEN 1 THEN 'Days (≤30d)'
        WHEN 2 THEN 'Months (>30d)'
    END AS tier_name,
    SUM(voucherCount) AS voucher_count,
    ROUND(SUM(voucherCount) * 100.0 / NULLIF(SUM(SUM(voucherCount)) OVER (), 0), 2) AS percentage
FROM ZaaNetPayment_evt_HostVouchersRegistered
GROUP BY 1
ORDER BY 2 DESC;

-- Hosts with Most Voucher Registrations
SELECT 
    host,
    SUM(voucherCount) AS total_vouchers,
    COUNT(*) AS registration_events,
    SUM(totalFee) / 1e6 AS total_fees_usdt
FROM ZaaNetPayment_evt_HostVouchersRegistered
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

-- Voucher Registration Cost Analysis
SELECT 
    tier,
    AVG(totalFee / NULLIF(voucherCount, 0)) / 1e6 AS avg_cost_per_voucher_usdt,
    MIN(totalFee / NULLIF(voucherCount, 0)) / 1e6 AS min_cost_per_voucher_usdt,
    MAX(totalFee / NULLIF(voucherCount, 0)) / 1e6 AS max_cost_per_voucher_usdt
FROM ZaaNetPayment_evt_HostVouchersRegistered
GROUP BY 1
ORDER BY 1;

-- Voucher Usage Rate (If tracking redemptions)
-- Note: This requires correlating registered vouchers with used vouchers
-- Assuming voucherId is tracked in both events

-- Voucher Transaction Size Distribution
SELECT 
    CASE 
        WHEN grossAmount <= 1000000 THEN '$0-$1'
        WHEN grossAmount <= 5000000 THEN '$1-$5'
        WHEN grossAmount <= 10000000 THEN '$5-$10'
        WHEN grossAmount <= 20000000 THEN '$10-$20'
        WHEN grossAmount <= 50000000 THEN '$20-$50'
        ELSE '$50+'
    END AS transaction_size,
    COUNT(*) AS transaction_count,
    SUM(grossAmount) / 1e6 AS total_volume_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 2 DESC;
