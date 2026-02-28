-- =============================================================================
-- Financial Analytics
-- Revenue, fees, payouts, treasury
-- =============================================================================

-- Platform Revenue by Source (All Time)
SELECT 
    'Voucher Redemptions' AS source,
    SUM(platformFee) / 1e6 AS total_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
UNION ALL
SELECT 
    'Host Voucher Registrations' AS source,
    SUM(totalFee) / 1e6 AS total_usdt
FROM ZaaNetPayment_evt_HostVouchersRegistered
UNION ALL
SELECT 
    'Hosting Fees' AS source,
    SUM(amount) / 1e6 AS total_usdt
FROM ZaaNetNetwork_evt_HostingFeePaid;

-- Monthly Platform Revenue Breakdown
SELECT 
    date_trunc('month', evt_block_time) AS month,
    SUM(platformFee) / 1e6 AS redemption_fees,
    0 AS voucher_registration_fees,
    0 AS hosting_fees
FROM ZaaNetPayment_evt_PaymentProcessed
WHERE evt_block_time >= NOW() - INTERVAL '12 months'
GROUP BY 1

UNION ALL

SELECT 
    date_trunc('month', evt_block_time) AS month,
    0 AS redemption_fees,
    SUM(totalFee) / 1e6 AS voucher_registration_fees,
    0 AS hosting_fees
FROM ZaaNetPayment_evt_HostVouchersRegistered
WHERE evt_block_time >= NOW() - INTERVAL '12 months'
GROUP BY 1

UNION ALL

SELECT 
    date_trunc('month', evt_block_time) AS month,
    0 AS redemption_fees,
    0 AS voucher_registration_fees,
    SUM(amount) / 1e6 AS hosting_fees
FROM ZaaNetNetwork_evt_HostingFeePaid
WHERE evt_block_time >= NOW() - INTERVAL '12 months'
GROUP BY 1
ORDER BY 1 DESC;

-- Daily Revenue
SELECT 
    date_trunc('day', evt_block_time) AS day,
    SUM(platformFee) / 1e6 AS platform_fees_usdt,
    SUM(hostAmount) / 1e6 AS host_payouts_usdt,
    (SUM(platformFee) + SUM(hostAmount)) / 1e6 AS total_flow_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
WHERE evt_block_time >= NOW() - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1 DESC;

-- Average Transaction Value Trends
SELECT 
    date_trunc('week', evt_block_time) AS week,
    AVG(grossAmount) / 1e6 AS avg_gross_usdt,
    AVG(hostAmount) / 1e6 AS avg_host_payout_usdt,
    AVG(platformFee) / 1e6 AS avg_platform_fee_usdt,
    COUNT(*) AS transaction_count
FROM ZaaNetPayment_evt_PaymentProcessed
WHERE evt_block_time >= NOW() - INTERVAL '12 weeks'
GROUP BY 1
ORDER BY 1 DESC;

-- Revenue by Network Tier (Price-based)
SELECT 
    n.pricePerSession / 1e6 AS price_tier_usdt,
    COUNT(*) AS transaction_count,
    SUM(p.platformFee) / 1e6 AS platform_revenue_usdt,
    AVG(p.platformFee) / 1e6 AS avg_fee_usdt
FROM ZaaNetPayment_evt_PaymentProcessed p
LEFT JOIN ZaaNetNetwork_evt_NetworkRegistered n 
    ON p.contractId = n.networkId
GROUP BY 1
ORDER BY 3 DESC;

-- Cumulative Revenue Over Time
SELECT 
    date_trunc('day', evt_block_time) AS day,
    SUM(SUM(platformFee)) OVER (ORDER BY date_trunc('day', evt_block_time)) / 1e6 AS cumulative_fees
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 1 DESC
LIMIT 30;

-- Fee Percentage Analysis
SELECT 
    date_trunc('month', evt_block_time) AS month,
    SUM(platformFee) * 100.0 / NULLIF(SUM(grossAmount), 0) AS effective_fee_percent,
    AVG(platformFee * 100.0 / NULLIF(grossAmount, 0)) AS avg_fee_percent
FROM ZaaNetPayment_evt_PaymentProcessed
WHERE evt_block_time >= NOW() - INTERVAL '12 months'
GROUP BY 1
ORDER BY 1 DESC;
