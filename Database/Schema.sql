-- ============================================================================
-- Dark Store Performance & Inventory Intelligence
-- Database Schema (PostgreSQL)
-- ============================================================================
-- This schema models a quick-commerce operation: dark stores spread across
-- cities, products organized into categories, customer orders fulfilled from
-- store inventory, and last-mile deliveries handled by delivery partners.
-- ============================================================================

DROP TABLE IF EXISTS returns CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS deliveries CASCADE;
DROP TABLE IF EXISTS delivery_partners CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS promotions CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS dark_stores CASCADE;
DROP TABLE IF EXISTS cities CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- ----------------------------------------------------------------------------
-- Cities
-- ----------------------------------------------------------------------------
CREATE TABLE cities (
    city_id         SERIAL PRIMARY KEY,
    city_name       VARCHAR(100) NOT NULL,
    state           VARCHAR(100) NOT NULL,
    tier            VARCHAR(10)  NOT NULL CHECK (tier IN ('Tier1', 'Tier2', 'Tier3'))
);

-- ----------------------------------------------------------------------------
-- Dark Stores
-- ----------------------------------------------------------------------------
CREATE TABLE dark_stores (
    store_id        SERIAL PRIMARY KEY,
    store_name      VARCHAR(150) NOT NULL,
    city_id         INT NOT NULL REFERENCES cities(city_id),
    store_area_sqft INT NOT NULL CHECK (store_area_sqft > 0),
    opened_date     DATE NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- Categories (self-referencing for sub-categories)
-- ----------------------------------------------------------------------------
CREATE TABLE categories (
    category_id     SERIAL PRIMARY KEY,
    category_name   VARCHAR(100) NOT NULL,
    parent_category_id INT REFERENCES categories(category_id)
);

-- ----------------------------------------------------------------------------
-- Products
-- ----------------------------------------------------------------------------
CREATE TABLE products (
    product_id      SERIAL PRIMARY KEY,
    product_name    VARCHAR(200) NOT NULL,
    category_id     INT NOT NULL REFERENCES categories(category_id),
    brand           VARCHAR(100),
    unit_price      NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    unit_cost       NUMERIC(10,2) NOT NULL CHECK (unit_cost >= 0),
    shelf_life_days INT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- Inventory (per store, per product, snapshot-style ledger)
-- ----------------------------------------------------------------------------
CREATE TABLE inventory (
    inventory_id     SERIAL PRIMARY KEY,
    store_id         INT NOT NULL REFERENCES dark_stores(store_id),
    product_id       INT NOT NULL REFERENCES products(product_id),
    stock_date       DATE NOT NULL,
    opening_stock    INT NOT NULL CHECK (opening_stock >= 0),
    closing_stock    INT NOT NULL CHECK (closing_stock >= 0),
    reorder_level    INT NOT NULL DEFAULT 20,
    units_received   INT NOT NULL DEFAULT 0,
    units_sold        INT NOT NULL DEFAULT 0,
    units_wasted     INT NOT NULL DEFAULT 0,
    UNIQUE (store_id, product_id, stock_date)
);

-- ----------------------------------------------------------------------------
-- Customers
-- ----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id     SERIAL PRIMARY KEY,
    full_name       VARCHAR(150) NOT NULL,
    email           VARCHAR(150) UNIQUE NOT NULL,
    phone           VARCHAR(20),
    city_id         INT NOT NULL REFERENCES cities(city_id),
    signup_date     DATE NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- Promotions
-- ----------------------------------------------------------------------------
CREATE TABLE promotions (
    promo_id        SERIAL PRIMARY KEY,
    promo_code      VARCHAR(30) UNIQUE NOT NULL,
    description     VARCHAR(200),
    discount_pct    NUMERIC(5,2) NOT NULL CHECK (discount_pct BETWEEN 0 AND 100),
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    CHECK (end_date >= start_date)
);

-- ----------------------------------------------------------------------------
-- Delivery Partners
-- ----------------------------------------------------------------------------
CREATE TABLE delivery_partners (
    partner_id      SERIAL PRIMARY KEY,
    partner_name    VARCHAR(150) NOT NULL,
    city_id         INT NOT NULL REFERENCES cities(city_id),
    vehicle_type    VARCHAR(30) CHECK (vehicle_type IN ('Bike', 'Bicycle', 'Scooter')),
    joined_date     DATE NOT NULL,
    rating          NUMERIC(2,1) CHECK (rating BETWEEN 0 AND 5)
);

-- ----------------------------------------------------------------------------
-- Orders
-- ----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id        SERIAL PRIMARY KEY,
    customer_id     INT NOT NULL REFERENCES customers(customer_id),
    store_id        INT NOT NULL REFERENCES dark_stores(store_id),
    promo_id        INT REFERENCES promotions(promo_id),
    order_datetime  TIMESTAMP NOT NULL,
    order_status    VARCHAR(20) NOT NULL CHECK (order_status IN
                        ('Placed','Delivered','Cancelled','Returned')),
    total_amount    NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0)
);

