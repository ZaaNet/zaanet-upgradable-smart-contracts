-- =============================================================================
-- Payment Volume Analytics
-- Daily, weekly, monthly payment volumes
-- =============================================================================

-- Daily Payment Volume (Last 30 Days)
SELECT 
    date_trunc('day', evt_block_time) AS day,
    COUNT(*) AS transaction_count,
    SUM(grossAmount) / 1e6 AS gross_volume_usdt,
    SUM(platformFee) / 1e6 AS platform_fees_usdt,
    SUM(hostAmount) / 1e6 AS host_payouts_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
WHERE evt_block_time >= NOW() - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1 DESC;

-- Weekly Payment Volume (Last 12 Weeks)
SELECT 
    date_trunc('week', evt_block_time) AS week,
    COUNT(*) AS transaction_count,
    SUM(grossAmount) / 1e6 AS gross_volume_usdt,
    SUM(hostAmount) / 1e6 AS host_payouts_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
WHERE evt_block_time >= NOW() - INTERVAL '12 weeks'
GROUP BY 1
ORDER BY 1 DESC;

-- Monthly Payment Volume (Last 12 Months)
SELECT 
    date_trunc('month', evt_block_time) AS month,
    COUNT(*) AS transaction_count,
    SUM(grossAmount) / 1e6 AS gross_volume_usdt,
    AVG(grossAmount) / 1e6 AS avg_transaction_usdt,
    MIN(grossAmount) / 1e6 AS min_transaction_usdt,
    MAX(grossAmount) / 1e6 AS max_transaction_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
WHERE evt_block_time >= NOW() - INTERVAL '12 months'
GROUP BY 1
ORDER BY 1 DESC;

-- Hour of Day Analysis (When do payments happen?)
SELECT 
    extract(hour from evt_block_time) AS hour_utc,
    COUNT(*) AS transaction_count,
    SUM(grossAmount) / 1e6 AS volume_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 1;

-- Day of Week Analysis
SELECT 
    CASE extract(dow from evt_block_time)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_of_week,
    COUNT(*) AS transaction_count,
    SUM(grossAmount) / 1e6 AS volume_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 2 DESC;
