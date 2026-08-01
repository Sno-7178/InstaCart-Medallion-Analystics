/* 
====================================================================================
Defining Tables within "bronze" Layer using DDL.
Schema of a table must match the data definition of the source data to retain data 
without loss, truncation, or type mismatches during loading or migration processes.
====================================================================================
*/

CREATE SCHEMA IF NOT EXISTS bronze;

-- Raw aisle lookup
DROP TABLE IF EXISTS bronze.aisles;
CREATE TABLE bronze.aisles (
    aisle_id     TEXT,
    aisle        TEXT,
    _ingested_at TIMESTAMP DEFAULT now(),   -- load timestamp
    _source_file TEXT                       -- lineage: originating CSV
);

-- Raw department lookup
DROP TABLE IF EXISTS bronze.departments;
CREATE TABLE bronze.departments (
    department_id TEXT,
    department     TEXT,
    _ingested_at    TIMESTAMP DEFAULT now(),
    _source_file    TEXT
);

-- Raw product catalog
DROP TABLE IF EXISTS bronze.products;
CREATE TABLE bronze.products (
    product_id     TEXT,
    product_name   TEXT,
    aisle_id       TEXT,
    department_id  TEXT,
    _ingested_at   TIMESTAMP DEFAULT now(),
    _source_file   TEXT
);

-- Raw orders
DROP TABLE IF EXISTS bronze.orders;
CREATE TABLE bronze.orders (
    order_id               TEXT,
    user_id                TEXT,
    eval_set               TEXT,
    order_number           TEXT,
    order_dow              TEXT,
    order_hour_of_day      TEXT,
    days_since_prior_order TEXT,
    _ingested_at           TIMESTAMP DEFAULT now(),
    _source_file           TEXT
);

-- Raw order line items ('prior' only — 'train' excluded by project scope)
DROP TABLE IF EXISTS bronze.order_products_prior;
CREATE TABLE bronze.order_products_prior (
    order_id          TEXT,
    product_id        TEXT,
    add_to_cart_order TEXT,
    reordered         TEXT,
    _ingested_at      TIMESTAMP DEFAULT now(),
    _source_file      TEXT
);