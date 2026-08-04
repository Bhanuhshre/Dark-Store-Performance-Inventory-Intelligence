-- ============================================================================
-- Views, Materialized Views, and Stored Procedures (PostgreSQL)
-- These wrap the analysis queries into reusable database objects — the kind
-- of layer a BI tool like Power BI would connect to directly.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- View: store_daily_performance
-- A single row per store/day combining revenue, orders, and delivery SLA.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW store_daily_performance AS
SELECT
    ds.store_id,
    ds.store_name,
    c.city_name,
    DATE(o.order_datetime)                                      AS order_date,
    COUNT(DISTINCT o.order_id)                                  AS total_orders,
    SUM(o.total_amount) FILTER (WHERE o.order_status = 'Delivered') AS total_revenue,
    SUM(CASE WHEN o.order_status = 'Cancelled' THEN 1 ELSE 0 END)  AS cancelled_orders,
    ROUND(AVG(d.actual_time_mins - d.promised_time_mins)
          FILTER (WHERE d.delivery_status IN ('Delivered','Delayed')), 2) AS avg_delay_mins
FROM orders o
JOIN dark_stores ds ON ds.store_id = o.store_id
JOIN cities c        ON c.city_id  = ds.city_id
LEFT JOIN deliveries d ON d.order_id = o.order_id
GROUP BY ds.store_id, ds.store_name, c.city_name, DATE(o.order_datetime);


-- ----------------------------------------------------------------------------
-- View: product_inventory_health
-- Latest stock position and reorder flag for every store/product pair.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW product_inventory_health AS
WITH latest_stock AS (
    SELECT
        store_id,
        product_id,
        closing_stock,
        reorder_level,
        stock_date,
        ROW_NUMBER() OVER (
            PARTITION BY store_id, product_id ORDER BY stock_date DESC
        ) AS rn
    FROM inventory
)
SELECT
    ls.store_id,
    ds.store_name,
    ls.product_id,
    p.product_name,
    ls.closing_stock,
    ls.reorder_level,
    ls.stock_date,
    (ls.closing_stock <= ls.reorder_level)                       AS needs_reorder
FROM latest_stock ls
JOIN dark_stores ds ON ds.store_id = ls.store_id
JOIN products p     ON p.product_id = ls.product_id
WHERE ls.rn = 1;


-- ----------------------------------------------------------------------------
-- Materialized View: monthly_city_revenue
-- Pre-aggregated revenue by city and month for fast dashboard loads.
-- Refresh on a schedule (e.g. nightly) with:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_city_revenue;
-- ----------------------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS monthly_city_revenue AS
SELECT
    c.city_id,
    c.city_name,
    TO_CHAR(o.order_datetime, 'YYYY-MM')                        AS order_month,
    COUNT(DISTINCT o.order_id)                                  AS total_orders,
    SUM(o.total_amount)                                         AS total_revenue,
    ROUND(AVG(o.total_amount), 2)                               AS avg_order_value
FROM orders o
JOIN dark_stores ds ON ds.store_id = o.store_id
JOIN cities c        ON c.city_id  = ds.city_id
WHERE o.order_status = 'Delivered'
GROUP BY c.city_id, c.city_name, TO_CHAR(o.order_datetime, 'YYYY-MM')
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_monthly_city_revenue
    ON monthly_city_revenue (city_id, order_month);


-- ----------------------------------------------------------------------------
-- Stored Procedure: refresh_dashboard_views
-- Refreshes all materialized views used by the Power BI dashboards in one call.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE refresh_dashboard_views()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_city_revenue;
    RAISE NOTICE 'Dashboard materialized views refreshed at %', clock_timestamp();
END;
$$;

-- Usage: CALL refresh_dashboard_views();


-- ----------------------------------------------------------------------------
-- Stored Procedure: flag_low_stock
-- Inserts (or updates) a low_stock_alerts table whenever a store/product
-- combination drops to or below its reorder level. Demonstrates a procedure
-- that performs a write, not just a read, as part of an operational workflow.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS low_stock_alerts (
    store_id      INT NOT NULL,
    product_id    INT NOT NULL,
    closing_stock INT NOT NULL,
    reorder_level INT NOT NULL,
    flagged_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (store_id, product_id, flagged_at)
);

CREATE OR REPLACE PROCEDURE flag_low_stock()
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO low_stock_alerts (store_id, product_id, closing_stock, reorder_level)
    SELECT store_id, product_id, closing_stock, reorder_level
    FROM product_inventory_health
    WHERE needs_reorder = TRUE;

    RAISE NOTICE 'Low stock alerts refreshed at %', clock_timestamp();
END;
$$;

-- Usage: CALL flag_low_stock();
