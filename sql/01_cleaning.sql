-- =====================================================================
-- 01_cleaning.sql
-- =====================================================================
-- Purpose: Build the clean base layer that all downstream analysis
--          views depend on. Handles type casting, deduplication, and
--          null handling on top of the raw_* tables (loaded as-is by
--          scripts/02_load_to_sqlite.py).
--
-- Views created:
--   clean_orders           - orders with proper date types + derived flags
--   clean_products          - products joined with English category names
--   clean_geolocation       - deduped, one avg lat/lng per zip prefix
--   clean_order_items       - order items, typed
--   clean_payments          - payments, typed
--   clean_reviews           - reviews, typed, comment flags
--
-- Run with: sqlite3 db/olist.db < sql/01_cleaning.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- clean_orders
-- Casts date columns, adds delivery delay + on-time flag.
-- NOTE: order_delivered_customer_date is NULL for non-delivered orders
--       (cancelled, still shipping, etc) - this is expected, not a data
--       quality issue, and is preserved here rather than dropped.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS clean_orders;
CREATE VIEW clean_orders AS
SELECT
    order_id,
    customer_id,
    order_status,
    datetime(order_purchase_timestamp)          AS order_purchase_ts,
    datetime(order_approved_at)                 AS order_approved_ts,
    datetime(order_delivered_carrier_date)      AS order_delivered_carrier_ts,
    datetime(order_delivered_customer_date)     AS order_delivered_customer_ts,
    datetime(order_estimated_delivery_date)     AS order_estimated_delivery_ts,
    -- delivery delay in days: positive = late, negative = early. NULL if not yet delivered.
    CASE
        WHEN order_delivered_customer_date IS NOT NULL
        THEN CAST(julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) AS INTEGER)
        ELSE NULL
    END AS delivery_delay_days,
    -- actual delivery duration (purchase -> customer) in days
    CASE
        WHEN order_delivered_customer_date IS NOT NULL
        THEN CAST(julianday(order_delivered_customer_date) - julianday(order_purchase_timestamp) AS REAL)
        ELSE NULL
    END AS delivery_duration_days,
    CASE
        WHEN order_delivered_customer_date IS NULL THEN NULL
        WHEN julianday(order_delivered_customer_date) <= julianday(order_estimated_delivery_date) THEN 1
        ELSE 0
    END AS is_on_time
FROM raw_orders;

-- ---------------------------------------------------------------------
-- clean_products
-- Joins English category names, fills missing category as 'unknown'.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS clean_products;
CREATE VIEW clean_products AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category_english,
    COALESCE(p.product_category_name, 'unknown') AS category_original,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM raw_products p
LEFT JOIN raw_category_translation t
    ON p.product_category_name = t.product_category_name;

-- ---------------------------------------------------------------------
-- clean_geolocation
-- Raw table has ~262k duplicate/near-duplicate rows per zip prefix
-- (multiple lat/lng readings). Collapse to one representative point
-- per zip prefix: average lat/lng, plus the single most frequent
-- city/state spelling for that prefix (via window function ranking,
-- which is far cheaper than per-row correlated subqueries at 1M rows).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS clean_geolocation;

DROP VIEW IF EXISTS _geo_avg;
CREATE VIEW _geo_avg AS
SELECT
    geolocation_zip_code_prefix AS zip_code_prefix,
    AVG(geolocation_lat) AS lat,
    AVG(geolocation_lng) AS lng
FROM raw_geolocation
GROUP BY geolocation_zip_code_prefix;

DROP VIEW IF EXISTS _geo_mode;
CREATE VIEW _geo_mode AS
SELECT zip_code_prefix, city, state
FROM (
    SELECT
        geolocation_zip_code_prefix AS zip_code_prefix,
        geolocation_city AS city,
        geolocation_state AS state,
        COUNT(*) AS cnt,
        ROW_NUMBER() OVER (
            PARTITION BY geolocation_zip_code_prefix
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM raw_geolocation
    GROUP BY geolocation_zip_code_prefix, geolocation_city, geolocation_state
)
WHERE rn = 1;

CREATE VIEW clean_geolocation AS
SELECT
    a.zip_code_prefix,
    a.lat,
    a.lng,
    m.city,
    m.state
FROM _geo_avg a
JOIN _geo_mode m ON a.zip_code_prefix = m.zip_code_prefix;

-- ---------------------------------------------------------------------
-- clean_order_items
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS clean_order_items;
CREATE VIEW clean_order_items AS
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    datetime(shipping_limit_date) AS shipping_limit_ts,
    price,
    freight_value,
    price + freight_value AS item_total_value
FROM raw_order_items;

-- ---------------------------------------------------------------------
-- clean_payments
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS clean_payments;
CREATE VIEW clean_payments AS
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM raw_order_payments
WHERE payment_type != 'not_defined';

-- ---------------------------------------------------------------------
-- clean_reviews
-- Adds boolean flags for whether a written comment exists (most
-- reviews are rating-only, per Stage 1 inspection).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS clean_reviews;
CREATE VIEW clean_reviews AS
SELECT
    review_id,
    order_id,
    review_score,
    CASE WHEN review_comment_title IS NOT NULL AND TRIM(review_comment_title) != '' THEN 1 ELSE 0 END AS has_title,
    CASE WHEN review_comment_message IS NOT NULL AND TRIM(review_comment_message) != '' THEN 1 ELSE 0 END AS has_message,
    datetime(review_creation_date) AS review_creation_ts,
    datetime(review_answer_timestamp) AS review_answer_ts
FROM raw_order_reviews;
