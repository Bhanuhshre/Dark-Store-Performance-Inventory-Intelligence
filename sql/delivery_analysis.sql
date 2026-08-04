-- ============================================================================
-- Delivery Performance Analysis
-- SLA compliance, delivery partner performance, and bottleneck identification.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Delivery status breakdown, overall
-- ----------------------------------------------------------------------------
SELECT
    delivery_status,
    COUNT(*)                                                    AS total_deliveries,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)          AS pct_of_all_deliveries
FROM deliveries
GROUP BY delivery_status
ORDER BY total_deliveries DESC;


-- ----------------------------------------------------------------------------
-- 2. Average delay (actual - promised) by city
-- ----------------------------------------------------------------------------
SELECT
    c.city_name,
    COUNT(*)                                                    AS delivered_orders,
    ROUND(AVG(d.actual_time_mins - d.promised_time_mins), 2)   AS avg_delay_mins
FROM deliveries d
JOIN orders o     ON o.order_id = d.order_id
JOIN dark_stores ds ON ds.store_id = o.store_id
JOIN cities c        ON c.city_id  = ds.city_id
WHERE d.delivery_status IN ('Delivered', 'Delayed')
GROUP BY c.city_name
ORDER BY avg_delay_mins DESC;


-- ----------------------------------------------------------------------------
-- 3. Delivery partner scorecard — ranked by on-time percentage (min 20 trips)
-- ----------------------------------------------------------------------------
WITH partner_stats AS (
    SELECT
        dp.partner_id,
        dp.partner_name,
        dp.city_id,
        COUNT(*)                                                AS total_trips,
        SUM(CASE WHEN d.actual_time_mins <= d.promised_time_mins
                 THEN 1 ELSE 0 END)                              AS on_time_trips,
        ROUND(AVG(d.actual_time_mins), 2)                        AS avg_delivery_time
    FROM deliveries d
    JOIN delivery_partners dp ON dp.partner_id = d.partner_id
    WHERE d.delivery_status IN ('Delivered', 'Delayed')
    GROUP BY dp.partner_id, dp.partner_name, dp.city_id
)
SELECT
    partner_id,
    partner_name,
    total_trips,
    on_time_trips,
    ROUND(100.0 * on_time_trips / total_trips, 2)                AS on_time_pct,
    avg_delivery_time,
    RANK() OVER (ORDER BY 100.0 * on_time_trips / total_trips DESC) AS on_time_rank
FROM partner_stats
WHERE total_trips >= 20
ORDER BY on_time_rank;


-- ----------------------------------------------------------------------------
-- 4. Delivery time percentiles by store (P50 / P90 approximation using NTILE)
-- True percentile functions (PERCENTILE_CONT) are available in PostgreSQL;
-- the NTILE-based version below is portable and included for comparison.
-- ----------------------------------------------------------------------------
-- PostgreSQL-native version:
-- SELECT
--     ds.store_id,
--     ds.store_name,
--     PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY d.actual_time_mins) AS p50_delivery_mins,
--     PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY d.actual_time_mins) AS p90_delivery_mins
-- FROM deliveries d
-- JOIN orders o ON o.order_id = d.order_id
-- JOIN dark_stores ds ON ds.store_id = o.store_id
-- WHERE d.delivery_status IN ('Delivered','Delayed')
-- GROUP BY ds.store_id, ds.store_name
-- ORDER BY p90_delivery_mins DESC;

WITH ranked AS (
    SELECT
        ds.store_id,
        ds.store_name,
        d.actual_time_mins,
        NTILE(100) OVER (
            PARTITION BY ds.store_id ORDER BY d.actual_time_mins
        ) AS pct_bucket
    FROM deliveries d
    JOIN orders o     ON o.order_id = d.order_id
    JOIN dark_stores ds ON ds.store_id = o.store_id
    WHERE d.delivery_status IN ('Delivered', 'Delayed')
)
SELECT
    store_id,
    store_name,
    MAX(CASE WHEN pct_bucket = 50 THEN actual_time_mins END)    AS approx_p50_mins,
    MAX(CASE WHEN pct_bucket = 90 THEN actual_time_mins END)    AS approx_p90_mins
FROM ranked
GROUP BY store_id, store_name
ORDER BY approx_p90_mins DESC;


-- ----------------------------------------------------------------------------
-- 5. Correlated subquery: stores whose average delay exceeds the citywide
-- average delay (bottleneck stores relative to their peers)
-- ----------------------------------------------------------------------------
SELECT
    ds.store_id,
    ds.store_name,
    ds.city_id,
    ROUND(AVG(d.actual_time_mins - d.promised_time_mins), 2)   AS store_avg_delay
FROM deliveries d
JOIN orders o      ON o.order_id = d.order_id
JOIN dark_stores ds ON ds.store_id = o.store_id
WHERE d.delivery_status IN ('Delivered', 'Delayed')
GROUP BY ds.store_id, ds.store_name, ds.city_id
HAVING AVG(d.actual_time_mins - d.promised_time_mins) > (
    SELECT AVG(d2.actual_time_mins - d2.promised_time_mins)
    FROM deliveries d2
    JOIN orders o2      ON o2.order_id = d2.order_id
    JOIN dark_stores ds2 ON ds2.store_id = o2.store_id
    WHERE ds2.city_id = ds.city_id
      AND d2.delivery_status IN ('Delivered', 'Delayed')
)
ORDER BY store_avg_delay DESC;


-- ----------------------------------------------------------------------------
-- 6. Peak hour analysis — order volume and average delay by hour of day
-- ----------------------------------------------------------------------------
SELECT
    CAST(strftime('%H', o.order_datetime) AS INTEGER)           AS order_hour,
    COUNT(DISTINCT o.order_id)                                   AS total_orders,
    ROUND(AVG(d.actual_time_mins - d.promised_time_mins), 2)    AS avg_delay_mins
FROM orders o
LEFT JOIN deliveries d ON d.order_id = o.order_id
GROUP BY order_hour
ORDER BY order_hour;
-- PostgreSQL equivalent for order_hour: EXTRACT(HOUR FROM o.order_datetime)


-- ----------------------------------------------------------------------------
-- 7. Vehicle type performance comparison
-- ----------------------------------------------------------------------------
SELECT
    dp.vehicle_type,
    COUNT(*)                                                    AS total_trips,
    ROUND(AVG(d.actual_time_mins), 2)                           AS avg_delivery_time,
    ROUND(100.0 * SUM(CASE WHEN d.actual_time_mins <= d.promised_time_mins
                            THEN 1 ELSE 0 END) / COUNT(*), 2)   AS on_time_pct
FROM deliveries d
JOIN delivery_partners dp ON dp.partner_id = d.partner_id
WHERE d.delivery_status IN ('Delivered', 'Delayed')
GROUP BY dp.vehicle_type
ORDER BY on_time_pct DESC;
