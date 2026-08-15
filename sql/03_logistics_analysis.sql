-- =====================================================================
-- 03_logistics_analysis.sql
-- =====================================================================
-- Purpose: Delivery/logistics performance views for Dashboard Page 2.
-- Depends on: 01_cleaning.sql views (clean_orders, clean_order_items,
--             clean_geolocation)
--
-- Views created:
--   logistics_delivery_by_state     - on-time rate & avg delay by customer state
--   logistics_delay_distribution    - histogram-ready delay buckets
--   logistics_freight_ratio         - freight cost as % of item price
--   logistics_route_performance     - seller state -> customer state avg delivery time
--
-- Run with: python (see scripts/03_run_sql.py) or sqlite3 CLI
-- =====================================================================

-- ---------------------------------------------------------------------
-- logistics_delivery_by_state
-- On-time delivery rate and average delay per customer state.
-- Only includes orders that were actually delivered (delivery_delay_days
-- is NULL for anything still in transit/cancelled - excluded here since
-- "were we late" only makes sense for completed deliveries).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS logistics_delivery_by_state;
CREATE VIEW logistics_delivery_by_state AS
SELECT
    c.customer_state,
    COUNT(*) AS num_delivered_orders,
    ROUND(AVG(o.delivery_duration_days), 1) AS avg_delivery_days,
    ROUND(AVG(o.delivery_delay_days), 1) AS avg_delay_days,
    ROUND(100.0 * SUM(o.is_on_time) / COUNT(*), 1) AS pct_on_time
FROM clean_orders o
JOIN raw_customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_ts IS NOT NULL
GROUP BY c.customer_state
ORDER BY pct_on_time ASC;

-- ---------------------------------------------------------------------
-- logistics_delay_distribution
-- Buckets delivered orders by how early/late they were, for a
-- histogram-style chart.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS logistics_delay_distribution;
CREATE VIEW logistics_delay_distribution AS
SELECT
    CASE
        WHEN delivery_delay_days <= -15 THEN '15+ days early'
        WHEN delivery_delay_days BETWEEN -14 AND -8 THEN '8-14 days early'
        WHEN delivery_delay_days BETWEEN -7 AND -1 THEN '1-7 days early'
        WHEN delivery_delay_days = 0 THEN 'On time'
        WHEN delivery_delay_days BETWEEN 1 AND 7 THEN '1-7 days late'
        WHEN delivery_delay_days BETWEEN 8 AND 14 THEN '8-14 days late'
        ELSE '15+ days late'
    END AS delay_bucket,
    CASE
        WHEN delivery_delay_days <= -15 THEN 1
        WHEN delivery_delay_days BETWEEN -14 AND -8 THEN 2
        WHEN delivery_delay_days BETWEEN -7 AND -1 THEN 3
        WHEN delivery_delay_days = 0 THEN 4
        WHEN delivery_delay_days BETWEEN 1 AND 7 THEN 5
        WHEN delivery_delay_days BETWEEN 8 AND 14 THEN 6
        ELSE 7
    END AS sort_order,
    COUNT(*) AS num_orders
FROM clean_orders
WHERE delivery_delay_days IS NOT NULL
GROUP BY delay_bucket, sort_order
ORDER BY sort_order;

-- ---------------------------------------------------------------------
-- logistics_freight_ratio
-- Freight cost as a % of item price, by product category - shows
-- which categories are expensive to ship relative to their value.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS logistics_freight_ratio;
CREATE VIEW logistics_freight_ratio AS
SELECT
    p.category_english,
    COUNT(*) AS num_items,
    ROUND(AVG(oi.price), 2) AS avg_price,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight,
    ROUND(100.0 * AVG(oi.freight_value) / NULLIF(AVG(oi.price), 0), 1) AS freight_pct_of_price
FROM clean_order_items oi
JOIN clean_products p ON oi.product_id = p.product_id
GROUP BY p.category_english
HAVING COUNT(*) >= 30  -- drop tiny categories where the ratio is noisy
ORDER BY freight_pct_of_price DESC;

-- ---------------------------------------------------------------------
-- logistics_route_performance
-- Average delivery time from seller state to customer state, for
-- routes with meaningful volume. Useful for a state-to-state matrix
-- or top/bottom routes chart.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS logistics_route_performance;
CREATE VIEW logistics_route_performance AS
SELECT
    s.seller_state,
    c.customer_state,
    COUNT(*) AS num_orders,
    ROUND(AVG(o.delivery_duration_days), 1) AS avg_delivery_days,
    ROUND(100.0 * SUM(o.is_on_time) / COUNT(*), 1) AS pct_on_time
FROM clean_orders o
JOIN clean_order_items oi ON o.order_id = oi.order_id
JOIN raw_sellers s ON oi.seller_id = s.seller_id
JOIN raw_customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_ts IS NOT NULL
GROUP BY s.seller_state, c.customer_state
HAVING COUNT(*) >= 20  -- drop low-volume routes
ORDER BY avg_delivery_days DESC;
