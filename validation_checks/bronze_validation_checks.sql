-- =====================================================================
-- BRONZE LAYER — DATA QUALITY CHECKS
-- =====================================================================
-- Bronze has no constraints yet, so these checks catch raw issues 
-- early — before they get passed into silver transformations.
-- =====================================================================


-- ---------------------------------------------------------------------
--  bronze.aisles
-- ---------------------------------------------------------------------

-- Row count check (expectation 134)
SELECT COUNT(*) AS total_aisles FROM bronze.aisles;

-- Null or blank values in key columns
SELECT * FROM bronze.aisles 
WHERE aisle_id IS NULL OR aisle IS NULL OR TRIM(aisle) = '';

-- Duplicate aisle_id values (no PK enforced yet at this layer)
SELECT aisle_id, COUNT(*) 
FROM bronze.aisles 
GROUP BY aisle_id 
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------------------
--  bronze.departments
-- ---------------------------------------------------------------------

-- Row count check (expectation 21)
SELECT COUNT(*) AS total_departments FROM bronze.departments;

-- Null or blank values in key columns
SELECT * FROM bronze.departments 
WHERE department_id IS NULL OR department IS NULL OR TRIM(department) = '';

-- Duplicate department_id values
SELECT department_id, COUNT(*) 
FROM bronze.departments 
GROUP BY department_id 
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------------------
--  bronze.products
-- ---------------------------------------------------------------------

-- Row count check (expectation 49,688)
SELECT COUNT(*) AS total_products FROM bronze.products;

-- Null or blank values in key columns
SELECT * FROM bronze.products 
WHERE product_id IS NULL OR product_name IS NULL OR TRIM(product_name) = '';

-- Duplicate product_id values
SELECT product_id, COUNT(*) 
FROM bronze.products 
GROUP BY product_id 
HAVING COUNT(*) > 1;

-- Values that can't be cast to INT (would break the silver load)
SELECT * FROM bronze.products 
WHERE product_id !~ '^\d+$' 
   OR aisle_id !~ '^\d+$' 
   OR department_id !~ '^\d+$';


-- ---------------------------------------------------------------------
--  bronze.orders
-- ---------------------------------------------------------------------

-- Row count check (expectation 3,421,083)
SELECT COUNT(*) AS total_orders FROM bronze.orders;

-- Null values in required fields
SELECT * FROM bronze.orders 
WHERE order_id IS NULL OR user_id IS NULL OR eval_set IS NULL;

-- Confirm eval_set only contains the 3 expected values
-- expect: prior, train, test
SELECT DISTINCT eval_set FROM bronze.orders;   

-- days_since_prior_order blank is expected (first orders) — 
SELECT COUNT(*) AS blank_days_since_prior 
FROM bronze.orders WHERE TRIM(days_since_prior_order) = '';

-- Values that can't be cast to INT (would break the silver load)
SELECT * FROM bronze.orders 
WHERE order_id !~ '^\d+$' 
   OR user_id !~ '^\d+$' 
   OR order_number !~ '^\d+$';


-- ---------------------------------------------------------------------
-- TABLE: bronze.order_products_prior
-- ---------------------------------------------------------------------

-- Row count check (expectation 10,000,000)
SELECT COUNT(*) AS total_order_products FROM bronze.order_products_prior;

-- Null values in required fields
SELECT * FROM bronze.order_products_prior 
WHERE order_id IS NULL OR product_id IS NULL;

-- Duplicate (order_id, product_id) pairs at the raw level
SELECT order_id, product_id, COUNT(*) 
FROM bronze.order_products_prior 
GROUP BY order_id, product_id 
HAVING COUNT(*) > 1;

-- reordered should only ever be '0' or '1' as raw text
SELECT DISTINCT reordered FROM bronze.order_products_prior;

-- Values that can't be cast to INT (would break the silver load)
SELECT * FROM bronze.order_products_prior 
WHERE order_id !~ '^\d+$' 
   OR product_id !~ '^\d+$' 
   OR add_to_cart_order !~ '^\d+$';