-- ----------------------------------------------------------------------------
-- Order Items
-- ----------------------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id   SERIAL PRIMARY KEY,
    order_id        INT NOT NULL REFERENCES orders(order_id),
    product_id      INT NOT NULL REFERENCES products(product_id),
    quantity        INT NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    line_total      NUMERIC(10,2) NOT NULL CHECK (line_total >= 0)
);

-- ----------------------------------------------------------------------------
-- Deliveries
-- ----------------------------------------------------------------------------
CREATE TABLE deliveries (
    delivery_id         SERIAL PRIMARY KEY,
    order_id             INT NOT NULL UNIQUE REFERENCES orders(order_id),
    partner_id           INT NOT NULL REFERENCES delivery_partners(partner_id),
    promised_time_mins   INT NOT NULL,
    actual_time_mins     INT,
    dispatched_at        TIMESTAMP,
    delivered_at         TIMESTAMP,
    delivery_status       VARCHAR(20) NOT NULL CHECK (delivery_status IN
                        ('Delivered','Delayed','Failed','Cancelled'))
);

-- ----------------------------------------------------------------------------
-- Payments
-- ----------------------------------------------------------------------------
CREATE TABLE payments (
    payment_id      SERIAL PRIMARY KEY,
    order_id        INT NOT NULL UNIQUE REFERENCES orders(order_id),
    payment_method  VARCHAR(20) NOT NULL CHECK (payment_method IN
                        ('UPI','Card','Wallet','COD','NetBanking')),
    payment_status  VARCHAR(20) NOT NULL CHECK (payment_status IN
                        ('Success','Failed','Refunded','Pending')),
    paid_amount     NUMERIC(10,2) NOT NULL CHECK (paid_amount >= 0),
    paid_at         TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- Returns
-- ----------------------------------------------------------------------------
CREATE TABLE returns (
    return_id       SERIAL PRIMARY KEY,
    order_item_id   INT NOT NULL REFERENCES order_items(order_item_id),
    return_reason   VARCHAR(200),
    return_date     DATE NOT NULL,
    refund_amount   NUMERIC(10,2) NOT NULL CHECK (refund_amount >= 0)
);

-- ============================================================================
-- Indexes for query performance
-- ============================================================================
CREATE INDEX idx_orders_customer        ON orders(customer_id);
CREATE INDEX idx_orders_store           ON orders(store_id);
CREATE INDEX idx_orders_datetime        ON orders(order_datetime);
CREATE INDEX idx_orders_status          ON orders(order_status);

CREATE INDEX idx_order_items_order      ON order_items(order_id);
CREATE INDEX idx_order_items_product    ON order_items(product_id);

CREATE INDEX idx_inventory_store_prod   ON inventory(store_id, product_id);
CREATE INDEX idx_inventory_date         ON inventory(stock_date);

CREATE INDEX idx_deliveries_partner     ON deliveries(partner_id);
CREATE INDEX idx_deliveries_status      ON deliveries(delivery_status);

CREATE INDEX idx_products_category      ON products(category_id);
CREATE INDEX idx_dark_stores_city       ON dark_stores(city_id);
CREATE INDEX idx_customers_city         ON customers(city_id);
