-- =============================================================================
-- Network Growth Analytics
-- Network registrations, activity, pricing
-- =============================================================================

-- Networks Registered Per Day (Last 30 Days)
SELECT 
    date_trunc('day', evt_block_time) AS day,
    COUNT(*) AS new_networks,
    COUNT(DISTINCT hostAddress) AS new_hosts
FROM ZaaNetNetwork_evt_NetworkRegistered
WHERE evt_block_time >= NOW() - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1 DESC;

-- Networks Registered Per Month
SELECT 
    date_trunc('month', evt_block_time) AS month,
    COUNT(*) AS new_networks,
    COUNT(DISTINCT hostAddress) AS unique_hosts,
    SUM(hostingFeePaid) / 1e6 AS hosting_fees_usdt
FROM ZaaNetNetwork_evt_NetworkRegistered
WHERE evt_block_time >= NOW() - INTERVAL '12 months'
GROUP BY 1
ORDER BY 1 DESC;

-- Network Status Changes (Activations/Deactivations)
SELECT 
    date_trunc('day', evt_block_time) AS day,
    SUM(CASE WHEN newStatus = true THEN 1 ELSE 0 END) AS activations,
    SUM(CASE WHEN newStatus = false THEN 1 ELSE 0 END) AS deactivations
FROM ZaaNetNetwork_evt_NetworkStatusChanged
WHERE evt_block_time >= NOW() - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1 DESC;

-- Network Price Distribution
SELECT 
    pricePerSession / 1e6 AS price_tier_usdt,
    CASE 
        WHEN pricePerSession = 0 THEN 'Free'
        WHEN pricePerSession <= 1000000 THEN '$0-$1'
        WHEN pricePerSession <= 5000000 THEN '$1-$5'
        WHEN pricePerSession <= 10000000 THEN '$5-$10'
        WHEN pricePerSession <= 20000000 THEN '$10-$20'
        ELSE '$20+'
    END AS price_category,
    COUNT(*) AS network_count
FROM ZaaNetNetwork_evt_NetworkRegistered
GROUP BY 1, 2
ORDER BY 3 DESC;

-- Networks with Most Transactions
SELECT 
    p.contractId,
    n.hostAddress,
    COUNT(*) AS transaction_count,
    SUM(p.grossAmount) / 1e6 AS total_volume_usdt
FROM ZaaNetPayment_evt_PaymentProcessed p
LEFT JOIN ZaaNetNetwork_evt_NetworkRegistered n 
    ON p.contractId = n.networkId
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;

-- Average Network Lifespan (Active Duration)
SELECT 
    contractId,
    hostAddress,
    MIN(evt_block_time) AS registered_at,
    MAX(CASE WHEN newStatus = false THEN evt_block_time END) AS deactivated_at,
    CASE 
        WHEN MAX(CASE WHEN newStatus = false THEN evt_block_time END) IS NOT NULL 
        THEN MAX(CASE WHEN newStatus = false THEN evt_block_time END) - MIN(evt_block_time)
        ELSE NOW() - MIN(evt_block_time)
    END AS active_duration
FROM ZaaNetNetwork_evt_NetworkRegistered n
LEFT JOIN ZaaNetNetwork_evt_NetworkStatusChanged s 
    ON n.networkId = s.networkId
GROUP BY 1, 2
ORDER BY 5 DESC;

-- Network Update Frequency
SELECT 
    networkId,
    hostAddress,
    COUNT(*) AS update_count,
    MIN(evt_block_time) AS first_update,
    MAX(evt_block_time) AS latest_update
FROM ZaaNetNetwork_evt_NetworkUpdated
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;
