-- Silver schema: cleaned, typed, constrained tables
CREATE SCHEMA IF NOT EXISTS silver;

-- Drop in reverse dependency order
DROP TABLE IF EXISTS silver.quarantine_order_products;
DROP TABLE IF EXISTS silver.order_products;
DROP TABLE IF EXISTS silver.orders;
DROP TABLE IF EXISTS silver.products;
DROP TABLE IF EXISTS silver.departments;
DROP TABLE IF EXISTS silver.aisles;

-- Lookup table: aisles
CREATE TABLE silver.aisles (
    aisle_id INT PRIMARY KEY,
    aisle    TEXT NOT NULL
);

-- Lookup table: departments
CREATE TABLE silver.departments (
    department_id INT PRIMARY KEY,
    department     TEXT NOT NULL
);

-- Product catalog, linked to aisles and departments
CREATE TABLE silver.products (
    product_id     INT PRIMARY KEY,
    product_name   TEXT NOT NULL,
    aisle_id       INT REFERENCES silver.aisles(aisle_id),
    department_id  INT REFERENCES silver.departments(department_id)
);

-- One row per order (only 'prior' eval_set orders are loaded)
CREATE TABLE silver.orders (
    order_id               INT PRIMARY KEY,
    user_id                INT NOT NULL,
    eval_set               TEXT,
    order_number           INT,
    order_dow              SMALLINT,
    order_hour_of_day      SMALLINT,
    days_since_prior_order NUMERIC,      -- NULL = user's first order
    is_first_order         BOOLEAN NOT NULL
);

-- Line items per order
CREATE TABLE silver.order_products (
    order_id           INT REFERENCES silver.orders(order_id),
    product_id         INT REFERENCES silver.products(product_id),
    add_to_cart_order  INT,
    reordered          BOOLEAN,
    PRIMARY KEY (order_id, product_id)
);

-- Holds order_products rows that failed FK validation, with a reason
CREATE TABLE silver.quarantine_order_products (
    order_id           TEXT,
    product_id         TEXT,
    add_to_cart_order  TEXT,
    reordered          TEXT,
    rejection_reason   TEXT
);