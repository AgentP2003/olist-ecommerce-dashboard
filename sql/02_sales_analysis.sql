-- =====================================================================
-- 02_sales_analysis.sql
-- =====================================================================
-- Purpose: Sales & revenue views for Dashboard Page 1 (Sales & Revenue).
-- Depends on: 01_cleaning.sql views (clean_orders, clean_order_items,
--             clean_products, clean_payments)
--
-- Views created:
--   sales_monthly_trend      - revenue & order volume by month
--   sales_by_category        - revenue by product category
--   sales_by_state           - revenue by customer state
--   sales_order_value_stats  - AOV trend by month
--
-- Run with: python (see scripts/03_run_sql.py) or sqlite3 CLI
-- =====================================================================

-- ---------------------------------------------------------------------
-- sales_monthly_trend
-- Monthly revenue (item price + freight) and distinct order count.
-- Only counts orders that were actually placed (excludes 'unavailable'
-- and 'canceled' since no real transaction completed), matching
-- typical revenue-recognition logic for a sales report.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS sales_monthly_trend;
CREATE VIEW sales_monthly_trend AS
SELECT
    strftime('%Y-%m', o.order_purchase_ts) AS year_month,
    COUNT(DISTINCT o.order_id) AS num_orders,
    SUM(oi.item_total_value) AS total_revenue,
    ROUND(SUM(oi.item_total_value) * 1.0 / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM clean_orders o
JOIN clean_order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('unavailable', 'canceled')
GROUP BY year_month
ORDER BY year_month;

-- ---------------------------------------------------------------------
-- sales_by_category
-- Revenue and order count by product category (English names).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS sales_by_category;
CREATE VIEW sales_by_category AS
SELECT
    p.category_english,
    COUNT(DISTINCT oi.order_id) AS num_orders,
    COUNT(*) AS num_items_sold,
    SUM(oi.item_total_value) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_item_price
FROM clean_order_items oi
JOIN clean_products p ON oi.product_id = p.product_id
JOIN clean_orders o ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('unavailable', 'canceled')
GROUP BY p.category_english
ORDER BY total_revenue DESC;

-- ---------------------------------------------------------------------
-- sales_by_state
-- Revenue by customer state (where the buyer is located).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS sales_by_state;
CREATE VIEW sales_by_state AS
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS num_orders,
    SUM(oi.item_total_value) AS total_revenue,
    ROUND(SUM(oi.item_total_value) * 1.0 / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM clean_orders o
JOIN clean_order_items oi ON o.order_id = oi.order_id
JOIN raw_customers c ON o.customer_id = c.customer_id
WHERE o.order_status NOT IN ('unavailable', 'canceled')
GROUP BY c.customer_state
ORDER BY total_revenue DESC;

-- ---------------------------------------------------------------------
-- sales_payment_breakdown
-- Revenue and order count by payment method - useful for a
-- "how do customers pay" chart on the sales page.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS sales_payment_breakdown;
CREATE VIEW sales_payment_breakdown AS
SELECT
    payment_type,
    COUNT(DISTINCT order_id) AS num_orders,
    SUM(payment_value) AS total_paid,
    ROUND(AVG(payment_installments), 2) AS avg_installments
FROM clean_payments
GROUP BY payment_type
ORDER BY total_paid DESC;
