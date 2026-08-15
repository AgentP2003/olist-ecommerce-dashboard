-- =====================================================================
-- 04_customer_reviews.sql
-- =====================================================================
-- Purpose: Customer experience / review views for Dashboard Page 3.
-- Depends on: 01_cleaning.sql views (clean_orders, clean_reviews,
--             clean_payments, clean_order_items, clean_products)
--
-- Views created:
--   reviews_score_distribution     - count of orders per star rating
--   reviews_score_by_delay         - avg review score by delivery delay bucket
--   reviews_score_by_category      - avg review score by product category
--   reviews_score_by_payment       - avg review score by payment type/installments
--
-- Run with: python (see scripts/03_run_sql.py) or sqlite3 CLI
-- =====================================================================

-- ---------------------------------------------------------------------
-- reviews_score_distribution
-- Simple count of reviews per star rating (1-5).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS reviews_score_distribution;
CREATE VIEW reviews_score_distribution AS
SELECT
    review_score,
    COUNT(*) AS num_reviews,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM clean_reviews), 1) AS pct_of_total
FROM clean_reviews
GROUP BY review_score
ORDER BY review_score;

-- ---------------------------------------------------------------------
-- reviews_score_by_delay
-- Does a late delivery actually hurt review scores? Buckets by the
-- same delay categories as logistics_delay_distribution so the two
-- pages can cross-reference.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS reviews_score_by_delay;
CREATE VIEW reviews_score_by_delay AS
SELECT
    CASE
        WHEN o.delivery_delay_days <= -8 THEN 'Early (8+ days)'
        WHEN o.delivery_delay_days BETWEEN -7 AND -1 THEN 'Early (1-7 days)'
        WHEN o.delivery_delay_days = 0 THEN 'On time'
        WHEN o.delivery_delay_days BETWEEN 1 AND 7 THEN 'Late (1-7 days)'
        ELSE 'Late (8+ days)'
    END AS delay_bucket,
    CASE
        WHEN o.delivery_delay_days <= -8 THEN 1
        WHEN o.delivery_delay_days BETWEEN -7 AND -1 THEN 2
        WHEN o.delivery_delay_days = 0 THEN 3
        WHEN o.delivery_delay_days BETWEEN 1 AND 7 THEN 4
        ELSE 5
    END AS sort_order,
    COUNT(*) AS num_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM clean_reviews r
JOIN clean_orders o ON r.order_id = o.order_id
WHERE o.delivery_delay_days IS NOT NULL
GROUP BY delay_bucket, sort_order
ORDER BY sort_order;

-- ---------------------------------------------------------------------
-- reviews_score_by_category
-- Average review score by product category. Orders with multiple
-- items/categories contribute their review score to each category
-- present in the order (standard approach when reviews are at the
-- order level but items are at the line-item level).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS reviews_score_by_category;
CREATE VIEW reviews_score_by_category AS
SELECT
    p.category_english,
    COUNT(*) AS num_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM clean_reviews r
JOIN clean_order_items oi ON r.order_id = oi.order_id
JOIN clean_products p ON oi.product_id = p.product_id
GROUP BY p.category_english
HAVING COUNT(*) >= 30
ORDER BY avg_review_score ASC;

-- ---------------------------------------------------------------------
-- reviews_score_by_payment
-- Average review score by payment type and installment count bucket.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS reviews_score_by_payment;
CREATE VIEW reviews_score_by_payment AS
SELECT
    pay.payment_type,
    CASE
        WHEN pay.payment_installments = 1 THEN '1 (single payment)'
        WHEN pay.payment_installments BETWEEN 2 AND 4 THEN '2-4'
        WHEN pay.payment_installments BETWEEN 5 AND 8 THEN '5-8'
        ELSE '9+'
    END AS installments_bucket,
    COUNT(*) AS num_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM clean_reviews r
JOIN clean_payments pay ON r.order_id = pay.order_id
GROUP BY pay.payment_type, installments_bucket
HAVING COUNT(*) >= 20
ORDER BY pay.payment_type, installments_bucket;
