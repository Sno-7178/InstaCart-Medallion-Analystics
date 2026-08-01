-- =====================================================================
-- SILVER LAYER — DATA QUALITY CHECKS
-- =====================================================================
-- Purpose: 1. Verify that every silver table is internally consistent and
--          correctly typed
--          2.Free of duplicates or logically 
--          impossible values before building the gold layer on top
--          3. Data range mismatch
--          4. Data consistency between dependent tables
-- =====================================================================


-- ---------------------------------------------------------------------
--  silver.aisles
-- ---------------------------------------------------------------------

-- Check 1: No duplicate aisle_ids (should be impossible due to PRIMARY KEY,
-- but confirms the constraint is actually doing its job)
SELECT aisle_id, COUNT(*) 
FROM silver.aisles 
GROUP BY aisle_id 
HAVING COUNT(*) > 1;

-- Check 2: No blank or null aisle names slipped through
SELECT * FROM silver.aisles 
WHERE aisle IS NULL OR TRIM(aisle) = '';

-- Check 3: Row count matches expected source count
-- expectation- 134
SELECT COUNT(*) AS total_aisles FROM silver.aisles; 


-- ---------------------------------------------------------------------
--  silver.departments
-- ---------------------------------------------------------------------

-- Check 1: No duplicate department_ids
SELECT department_id, COUNT(*) 
FROM silver.departments 
GROUP BY department_id 
HAVING COUNT(*) > 1;

-- Check 2: No blank or null department names
SELECT * FROM silver.departments 
WHERE department IS NULL OR TRIM(department) = '';

-- Check 3: Row count matches expected source count
-- expectation - 21
SELECT COUNT(*) AS total_departments FROM silver.departments;  


-- ---------------------------------------------------------------------
--  silver.products
-- ---------------------------------------------------------------------

-- Check 1: No duplicate product_ids
SELECT product_id, COUNT(*) 
FROM silver.products 
GROUP BY product_id 
HAVING COUNT(*) > 1;

-- Check 2: No blank or null product names
SELECT * FROM silver.products 
WHERE product_name IS NULL OR TRIM(product_name) = '';

-- Check 3: Every product's aisle_id actually exists in silver.aisles
-- (redundant with the FK constraint, but useful as an explicit)
SELECT p.product_id, p.aisle_id
FROM silver.products p
LEFT JOIN silver.aisles a ON p.aisle_id = a.aisle_id
WHERE a.aisle_id IS NULL;

-- Check 4: Every product's department_id actually exists in silver.departments
SELECT p.product_id, p.department_id
FROM silver.products p
LEFT JOIN silver.departments d ON p.department_id = d.department_id
WHERE d.department_id IS NULL;

-- Check 5: Row count sanity check 
-- expectation close to 49,688, minus any 
-- products excluded during load due to missing aisle/department refs)
SELECT COUNT(*) AS total_products FROM silver.products;


-- ---------------------------------------------------------------------
--  silver.orders
-- ---------------------------------------------------------------------

-- Check 1: No duplicate order_ids
SELECT order_id, COUNT(*) 
FROM silver.orders 
GROUP BY order_id 
HAVING COUNT(*) > 1;

-- Check 2: order_dow must be a valid day-of-week value (0-6)
SELECT * FROM silver.orders 
WHERE order_dow NOT BETWEEN 0 AND 6;

-- Check 3: order_hour_of_day must be a valid hour (0-23)
SELECT * FROM silver.orders 
WHERE order_hour_of_day NOT BETWEEN 0 AND 23;

