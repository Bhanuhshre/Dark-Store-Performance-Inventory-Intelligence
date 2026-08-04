-- ============================================================================
-- Sales & Revenue Analysis
-- Product performance, weekday/weekend trends, promotion effectiveness.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Top 10 products by revenue
-- ----------------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    cat.category_name,
    SUM(oi.quantity)                                            AS units_sold,
    ROUND(SUM(oi.line_total), 2)                                AS total_revenue
FROM order_items oi
JOIN orders o        ON o.order_id = oi.order_id
JOIN products p      ON p.product_id = oi.product_id
JOIN categories cat  ON cat.category_id = p.category_id
WHERE o.order_status = 'Delivered'
GROUP BY p.product_id, p.product_name, cat.category_name
ORDER BY total_revenue DESC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- 2. Category performance with rank and running share of total revenue
-- ----------------------------------------------------------------------------
WITH category_revenue AS (
    SELECT
        cat.category_id,
        cat.category_name,
        SUM(oi.line_total) AS revenue
    FROM order_items oi
    JOIN orders o       ON o.order_id = oi.order_id
    JOIN products p     ON p.product_id = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    WHERE o.order_status = 'Delivered'
    GROUP BY cat.category_id, cat.category_name
)
SELECT
    category_name,
    ROUND(revenue, 2)                                           AS revenue,
    RANK() OVER (ORDER BY revenue DESC)                          AS revenue_rank,
    ROUND(
        100.0 * SUM(revenue) OVER (ORDER BY revenue DESC)
        / SUM(revenue) OVER (), 2
    )                                                            AS cumulative_pct_of_revenue
FROM category_revenue
ORDER BY revenue_rank;


-- ----------------------------------------------------------------------------
-- 3. Weekday vs Weekend sales comparison
-- ----------------------------------------------------------------------------
SELECT
    CASE
        WHEN CAST(strftime('%w', o.order_datetime) AS INTEGER) IN (0, 6)
        THEN 'Weekend' ELSE 'Weekday'
    END                                                          AS day_type,
    COUNT(DISTINCT o.order_id)                                   AS total_orders,
    ROUND(SUM(o.total_amount), 2)                                AS total_revenue,
    ROUND(AVG(o.total_amount), 2)                                AS avg_order_value
FROM orders o
WHERE o.order_status = 'Delivered'
GROUP BY day_type;
-- PostgreSQL equivalent for day_type: EXTRACT(DOW FROM o.order_datetime) IN (0,6)


-- ----------------------------------------------------------------------------
-- 4. Monthly revenue trend with month-over-month growth (LAG)
-- ----------------------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        strftime('%Y-%m', o.order_datetime)                     AS order_month,
        SUM(o.total_amount)                                     AS revenue
    FROM orders o
    WHERE o.order_status = 'Delivered'
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(revenue, 2)                                           AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY order_month), 2)          AS prev_month_revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0), 2
    )                                                            AS mom_growth_pct
FROM monthly_revenue
ORDER BY order_month;
-- PostgreSQL equivalent for order_month: TO_CHAR(o.order_datetime, 'YYYY-MM')


-- ----------------------------------------------------------------------------
-- 5. Promotion effectiveness — revenue and order volume with vs without promo
-- ----------------------------------------------------------------------------
SELECT
    CASE WHEN o.promo_id IS NULL THEN 'No Promotion' ELSE pr.promo_code END AS promo_used,
    COUNT(DISTINCT o.order_id)                                   AS total_orders,
    ROUND(AVG(o.total_amount), 2)                                AS avg_order_value,
    ROUND(SUM(o.total_amount), 2)                                AS total_revenue
FROM orders o
LEFT JOIN promotions pr ON pr.promo_id = o.promo_id
WHERE o.order_status = 'Delivered'
GROUP BY promo_used
ORDER BY total_revenue DESC;


-- ----------------------------------------------------------------------------
-- 6. Best-selling product per store (window function to pick the top row)
-- ----------------------------------------------------------------------------
WITH store_product_sales AS (
    SELECT
        ds.store_id,
        ds.store_name,
        p.product_id,
        p.product_name,
        SUM(oi.quantity) AS units_sold,
        ROW_NUMBER() OVER (
            PARTITION BY ds.store_id ORDER BY SUM(oi.quantity) DESC
        ) AS rn
    FROM order_items oi
    JOIN orders o       ON o.order_id = oi.order_id
    JOIN dark_stores ds ON ds.store_id = o.store_id
    JOIN products p     ON p.product_id = oi.product_id
    WHERE o.order_status = 'Delivered'
    GROUP BY ds.store_id, ds.store_name, p.product_id, p.product_name
)
SELECT store_id, store_name, product_id, product_name, units_sold
FROM store_product_sales
WHERE rn = 1
ORDER BY store_id;


-- ----------------------------------------------------------------------------
-- 7. Payment method mix and success rate
-- ----------------------------------------------------------------------------
SELECT
    payment_method,
    COUNT(*)                                                    AS total_payments,
    SUM(CASE WHEN payment_status = 'Success' THEN 1 ELSE 0 END) AS successful_payments,
    ROUND(
        100.0 * SUM(CASE WHEN payment_status = 'Success' THEN 1 ELSE 0 END)
        / COUNT(*), 2
    )                                                            AS success_rate_pct
FROM payments
GROUP BY payment_method
ORDER BY total_payments DESC;
