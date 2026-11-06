/*
========================================================
PROJECT: E-Commerce Sales and Customer Behaviour Analysis
DATASET: Brazilian E-Commerce Public Dataset by Olist
DATABASE: ecommerce_analytics
TOOL: MySQL and DBeaver

PROJECT OBJECTIVES:
1. Analyse sales and revenue performance.
2. Understand customer purchasing behaviour.
3. Evaluate product category performance.
4. Analyse seller performance.
5. Examine delivery and payment performance.
6. Identify customer satisfaction trends.
7. Generate actionable business insights.

SQL CONCEPTS USED:
- Data cleaning and validation
- SELECT, WHERE, GROUP BY, ORDER BY
- Aggregate functions
- INNER JOIN and LEFT JOIN
- Subqueries and CTEs
- CASE statements
- Window functions
- DENSE_RANK, PARTITION BY and LAG

========================================================
*/


/*
DATA PREPARATION NOTE:
The customers_clean table was created by removing
duplicate customer records from the original dataset.

The review dataset contains 70,000 imported records
and is therefore a partial dataset.
*/



/* =====================================================
   SECTION 01: DATABASE EXPLORATION AND DATA QUALITY
===================================================== */



SHOW TABLES FROM ecommerce_analytics;


SELECT 'Customers' AS table_name, COUNT(*) AS total_records
FROM ecommerce_analytics.customers_clean

UNION ALL

SELECT 'Orders', COUNT(*)
FROM ecommerce_analytics.olist_orders_dataset

UNION ALL

SELECT 'Order Items', COUNT(*)
FROM ecommerce_analytics.olist_order_items_dataset

UNION ALL

SELECT 'Products', COUNT(*)
FROM ecommerce_analytics.olist_products_dataset

UNION ALL

SELECT 'Payments', COUNT(*)
FROM ecommerce_analytics.olist_order_payments_dataset

UNION ALL

SELECT 'Sellers', COUNT(*)
FROM ecommerce_analytics.olist_sellers_dataset;



SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT customer_id) AS unique_customer_ids
FROM ecommerce_analytics.customers_clean;


SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT order_id) AS unique_order_ids
FROM ecommerce_analytics.olist_orders_dataset;


SELECT
    order_status,
    COUNT(*) AS total_orders
FROM ecommerce_analytics.olist_orders_dataset
GROUP BY order_status
ORDER BY total_orders DESC;


/* =====================================================
   SECTION 02: SALES AND REVENUE ANALYSIS
===================================================== */


SELECT
    COUNT(DISTINCT o.order_id) AS total_delivered_orders,
    ROUND(SUM(oi.price), 2) AS total_product_revenue
FROM ecommerce_analytics.olist_orders_dataset o
JOIN ecommerce_analytics.olist_order_items_dataset oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM ecommerce_analytics.olist_orders_dataset o
JOIN ecommerce_analytics.customers_clean c
    ON o.customer_id = c.customer_id
JOIN ecommerce_analytics.olist_order_items_dataset oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


SELECT
    DATE_FORMAT(
        STR_TO_DATE(o.order_purchase_timestamp, '%Y-%m-%d %H:%i:%s'),
        '%Y-%m'
    ) AS order_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS monthly_revenue
FROM ecommerce_analytics.olist_orders_dataset o
JOIN ecommerce_analytics.olist_order_items_dataset oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month;


SELECT
    p.product_category_name,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM ecommerce_analytics.olist_order_items_dataset oi
JOIN ecommerce_analytics.olist_products_dataset p
    ON oi.product_id = p.product_id
JOIN ecommerce_analytics.olist_orders_dataset o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name
ORDER BY total_revenue DESC
LIMIT 10;


/* =====================================================
   SECTION 03: CUSTOMER BEHAVIOUR AND SEGMENTATION
===================================================== */


SELECT
    CASE
        WHEN customer_orders = 1 THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END AS customer_type,
    COUNT(*) AS total_customers,
    SUM(customer_orders) AS total_orders
FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS customer_orders
    FROM ecommerce_analytics.olist_orders_dataset o
    JOIN ecommerce_analytics.customers_clean c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
) AS customer_summary
GROUP BY customer_type;


SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_spending
FROM ecommerce_analytics.olist_orders_dataset o
JOIN ecommerce_analytics.customers_clean c
    ON o.customer_id = c.customer_id
JOIN ecommerce_analytics.olist_order_items_dataset oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY total_spending DESC
LIMIT 20;



WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS total_spending
    FROM ecommerce_analytics.olist_orders_dataset o
    JOIN ecommerce_analytics.customers_clean c
        ON o.customer_id = c.customer_id
    JOIN ecommerce_analytics.olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_segments AS (
    SELECT
        customer_unique_id,
        total_orders,
        total_spending,
        CASE
            WHEN total_orders = 1 THEN 'One-Time Customer'
            WHEN total_orders = 2 THEN 'Repeat Customer'
            ELSE 'Loyal Customer'
        END AS customer_segment
    FROM customer_orders
)
SELECT
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND(SUM(total_spending), 2) AS total_revenue,
    ROUND(AVG(total_spending), 2) AS average_customer_spending
FROM customer_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;


WITH customer_state_spending AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS total_orders,
        ROUND(SUM(oi.price), 2) AS total_spending
    FROM ecommerce_analytics.olist_orders_dataset o
    JOIN ecommerce_analytics.customers_clean c
        ON o.customer_id = c.customer_id
    JOIN ecommerce_analytics.olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        c.customer_unique_id,
        c.customer_state
),
ranked_customers AS (
    SELECT
        customer_state,
        customer_unique_id,
        total_orders,
        total_spending,
        DENSE_RANK() OVER (
            PARTITION BY customer_state
            ORDER BY total_spending DESC
        ) AS state_rank
    FROM customer_state_spending
)
SELECT *
FROM ranked_customers
WHERE state_rank <= 3
ORDER BY customer_state, state_rank;


/* =====================================================
   SECTION 04: PRODUCT CATEGORY ANALYSIS
===================================================== */


WITH category_revenue AS (
    SELECT
        p.product_category_name,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COUNT(*) AS total_items_sold,
        ROUND(SUM(oi.price), 2) AS total_revenue
    FROM ecommerce_analytics.olist_order_items_dataset oi
    JOIN ecommerce_analytics.olist_products_dataset p
        ON oi.product_id = p.product_id
    JOIN ecommerce_analytics.olist_orders_dataset o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY p.product_category_name
),
ranked_categories AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            ORDER BY total_revenue DESC
        ) AS revenue_rank
    FROM category_revenue
)
SELECT *
FROM ranked_categories
WHERE revenue_rank <= 10
ORDER BY revenue_rank;


SELECT
    p.product_category_name,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(
        SUM(oi.price) / COUNT(DISTINCT oi.order_id), 2
    ) AS average_revenue_per_order
FROM ecommerce_analytics.olist_order_items_dataset oi
JOIN ecommerce_analytics.olist_products_dataset p
    ON oi.product_id = p.product_id
JOIN ecommerce_analytics.olist_orders_dataset o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name
HAVING COUNT(DISTINCT oi.order_id) >= 100
ORDER BY average_revenue_per_order DESC
LIMIT 10;



WITH review_by_order AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM ecommerce_analytics.olist_order_reviews_dataset
    WHERE review_score IS NOT NULL
    GROUP BY order_id
),

category_orders AS (
    SELECT DISTINCT
        oi.order_id,
        p.product_category_name
    FROM ecommerce_analytics.olist_order_items_dataset oi
    JOIN ecommerce_analytics.olist_products_dataset p
        ON oi.product_id = p.product_id
    WHERE p.product_category_name IS NOT NULL
)

SELECT
    co.product_category_name,
    COUNT(*) AS total_reviews,
    ROUND(AVG(r.average_review_score), 2) AS average_review_score
FROM category_orders co
JOIN review_by_order r
    ON co.order_id = r.order_id
GROUP BY co.product_category_name
HAVING COUNT(*) >= 50
ORDER BY average_review_score DESC;

/* =====================================================
   SECTION 05: SELLER PERFORMANCE ANALYSIS
===================================================== */


DROP TABLE IF EXISTS ecommerce_analytics.seller_summary;


CREATE TABLE ecommerce_analytics.seller_summary AS
SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM ecommerce_analytics.olist_order_items_dataset oi
JOIN ecommerce_analytics.olist_orders_dataset o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.seller_id;



SELECT
    seller_id,
    total_orders,
    total_items_sold,
    total_revenue
FROM ecommerce_analytics.seller_summary
ORDER BY total_revenue DESC
LIMIT 10;



SELECT
    s.seller_state,
    COUNT(DISTINCT ss.seller_id) AS total_sellers,
    SUM(ss.total_orders) AS total_orders,
    SUM(ss.total_items_sold) AS total_items_sold,
    ROUND(SUM(ss.total_revenue), 2) AS total_revenue