-- Check 4: order_number must be positive (there's no "0th" or negative order)
SELECT * FROM silver.orders 
WHERE order_number <= 0;

-- Check 5: days_since_prior_order should never be negative 
SELECT * FROM silver.orders 
WHERE days_since_prior_order < 0;

-- Check 6: is_first_order flag must be perfectly consistent with 
-- days_since_prior_order being NULL — these two counts should match exactly
SELECT COUNT(*) AS flagged_first_orders 
FROM silver.orders WHERE is_first_order = TRUE;

SELECT COUNT(*) AS null_days_since_prior 
FROM silver.orders WHERE days_since_prior_order IS NULL;

-- Check 7: is_first_order should also align with order_number = 1
-- (catches any logical mismatch between the two definitions of "first order")
SELECT * FROM silver.orders 
WHERE is_first_order = TRUE AND order_number != 1;

-- Check 8: eval_set should only ever be 'prior' at this point, 
-- since we filtered out train/test during load — confirms the filter worked
SELECT DISTINCT eval_set FROM silver.orders;   -- expect only 'prior'

-- Check 9: Row count sanity check (expect close to 3,214,874, since 
-- 'prior' orders are a subset of the original 3,421,083 total orders)
SELECT COUNT(*) AS total_orders FROM silver.orders;


-- ---------------------------------------------------------------------
--  silver.order_products
-- ---------------------------------------------------------------------

-- Check 1: No duplicate (order_id, product_id) pairs
SELECT order_id, product_id, COUNT(*) 
FROM silver.order_products 
GROUP BY order_id, product_id 
HAVING COUNT(*) > 1;

-- Check 2: add_to_cart_order must be positive
SELECT * FROM silver.order_products 
WHERE add_to_cart_order <= 0;

-- Check 3: Every order_id here must exist in silver.orders 
-- (redundant with FK constraint, explicit confirmation)
SELECT op.order_id
FROM silver.order_products op
LEFT JOIN silver.orders o ON op.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Check 4: Every product_id here must exist in silver.products
SELECT op.product_id
FROM silver.order_products op
LEFT JOIN silver.products p ON op.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Check 5: every order in silver.orders must have at least 
-- one product
SELECT o.order_id 
FROM silver.orders o 
LEFT JOIN silver.order_products op ON o.order_id = op.order_id 
WHERE op.order_id IS NULL;

-- Check 6: Row count sanity check
SELECT COUNT(*) AS total_order_products FROM silver.order_products;


-- ---------------------------------------------------------------------
--  silver.quarantine_order_products
-- ---------------------------------------------------------------------

-- Check 1: See total quarantined row count — should be a very small 
-- fraction of the original 10,000,000 bronze rows, ideally close to 0
SELECT COUNT(*) AS total_quarantined FROM silver.quarantine_order_products;

-- Check 2: Breakdown of rejection reasons 
SELECT rejection_reason, COUNT(*) 
FROM silver.quarantine_order_products 
GROUP BY rejection_reason;

-- Check 3: Cross-check — good rows + quarantined rows should sum close 
-- to the original bronze row count of 10,000,000
SELECT 
    (SELECT COUNT(*) FROM silver.order_products) AS good_rows,
    (SELECT COUNT(*) FROM silver.quarantine_order_products) AS quarantined_rows,
    (SELECT COUNT(*) FROM silver.order_products) 
        + (SELECT COUNT(*) FROM silver.quarantine_order_products) AS total_accounted_for;


-- ---------------------------------------------------------------------
--  silver.users
-- ---------------------------------------------------------------------

-- Check 1: No duplicate user_ids
SELECT user_id, COUNT(*) 
FROM silver.users 
GROUP BY user_id 
HAVING COUNT(*) > 1;

-- Check 2: total_orders should never be zero or negative — every user 
-- in this table came from GROUP BY on orders, so they must have at 
-- least one order by construction
SELECT * FROM silver.users 
WHERE total_orders <= 0;

-- Check 3: Every user_id here should exist in silver.orders, and vice versa 
SELECT u.user_id
FROM silver.users u
LEFT JOIN silver.orders o ON u.user_id = o.user_id
WHERE o.user_id IS NULL;

SELECT DISTINCT o.user_id
FROM silver.orders o
LEFT JOIN silver.users u ON o.user_id = u.user_id
WHERE u.user_id IS NULL;

-- Check 4: Row count sanity check — should match the number of 
-- distinct user_ids in silver.orders
SELECT COUNT(*) AS total_users FROM silver.users;
SELECT COUNT(DISTINCT user_id) AS distinct_users_in_orders FROM silver.orders;