-- Olist E-Commerce Business Analytics Project
-- SQL analysis completed in Google BigQuery


-- 1. Monthly Revenue Trend
SELECT
  FORMAT_DATE('%Y-%m', DATE(o.order_purchase_timestamp)) AS month,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(SUM(oi.price), 2) AS revenue
FROM `mis-analytics-project.Olist.Orders` o
JOIN `mis-analytics-project.Olist.Order_Items` oi
  ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY month
ORDER BY month;


-- 2. Sales Performance by State
SELECT
  c.customer_state,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(SUM(oi.price), 2) AS revenue,
  ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM `mis-analytics-project.Olist.Orders` o
JOIN `mis-analytics-project.Olist.customers` c
  ON o.customer_id = c.customer_id
JOIN `mis-analytics-project.Olist.Order_Items` oi
  ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;


-- 3. Top Product Categories by Revenue
SELECT
  ct.product_category_name_english AS category,
  COUNT(DISTINCT oi.order_id) AS orders,
  ROUND(SUM(oi.price), 2) AS revenue,
  ROUND(AVG(oi.price), 2) AS avg_item_price
FROM `mis-analytics-project.Olist.Order_Items` oi
JOIN `mis-analytics-project.Olist.Orders` o
  ON oi.order_id = o.order_id
JOIN `mis-analytics-project.Olist.Products` p
  ON oi.product_id = p.product_id
LEFT JOIN `mis-analytics-project.Olist.Category_Translation` ct
  ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY revenue DESC
LIMIT 15;


-- 4. Delivery Performance vs Customer Reviews
SELECT
  CASE
    WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
      THEN 'Late'
    ELSE 'On Time'
  END AS delivery_status,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(AVG(r.review_score), 2) AS avg_review_score,
  ROUND(
    SAFE_DIVIDE(
      COUNTIF(r.review_score <= 2),
      COUNT(r.review_score)
    ) * 100,
    2
  ) AS low_review_rate
FROM `mis-analytics-project.Olist.Orders` o
JOIN `mis-analytics-project.Olist.Reviews` r
  ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status;


-- 5. Repeat Customer Rate
WITH customer_orders AS (
  SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count
  FROM `mis-analytics-project.Olist.Orders` o
  JOIN `mis-analytics-project.Olist.customers` c
    ON o.customer_id = c.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
)
SELECT
  COUNT(*) AS total_customers,
  COUNTIF(order_count > 1) AS repeat_customers,
  ROUND(
    SAFE_DIVIDE(COUNTIF(order_count > 1), COUNT(*)) * 100,
    2
  ) AS repeat_customer_rate
FROM customer_orders;


-- 6. Repeat vs One-Time Customer Value
WITH customer_stats AS (
  SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(oi.price) AS total_spend
  FROM `mis-analytics-project.Olist.Orders` o
  JOIN `mis-analytics-project.Olist.customers` c
    ON o.customer_id = c.customer_id
  JOIN `mis-analytics-project.Olist.Order_Items` oi
    ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
)
SELECT
  CASE
    WHEN order_count > 1 THEN 'Repeat Customer'
    ELSE 'One-Time Customer'
  END AS customer_type,
  COUNT(*) AS customers,
  ROUND(AVG(order_count), 2) AS avg_orders_per_customer,
  ROUND(AVG(total_spend), 2) AS avg_customer_value,
  ROUND(SUM(total_spend), 2) AS total_revenue
FROM customer_stats
GROUP BY customer_type;


-- 7. Shipping Efficiency by State
WITH order_shipping AS (
  SELECT
    order_id,
    SUM(price) AS product_value,
    SUM(freight_value) AS freight_value
  FROM `mis-analytics-project.Olist.Order_Items`
  GROUP BY order_id
)
SELECT
  c.customer_state,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(AVG(os.freight_value), 2) AS avg_freight_per_order,
  ROUND(
    AVG(SAFE_DIVIDE(os.freight_value, os.product_value)) * 100,
    2
  ) AS avg_freight_pct_of_product_value,
  ROUND(
    SAFE_DIVIDE(
      COUNTIF(o.order_delivered_customer_date > o.order_estimated_delivery_date),
      COUNT(*)
    ) * 100,
    2
  ) AS late_delivery_rate
FROM `mis-analytics-project.Olist.Orders` o
JOIN `mis-analytics-project.Olist.customers` c
  ON o.customer_id = c.customer_id
JOIN order_shipping os
  ON o.order_id = os.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_freight_pct_of_product_value DESC;