FROM ecommerce_analytics.seller_summary ss
JOIN ecommerce_analytics.olist_sellers_dataset s
    ON ss.seller_id = s.seller_id
GROUP BY s.seller_state
ORDER BY total_revenue DESC;




WITH seller_state_performance AS (
    SELECT
        s.seller_state,
        ss.seller_id,
        ss.total_orders,
        ss.total_items_sold,
        ss.total_revenue
    FROM ecommerce_analytics.seller_summary ss
    JOIN ecommerce_analytics.olist_sellers_dataset s
        ON ss.seller_id = s.seller_id
)

SELECT
    seller_state,
    seller_id,
    total_orders,
    total_items_sold,
    total_revenue,

    DENSE_RANK() OVER (
        PARTITION BY seller_state
        ORDER BY total_revenue DESC
    ) AS state_rank

FROM seller_state_performance
ORDER BY seller_state, state_rank;




/* =====================================================
   SECTION 06: DELIVERY PERFORMANCE ANALYSIS
===================================================== */


SELECT
    COUNT(*) AS total_delivered_orders,
    ROUND(
        AVG(
            DATEDIFF(
                STR_TO_DATE(order_delivered_customer_date, '%Y-%m-%d %H:%i:%s'),
                STR_TO_DATE(order_purchase_timestamp, '%Y-%m-%d %H:%i:%s')
            )
        ), 2
    ) AS average_delivery_days
FROM ecommerce_analytics.olist_orders_dataset
WHERE order_status = 'delivered';



SELECT
    MIN(
        DATEDIFF(
            STR_TO_DATE(order_delivered_customer_date, '%Y-%m-%d %H:%i:%s'),
            STR_TO_DATE(order_purchase_timestamp, '%Y-%m-%d %H:%i:%s')
        )
    ) AS fastest_delivery_days,
    MAX(
        DATEDIFF(
            STR_TO_DATE(order_delivered_customer_date, '%Y-%m-%d %H:%i:%s'),
            STR_TO_DATE(order_purchase_timestamp, '%Y-%m-%d %H:%i:%s')
        )
    ) AS slowest_delivery_days
FROM ecommerce_analytics.olist_orders_dataset
WHERE order_status = 'delivered';



SELECT
    CASE
        WHEN STR_TO_DATE(order_delivered_customer_date, '%Y-%m-%d %H:%i:%s')
             < STR_TO_DATE(order_estimated_delivery_date, '%Y-%m-%d %H:%i:%s')
            THEN 'Early'
        WHEN STR_TO_DATE(order_delivered_customer_date, '%Y-%m-%d %H:%i:%s')
             > STR_TO_DATE(order_estimated_delivery_date, '%Y-%m-%d %H:%i:%s')
            THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status,
    COUNT(*) AS total_orders
FROM ecommerce_analytics.olist_orders_dataset
WHERE order_status = 'delivered'
GROUP BY delivery_status
ORDER BY total_orders DESC;



SELECT
    c.customer_state,
    COUNT(*) AS late_orders,
    ROUND(
        AVG(
            DATEDIFF(
                STR_TO_DATE(o.order_delivered_customer_date, '%Y-%m-%d %H:%i:%s'),
                STR_TO_DATE(o.order_estimated_delivery_date, '%Y-%m-%d %H:%i:%s')
            )
        ), 2
    ) AS average_delay_days
FROM ecommerce_analytics.olist_orders_dataset o
JOIN ecommerce_analytics.customers_clean c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
AND STR_TO_DATE(o.order_delivered_customer_date, '%Y-%m-%d %H:%i:%s')
    > STR_TO_DATE(o.order_estimated_delivery_date, '%Y-%m-%d %H:%i:%s')
GROUP BY c.customer_state
ORDER BY late_orders DESC;




/* =====================================================
   SECTION 07: PAYMENT ANALYSIS
===================================================== */


SELECT
    payment_type,
    COUNT(*) AS total_transactions,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM ecommerce_analytics.olist_order_payments_dataset
GROUP BY payment_type
ORDER BY total_payment_value DESC;



SELECT
    payment_installments,
    COUNT(*) AS total_payment_records,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM ecommerce_analytics.olist_order_payments_dataset
GROUP BY payment_installments
ORDER BY payment_installments;


WITH review_by_order AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM ecommerce_analytics.olist_order_reviews_dataset
    WHERE review_score IS NOT NULL
    GROUP BY order_id
),

