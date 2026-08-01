-- =====================================================================
-- INSTACART MEDALLION ARCHITECTURE — SILVER LAYER
-- =====================================================================
-- Purpose : Transform raw bronze data into cleaned, typed, and 
--           referentially-validated tables ready for gold-layer 
--           star schema and analytics.
--
-- Source  : bronze.* (raw, TEXT-typed, unvalidated tables)
-- Target  : silver.* (typed, constrained, deduplicated tables)
-- Key principles applied in this layer:
--   1. Type enforcement   -> cast TEXT to proper INT/NUMERIC/BOOLEAN
--   2. Deduplication      -> DISTINCT ON to guarantee one row per key
--   3. Null handling      -> NULLIF to convert blank strings to real NULLs
--   4. Referential integrity -> enforce FK relationships via WHERE filters
--   5. Quarantine -> orphaned rows go to a quarantine 
--      table with a documented reason
--   6. Scope decision -> only 'prior' eval_set orders are loaded, since 
--      'train'/'test' orders have no corresponding product-level data 
--      in this project


-- ---------------------------------------------------------------------
--  Loading in lookup tables (silver.aisles, silver.departments)
-- ---------------------------------------------------------------------
-- Cast aisle_id from TEXT to INT, remove any exact duplicate rows

INSERT INTO silver.aisles
SELECT DISTINCT aisle_id::INT, aisle
FROM bronze.aisles;

-- Cast aisle_id from TEXT to INT, remove any exact duplicate rows

INSERT INTO silver.departments
SELECT DISTINCT department_id::INT, department
FROM bronze.departments;

-- ---------------------------------------------------------------------
--  Loading in silver.products
-- ---------------------------------------------------------------------
-- Casts types, trims whitespace from names, deduplicates by product_id,
-- and only keeps products whose aisle/department actually exist

INSERT INTO silver.products
SELECT DISTINCT ON (b.product_id::INT)
    b.product_id::INT,
    TRIM(b.product_name),
    b.aisle_id::INT,
    b.department_id::INT
FROM bronze.products b
WHERE b.aisle_id::INT IN 
	(SELECT aisle_id FROM silver.aisles)
  	AND b.department_id::INT IN 
	 (SELECT department_id FROM silver.departments)
ORDER BY b.product_id::INT;

-- ---------------------------------------------------------------------
--  Loading in silver.orders
-- ---------------------------------------------------------------------
-- Casts types, deduplicates by order_id, converts blank 
-- days_since_prior_order values into real NULLs, and filters to only
-- 'prior' eval_set orders — since 'train' orders have no matching
-- product-level data in this project (train file intentionally excluded).

INSERT INTO silver.orders
SELECT DISTINCT ON (b.order_id::INT)     -- keep exactly one row per order_id
    b.order_id::INT,
    b.user_id::INT,
    b.eval_set,
    b.order_number::INT,
    b.order_dow::SMALLINT,
    b.order_hour_of_day::SMALLINT,
    NULLIF(b.days_since_prior_order, '')::NUMERIC,   -- '', real NULL, meaning "no prior order"
    (b.order_number::INT = 1)                        -- TRUE, only for a user's actual first order
FROM bronze.orders b
WHERE b.eval_set = 'prior'
ORDER BY b.order_id::INT;

-- ---------------------------------------------------------------------
--  loading in silver.order_products
-- ---------------------------------------------------------------------
-- Splits bronze.order_products_prior into two destinations:
--   (a) rows whose order_id AND product_id both exist in silver 
--       -> inserted into silver.order_products
--   (b) rows that fail either check 
--       -> inserted into silver.quarantine_order_products with a reason
-- This guarantees FK constraints on silver.order_products will never
-- fail, since every row inserted has already been validated.
-- ---------------------------------------------------------------------

-- (a) GOOD ROWS
INSERT INTO silver.order_products
SELECT DISTINCT ON (b.order_id::INT, b.product_id::INT)
    b.order_id::INT,
    b.product_id::INT,
    b.add_to_cart_order::INT,
    (b.reordered::INT = 1)
FROM bronze.order_products_prior b
WHERE EXISTS 
	(SELECT 1 FROM silver.orders o 
	WHERE o.order_id = b.order_id::INT)
  	AND EXISTS (SELECT 1 FROM silver.products p 
	WHERE p.product_id = b.product_id::INT)
ORDER BY b.order_id::INT, b.product_id::INT;

-- (b) QUARANTINED ROWS
INSERT INTO silver.quarantine_order_products (order_id, product_id, add_to_cart_order, reordered, rejection_reason)
SELECT
    b.order_id,
    b.product_id,
    b.add_to_cart_order,
    b.reordered,
    CASE
        WHEN NOT EXISTS 
		(SELECT 1 FROM silver.orders o WHERE o.order_id = b.order_id::INT)
            THEN 'order_id not found in silver.orders'
        WHEN NOT EXISTS 
		(SELECT 1 FROM silver.products p WHERE p.product_id = b.product_id::INT)
            THEN 'product_id not found in silver.products'
    END AS rejection_reason
FROM bronze.order_products_prior b
WHERE NOT EXISTS 
(SELECT 1 FROM silver.orders o WHERE o.order_id = b.order_id::INT)
   OR NOT EXISTS 
   (SELECT 1 FROM silver.products p WHERE p.product_id = b.product_id::INT);

-- ---------------------------------------------------------------------
--  Loading in silver.users
-- ---------------------------------------------------------------------
-- There is no standalone "users" file in the raw Instacart data —
-- user_id only appears as a column inside orders.csv. 
-- This table is derieved, by aggregating silver.orders per user.
-- It becomes the source for dim_users in the gold layer.
-- ---------------------------------------------------------------------
CREATE TABLE silver.users (
    user_id                  INT PRIMARY KEY,
    total_orders              INT,
    avg_days_between_orders   NUMERIC
);

INSERT INTO silver.users
SELECT
    user_id,
    COUNT(*) AS total_orders,
    AVG(days_since_prior_order) AS avg_days_between_orders
FROM silver.orders
GROUP BY user_id;