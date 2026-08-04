-- ============================================================================
-- KPI Queries
-- Core business metrics used across the Power BI dashboards.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Fill Rate (per store)
-- Fill Rate = units actually sold / units that were available to sell
-- ----------------------------------------------------------------------------
SELECT
    ds.store_id,
    ds.store_name,
    SUM(i.units_sold)                                          AS total_units_sold,
    SUM(i.opening_stock + i.units_received)                    AS total_units_available,
    ROUND(
        100.0 * SUM(i.units_sold)
        / NULLIF(SUM(i.opening_stock + i.units_received), 0), 2
    )                                                           AS fill_rate_pct
FROM inventory i
JOIN dark_stores ds ON ds.store_id = i.store_id
GROUP BY ds.store_id, ds.store_name
ORDER BY fill_rate_pct DESC;


-- ----------------------------------------------------------------------------
-- 2. SLA Percentage (per store) — orders delivered within the promised window
-- ----------------------------------------------------------------------------
SELECT
    ds.store_id,
    ds.store_name,
    COUNT(*)                                                    AS total_deliveries,
    SUM(CASE WHEN d.actual_time_mins <= d.promised_time_mins
             THEN 1 ELSE 0 END)                                 AS on_time_deliveries,
    ROUND(
        100.0 * SUM(CASE WHEN d.actual_time_mins <= d.promised_time_mins
                          THEN 1 ELSE 0 END) / COUNT(*), 2
    )                                                            AS sla_pct
FROM deliveries d
JOIN orders o     ON o.order_id = d.order_id
JOIN dark_stores ds ON ds.store_id = o.store_id
WHERE d.delivery_status IN ('Delivered', 'Delayed')
GROUP BY ds.store_id, ds.store_name
ORDER BY sla_pct DESC;


-- ----------------------------------------------------------------------------
-- 3. Inventory Turnover (per store) — how many times stock is sold through
-- Turnover = units sold / average stock on hand
-- ----------------------------------------------------------------------------
SELECT
    store_id,
    SUM(units_sold)                                             AS units_sold,
    ROUND(AVG((opening_stock + closing_stock) / 2.0), 2)        AS avg_stock_on_hand,
    ROUND(
        SUM(units_sold) / NULLIF(AVG((opening_stock + closing_stock) / 2.0), 0), 2
    )                                                            AS inventory_turnover
FROM inventory
GROUP BY store_id
ORDER BY inventory_turnover DESC;


-- ----------------------------------------------------------------------------
-- 4. Out-of-Stock Rate (per store) — share of stock-days ending at zero
-- ----------------------------------------------------------------------------
SELECT
    store_id,
    COUNT(*)                                                    AS stock_days_tracked,
    SUM(CASE WHEN closing_stock = 0 THEN 1 ELSE 0 END)          AS stockout_days,
    ROUND(
        100.0 * SUM(CASE WHEN closing_stock = 0 THEN 1 ELSE 0 END) / COUNT(*), 2
    )                                                            AS out_of_stock_rate_pct
FROM inventory
GROUP BY store_id
ORDER BY out_of_stock_rate_pct DESC;


-- ----------------------------------------------------------------------------
-- 5. Revenue Lost Due to Stockouts (estimated)
-- Approximates lost revenue as: stockout-days * average daily units sold
-- for that product/store * unit price. This is an estimate, not an exact figure,
-- since a true stockout day by definition has no sales to measure against.
-- ----------------------------------------------------------------------------
WITH avg_daily_sales AS (
    SELECT
        i.store_id,
        i.product_id,
        AVG(i.units_sold) AS avg_units_sold_per_day
    FROM inventory i
    WHERE i.closing_stock > 0   -- only use "healthy" days to estimate demand
    GROUP BY i.store_id, i.product_id
),
stockout_days AS (
    SELECT store_id, product_id, COUNT(*) AS stockout_day_count
    FROM inventory
    WHERE closing_stock = 0
    GROUP BY store_id, product_id
)
SELECT
    sd.store_id,
    sd.product_id,
    p.product_name,
    sd.stockout_day_count,
    ROUND(ads.avg_units_sold_per_day, 2)                        AS est_daily_demand,
    ROUND(sd.stockout_day_count * ads.avg_units_sold_per_day * p.unit_price, 2)
                                                                 AS est_revenue_lost