payment_by_order AS (
    SELECT
        order_id,
        payment_type
    FROM ecommerce_analytics.olist_order_payments_dataset
    GROUP BY order_id, payment_type
)

SELECT
    p.payment_type,
    COUNT(DISTINCT p.order_id) AS total_orders,
    COUNT(r.average_review_score) AS total_reviews,
    ROUND(AVG(r.average_review_score), 2) AS average_customer_satisfaction
FROM payment_by_order p
JOIN review_by_order r
    ON p.order_id = r.order_id
GROUP BY p.payment_type
ORDER BY average_customer_satisfaction DESC;




/* =====================================================
   SECTION 08: CUSTOMER REVIEWS AND SATISFACTION
===================================================== */



SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2
    ) AS percentage
FROM ecommerce_analytics.olist_order_reviews_dataset
GROUP BY review_score
ORDER BY review_score;



SELECT
    CASE
        WHEN review_score >= 4 THEN 'Positive'
        WHEN review_score = 3 THEN 'Neutral'
        ELSE 'Negative'
    END AS customer_sentiment,
    COUNT(*) AS total_reviews
FROM ecommerce_analytics.olist_order_reviews_dataset
GROUP BY customer_sentiment
ORDER BY total_reviews DESC;



SELECT
    c.customer_state,
    COUNT(*) AS total_reviews,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM ecommerce_analytics.olist_order_reviews_dataset r
JOIN ecommerce_analytics.olist_orders_dataset o
    ON r.order_id = o.order_id
JOIN ecommerce_analytics.customers_clean c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
HAVING COUNT(*) >= 50
ORDER BY average_review_score DESC;


WITH review_by_order AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM ecommerce_analytics.olist_order_reviews_dataset
    WHERE review_score IS NOT NULL
    GROUP BY order_id
),

category_orders AS (
    SELECT DISTINCT
        oi.order_id,
        p.product_category_name
    FROM ecommerce_analytics.olist_order_items_dataset oi
    JOIN ecommerce_analytics.olist_products_dataset p
        ON oi.product_id = p.product_id
    WHERE p.product_category_name IS NOT NULL
)

SELECT
    co.product_category_name,
    COUNT(*) AS total_reviews,

    ROUND(AVG(r.average_review_score), 2)
        AS average_customer_satisfaction,

    SUM(CASE
        WHEN r.average_review_score >= 4 THEN 1
        ELSE 0
    END) AS positive_reviews,

    SUM(CASE
        WHEN r.average_review_score = 3 THEN 1
        ELSE 0
    END) AS neutral_reviews,

    SUM(CASE
        WHEN r.average_review_score <= 2 THEN 1
        ELSE 0
    END) AS negative_reviews

FROM category_orders co
JOIN review_by_order r
    ON co.order_id = r.order_id
GROUP BY co.product_category_name
HAVING COUNT(*) >= 50
ORDER BY average_customer_satisfaction DESC;



/* =====================================================
   SECTION 09: ADVANCED SQL ANALYSIS
===================================================== */



WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(
            STR_TO_DATE(o.order_purchase_timestamp, '%Y-%m-%d %H:%i:%s'),
            '%Y-%m'
        ) AS order_month,
        ROUND(SUM(oi.price), 2) AS monthly_revenue
    FROM ecommerce_analytics.olist_orders_dataset o
    JOIN ecommerce_analytics.olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY order_month
)
SELECT
    order_month,
    monthly_revenue,
    ROUND(
        SUM(monthly_revenue) OVER (
            ORDER BY order_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2
    ) AS cumulative_revenue,
    DENSE_RANK() OVER (
        ORDER BY monthly_revenue DESC
    ) AS revenue_rank
FROM monthly_sales
ORDER BY order_month;



WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(
            STR_TO_DATE(o.order_purchase_timestamp, '%Y-%m-%d %H:%i:%s'),
            '%Y-%m'
        ) AS order_month,
        ROUND(SUM(oi.price), 2) AS revenue
    FROM ecommerce_analytics.olist_orders_dataset o
    JOIN ecommerce_analytics.olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY order_month
),
revenue_comparison AS (
    SELECT
        order_month,
        revenue,
        LAG(revenue) OVER (
            ORDER BY order_month
        ) AS previous_month_revenue
    FROM monthly_revenue
)
SELECT
    order_month,
    revenue,
    previous_month_revenue,
    ROUND(
        (revenue - previous_month_revenue)
        / NULLIF(previous_month_revenue, 0) * 100,
        2
    ) AS growth_percentage
FROM revenue_comparison
ORDER BY order_month;





