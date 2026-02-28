-- =============================================================================
-- User Activity Analytics
-- User engagement, retention, patterns
-- =============================================================================

-- Unique Users (Payers) Over Time
SELECT 
    date_trunc('month', evt_block_time) AS month,
    COUNT(DISTINCT payer) AS unique_payers,
    COUNT(*) AS total_transactions
FROM ZaaNetPayment_evt_PaymentProcessed
WHERE evt_block_time >= NOW() - INTERVAL '12 months'
GROUP BY 1
ORDER BY 1 DESC;

-- New vs Returning Users
WITH all_users AS (
    SELECT 
        payer,
        MIN(evt_block_time) AS first_transaction,
        COUNT(*) AS transaction_count
    FROM ZaaNetPayment_evt_PaymentProcessed
    GROUP BY 1
)
SELECT 
    CASE 
        WHEN first_transaction >= NOW() - INTERVAL '30 days' THEN 'New (30d)'
        WHEN first_transaction >= NOW() - INTERVAL '90 days' THEN 'New (90d)'
        ELSE 'Returning'
    END AS user_segment,
    COUNT(*) AS user_count,
    SUM(transaction_count) AS total_transactions
FROM all_users
GROUP BY 1
ORDER BY 2 DESC;

-- User Transaction Frequency
SELECT 
    transaction_bucket,
    COUNT(*) AS user_count
FROM (
    SELECT 
        payer,
        CASE 
            WHEN COUNT(*) = 1 THEN '1 transaction'
            WHEN COUNT(*) <= 3 THEN '2-3 transactions'
            WHEN COUNT(*) <= 10 THEN '4-10 transactions'
            WHEN COUNT(*) <= 50 THEN '11-50 transactions'
            ELSE '50+ transactions'
        END AS transaction_bucket
    FROM ZaaNetPayment_evt_PaymentProcessed
    GROUP BY 1
) sub
GROUP BY 1
ORDER BY 2 DESC;

-- Average Revenue Per User (ARPU)
SELECT 
    date_trunc('month', evt_block_time) AS month,
    COUNT(DISTINCT payer) AS active_users,
    SUM(grossAmount) / 1e6 AS total_volume_usdt,
    (SUM(grossAmount) / COUNT(DISTINCT payer)) / 1e6 AS arpu_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
WHERE evt_block_time >= NOW() - INTERVAL '12 months'
GROUP BY 1
ORDER BY 1 DESC;

-- User Lifetime Value (LTV)
SELECT 
    payer,
    SUM(grossAmount) / 1e6 AS lifetime_value_usdt,
    COUNT(*) AS transaction_count,
    MIN(evt_block_time) AS first_seen,
    MAX(evt_block_time) AS last_seen
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 2 DESC
LIMIT 50;

-- Time Between Transactions
WITH user_transactions AS (
    SELECT 
        payer,
        evt_block_time,
        LAG(evt_block_time) OVER (PARTITION BY payer ORDER BY evt_block_time) AS prev_transaction
    FROM ZaaNetPayment_evt_PaymentProcessed
)
SELECT 
    AVG(evt_block_time - prev_transaction) AS avg_days_between,
    MIN(evt_block_time - prev_transaction) AS min_days_between,
    MAX(evt_block_time - prev_transaction) AS max_days_between
FROM user_transactions
WHERE prev_transaction IS NOT NULL;

-- Network Engagement (Networks per User)
SELECT 
    contractId,
    COUNT(DISTINCT payer) AS unique_users,
    COUNT(*) AS total_transactions,
    AVG(grossAmount) / 1e6 AS avg_transaction_usdt
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

-- Peak Usage Hours
SELECT 
    extract(hour from evt_block_time) AS hour_utc,
    COUNT(*) AS transaction_count,
    COUNT(DISTINCT payer) AS unique_users
FROM ZaaNetPayment_evt_PaymentProcessed
GROUP BY 1
ORDER BY 1;

-- User Geographic Distribution (If IP data available)
-- Note: Requires additional data collection from off-chain sources