FROM stockout_days sd
JOIN avg_daily_sales ads
    ON ads.store_id = sd.store_id AND ads.product_id = sd.product_id
JOIN products p ON p.product_id = sd.product_id
ORDER BY est_revenue_lost DESC
LIMIT 25;


-- ----------------------------------------------------------------------------
-- 6. Average Order Value (AOV) — overall and by store
-- ----------------------------------------------------------------------------
SELECT
    ds.store_id,
    ds.store_name,
    COUNT(o.order_id)                                           AS total_orders,
    ROUND(AVG(o.total_amount), 2)                                AS avg_order_value
FROM orders o
JOIN dark_stores ds ON ds.store_id = o.store_id
WHERE o.order_status = 'Delivered'
GROUP BY ds.store_id, ds.store_name
ORDER BY avg_order_value DESC;


-- ----------------------------------------------------------------------------
-- 7. Repeat Customer Rate
-- Share of customers who have placed more than one delivered order
-- ----------------------------------------------------------------------------
WITH customer_order_counts AS (
    SELECT customer_id, COUNT(*) AS order_count
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)
SELECT
    COUNT(*)                                                    AS total_customers_with_orders,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)            AS repeat_customers,
    ROUND(
        100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 2
    )                                                            AS repeat_customer_rate_pct
FROM customer_order_counts;


-- ----------------------------------------------------------------------------
-- 8. Revenue per Store
-- ----------------------------------------------------------------------------
SELECT
    ds.store_id,
    ds.store_name,
    c.city_name,
    ROUND(SUM(o.total_amount), 2)                                AS total_revenue
FROM orders o
JOIN dark_stores ds ON ds.store_id = o.store_id
JOIN cities c        ON c.city_id  = ds.city_id
WHERE o.order_status = 'Delivered'
GROUP BY ds.store_id, ds.store_name, c.city_name
ORDER BY total_revenue DESC;


-- ----------------------------------------------------------------------------
-- 9. Revenue per City
-- ----------------------------------------------------------------------------
SELECT
    c.city_id,
    c.city_name,
    c.tier,
    ROUND(SUM(o.total_amount), 2)                                AS total_revenue,
    COUNT(DISTINCT o.order_id)                                   AS total_orders
FROM orders o
JOIN dark_stores ds ON ds.store_id = o.store_id
JOIN cities c        ON c.city_id  = ds.city_id
WHERE o.order_status = 'Delivered'
GROUP BY c.city_id, c.city_name, c.tier
ORDER BY total_revenue DESC;


-- ----------------------------------------------------------------------------
-- 10. Cancellation Rate (overall and by store)
-- ----------------------------------------------------------------------------
SELECT
    ds.store_id,
    ds.store_name,
    COUNT(*)                                                    AS total_orders,
    SUM(CASE WHEN o.order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND(
        100.0 * SUM(CASE WHEN o.order_status = 'Cancelled' THEN 1 ELSE 0 END)
        / COUNT(*), 2
    )                                                            AS cancellation_rate_pct
FROM orders o
JOIN dark_stores ds ON ds.store_id = o.store_id
GROUP BY ds.store_id, ds.store_name
ORDER BY cancellation_rate_pct DESC;


-- ----------------------------------------------------------------------------
-- 11. Return Rate (by item-level returns against delivered order items)
-- ----------------------------------------------------------------------------
WITH delivered_items AS (
    SELECT oi.order_item_id, oi.product_id
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status IN ('Delivered', 'Returned')
)
SELECT
    COUNT(DISTINCT di.order_item_id)                            AS delivered_items_count,
    COUNT(DISTINCT r.return_id)                                 AS returned_items_count,
    ROUND(
        100.0 * COUNT(DISTINCT r.return_id)
        / NULLIF(COUNT(DISTINCT di.order_item_id), 0), 2
    )                                                            AS return_rate_pct
FROM delivered_items di
LEFT JOIN returns r ON r.order_item_id = di.order_item_id;
