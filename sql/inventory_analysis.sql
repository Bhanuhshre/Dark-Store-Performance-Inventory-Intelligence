-- ============================================================================
-- Inventory Analysis
-- Stockout risk, wastage, reorder behaviour, and demand trends.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Products currently at risk of stockout
-- (latest known closing stock at or below reorder level)
-- ----------------------------------------------------------------------------
WITH latest_stock AS (
    SELECT
        i.store_id,
        i.product_id,
        i.closing_stock,
        i.reorder_level,
        i.stock_date,
        ROW_NUMBER() OVER (
            PARTITION BY i.store_id, i.product_id
            ORDER BY i.stock_date DESC
        ) AS rn
    FROM inventory i
)
SELECT
    ls.store_id,
    ds.store_name,
    ls.product_id,
    p.product_name,
    ls.closing_stock,
    ls.reorder_level,
    ls.stock_date
FROM latest_stock ls
JOIN dark_stores ds ON ds.store_id = ls.store_id
JOIN products p     ON p.product_id = ls.product_id
WHERE ls.rn = 1
  AND ls.closing_stock <= ls.reorder_level
ORDER BY ls.closing_stock ASC;


-- ----------------------------------------------------------------------------
-- 2. Wastage analysis — products with the highest spoilage/damage losses
-- ----------------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    p.shelf_life_days,
    SUM(i.units_wasted)                                         AS total_units_wasted,
    ROUND(SUM(i.units_wasted) * p.unit_cost, 2)                 AS wastage_cost
FROM inventory i
JOIN products p ON p.product_id = i.product_id
GROUP BY p.product_id, p.product_name, p.shelf_life_days, p.unit_cost
HAVING SUM(i.units_wasted) > 0
ORDER BY wastage_cost DESC
LIMIT 20;


-- ----------------------------------------------------------------------------
-- 2b. Wastage rank within each product's category (ranking function)
-- ----------------------------------------------------------------------------
WITH wastage_by_product AS (
    SELECT
        p.category_id,
        p.product_id,
        p.product_name,
        SUM(i.units_wasted) AS total_wasted
    FROM inventory i
    JOIN products p ON p.product_id = i.product_id
    GROUP BY p.category_id, p.product_id, p.product_name
)
SELECT
    c.category_name,
    w.product_name,
    w.total_wasted,
    RANK() OVER (
        PARTITION BY w.category_id ORDER BY w.total_wasted DESC
    ) AS wastage_rank_in_category
FROM wastage_by_product w
JOIN categories c ON c.category_id = w.category_id
ORDER BY c.category_name, wastage_rank_in_category;


-- ----------------------------------------------------------------------------
-- 3. Day-over-day stock movement using LAG / LEAD
-- Flags sudden drops in closing stock that could indicate a demand spike
-- or a data/receiving issue worth investigating.
-- ----------------------------------------------------------------------------
SELECT
    store_id,
    product_id,
    stock_date,
    closing_stock,
    LAG(closing_stock) OVER (
        PARTITION BY store_id, product_id ORDER BY stock_date
    )                                                            AS prev_closing_stock,
    LEAD(closing_stock) OVER (
        PARTITION BY store_id, product_id ORDER BY stock_date
    )                                                            AS next_closing_stock,
    closing_stock - LAG(closing_stock) OVER (
        PARTITION BY store_id, product_id ORDER BY stock_date
    )                                                            AS stock_change
FROM inventory
ORDER BY store_id, product_id, stock_date;


-- ----------------------------------------------------------------------------
-- 4. Rolling 4-period average of units sold (smoothed demand signal)
-- ----------------------------------------------------------------------------
SELECT
    store_id,
    product_id,
    stock_date,
    units_sold,
    ROUND(AVG(units_sold) OVER (
        PARTITION BY store_id, product_id
        ORDER BY stock_date
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ), 2)                                                        AS rolling_4period_avg_sold
FROM inventory
ORDER BY store_id, product_id, stock_date;


-- ----------------------------------------------------------------------------
-- 5. Running total of units received per store (year-to-date style tracking)
-- ----------------------------------------------------------------------------
SELECT
    store_id,
    stock_date,
    SUM(units_received)                                         AS units_received_that_day,
    SUM(SUM(units_received)) OVER (
        PARTITION BY store_id ORDER BY stock_date
    )                                                            AS running_total_received
FROM inventory
GROUP BY store_id, stock_date
ORDER BY store_id, stock_date;


-- ----------------------------------------------------------------------------
-- 6. Percentile ranking of products by total units sold (demand tiering)
-- ----------------------------------------------------------------------------
WITH product_sales AS (
    SELECT product_id, SUM(units_sold) AS total_sold
    FROM inventory
    GROUP BY product_id
)
SELECT
    p.product_id,
    p.product_name,
    ps.total_sold,
    ROUND(PERCENT_RANK() OVER (ORDER BY ps.total_sold), 3)      AS sales_percentile,
    NTILE(4) OVER (ORDER BY ps.total_sold)                       AS demand_quartile
FROM product_sales ps
JOIN products p ON p.product_id = ps.product_id
ORDER BY ps.total_sold DESC;


-- ----------------------------------------------------------------------------
-- 7. Recursive CTE: category tree with depth
-- Expands each top-level category down through its sub-categories.
-- ----------------------------------------------------------------------------
WITH RECURSIVE category_tree AS (
    SELECT
        category_id,
        category_name,
        parent_category_id,
        0 AS depth,
        category_name AS category_path
    FROM categories
    WHERE parent_category_id IS NULL

    UNION ALL

    SELECT
        c.category_id,
        c.category_name,
        c.parent_category_id,
        ct.depth + 1,
        ct.category_path || ' > ' || c.category_name
    FROM categories c
    JOIN category_tree ct ON c.parent_category_id = ct.category_id
)
SELECT category_id, category_name, depth, category_path
FROM category_tree
ORDER BY category_path;
