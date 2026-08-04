-- ============================================================================
-- Customer Behavior Analysis
-- Segmentation, retention signals, and lifetime value indicators.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Customer order frequency segmentation
-- ----------------------------------------------------------------------------
WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(*)          AS order_count,
        SUM(total_amount) AS lifetime_spend
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN order_count = 1 THEN 'One-time'
        WHEN order_count BETWEEN 2 AND 4 THEN 'Occasional'
        WHEN order_count BETWEEN 5 AND 9 THEN 'Regular'
        ELSE 'Loyal'
    END                                                          AS customer_segment,
    COUNT(*)                                                     AS customers_in_segment,
    ROUND(AVG(lifetime_spend), 2)                                AS avg_lifetime_spend
FROM customer_orders
GROUP BY customer_segment
ORDER BY avg_lifetime_spend DESC;


-- ----------------------------------------------------------------------------
-- 2. RFM-style ranking — Recency, Frequency, Monetary value per customer
-- ----------------------------------------------------------------------------
WITH customer_metrics AS (
    SELECT
        c.customer_id,
        c.full_name,
        MAX(o.order_datetime)                                    AS last_order_date,
        COUNT(o.order_id)                                        AS frequency,
        SUM(o.total_amount)                                      AS monetary
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    WHERE o.order_status = 'Delivered'
    GROUP BY c.customer_id, c.full_name
)
SELECT
    customer_id,
    full_name,
    last_order_date,
    frequency,
    ROUND(monetary, 2)                                           AS monetary,
    NTILE(4) OVER (ORDER BY last_order_date DESC)                AS recency_quartile,
    NTILE(4) OVER (ORDER BY frequency DESC)                      AS frequency_quartile,
    NTILE(4) OVER (ORDER BY monetary DESC)                       AS monetary_quartile
FROM customer_metrics
ORDER BY monetary DESC;


-- ----------------------------------------------------------------------------
-- 3. Days between orders per customer (LAG-based gap analysis)
-- ----------------------------------------------------------------------------
SELECT
    customer_id,
    order_id,
    order_datetime,
    LAG(order_datetime) OVER (
        PARTITION BY customer_id ORDER BY order_datetime
    )                                                            AS prev_order_datetime,
    julianday(order_datetime) - julianday(
        LAG(order_datetime) OVER (PARTITION BY customer_id ORDER BY order_datetime)
    )                                                            AS days_since_prev_order
FROM orders
WHERE order_status = 'Delivered'
ORDER BY customer_id, order_datetime;
-- PostgreSQL equivalent for the day gap:
-- EXTRACT(EPOCH FROM (order_datetime - LAG(order_datetime) OVER (...))) / 86400


-- ----------------------------------------------------------------------------
-- 4. City-level customer engagement (active vs total, avg orders per customer)
-- ----------------------------------------------------------------------------
SELECT
    ci.city_name,
    COUNT(DISTINCT c.customer_id)                                AS total_customers,
    COUNT(DISTINCT CASE WHEN c.is_active THEN c.customer_id END) AS active_customers,
    ROUND(COUNT(o.order_id) * 1.0 / COUNT(DISTINCT c.customer_id), 2) AS avg_orders_per_customer
FROM customers c
JOIN cities ci ON ci.city_id = c.city_id
LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.order_status = 'Delivered'
GROUP BY ci.city_name
ORDER BY total_customers DESC;


-- ----------------------------------------------------------------------------
-- 5. New vs returning customer trend by month
-- A customer is "new" in the month of their very first delivered order.
-- ----------------------------------------------------------------------------
WITH first_order AS (
    SELECT
        customer_id,
        MIN(order_datetime) AS first_order_date
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
),
monthly_orders AS (
    SELECT
        o.customer_id,
        strftime('%Y-%m', o.order_datetime)                      AS order_month,
        strftime('%Y-%m', fo.first_order_date)                   AS first_order_month
    FROM orders o
    JOIN first_order fo ON fo.customer_id = o.customer_id
    WHERE o.order_status = 'Delivered'
)
SELECT
    order_month,
    SUM(CASE WHEN order_month = first_order_month THEN 1 ELSE 0 END) AS new_customers,
    SUM(CASE WHEN order_month != first_order_month THEN 1 ELSE 0 END) AS returning_orders
FROM monthly_orders
GROUP BY order_month
ORDER BY order_month;


-- ----------------------------------------------------------------------------
-- 6. High-value customers (top 5% by spend) using a window function threshold
-- ----------------------------------------------------------------------------
WITH customer_spend AS (
    SELECT
        customer_id,
        SUM(total_amount) AS lifetime_spend,
        PERCENT_RANK() OVER (ORDER BY SUM(total_amount)) AS spend_percentile
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)
SELECT
    cs.customer_id,
    c.full_name,
    ROUND(cs.lifetime_spend, 2)                                  AS lifetime_spend,
    ROUND(cs.spend_percentile, 3)                                AS spend_percentile
FROM customer_spend cs
JOIN customers c ON c.customer_id = cs.customer_id
WHERE cs.spend_percentile >= 0.95
ORDER BY cs.lifetime_spend DESC;
