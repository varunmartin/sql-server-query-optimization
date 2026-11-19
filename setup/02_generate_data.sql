/* =====================================================================
   02_generate_data.sql
   Generates synthetic data (no real data involved):
     customers    50,000
     categories       20
     products      2,000
     orders      500,000
     order_items 1,500,000
     payments    ~375,000
   Values are deterministic (no randomness), so everyone gets the same data.
   Expect roughly 1-3 minutes to run.
   ===================================================================== */

USE StoreOpt;
GO
SET NOCOUNT ON;
GO

-- Customers ------------------------------------------------------------
;WITH n AS (
    SELECT TOP (50000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT dbo.customers (first_name, last_name, email, city, country, created_at)
SELECT CONCAT('First', i),
       CONCAT('Last', i),
       CONCAT('user', i, '@example.com'),
       CHOOSE(i % 5 + 1, 'Kochi', 'Mumbai', 'Delhi', 'Chennai', 'Bengaluru'),
       CHOOSE(i % 4 + 1, 'India', 'USA', 'UK', 'Germany'),
       DATEADD(DAY, -(i % 1500), SYSDATETIME())
FROM n;

-- Categories -----------------------------------------------------------
;WITH n AS (
    SELECT TOP (20) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects
)
INSERT dbo.categories (category_name)
SELECT CONCAT('Category ', i) FROM n;

-- Products -------------------------------------------------------------
;WITH n AS (
    SELECT TOP (2000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT dbo.products (category_id, product_name, unit_price, is_active)
SELECT i % 20 + 1,
       CONCAT('Product ', i),
       CAST(5 + (i * 37) % 495 AS DECIMAL(10,2)) + 0.99,
       CASE WHEN i % 10 = 0 THEN 0 ELSE 1 END
FROM n;

-- Orders (spread over the last ~3 years) --------------------------------
;WITH n AS (
    SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT dbo.orders (customer_id, order_date, status, total_amount)
SELECT CAST((i * 7919) % 50000 + 1 AS INT),
       DATEADD(MINUTE, -((i * 37) % 1576800), SYSDATETIME()),
       CHOOSE(i % 4 + 1, 'Pending', 'Shipped', 'Delivered', 'Cancelled'),
       0
FROM n;

-- Order items (3 per order) ----------------------------------------------
INSERT dbo.order_items (order_id, product_id, quantity, unit_price)
SELECT o.order_id,
       p.product_id,
       (o.order_id + v.k) % 5 + 1,
       p.unit_price
FROM dbo.orders o
CROSS JOIN (VALUES (1), (2), (3)) v(k)
JOIN dbo.products p
  ON p.product_id = (o.order_id * 7 + v.k * 131) % 2000 + 1;

-- Order totals -----------------------------------------------------------
UPDATE o
SET    total_amount = x.total
FROM   dbo.orders o
JOIN  (SELECT order_id, SUM(quantity * unit_price) AS total
       FROM dbo.order_items GROUP BY order_id) x
  ON  x.order_id = o.order_id;

-- Payments (all non-cancelled orders) ---------------------------------------
INSERT dbo.payments (order_id, payment_date, amount, method)
SELECT order_id,
       DATEADD(MINUTE, 30, order_date),
       total_amount,
       CHOOSE(order_id % 3 + 1, 'Card', 'UPI', 'NetBanking')
FROM dbo.orders
WHERE status <> 'Cancelled';
GO

-- Sanity check -------------------------------------------------------------
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM dbo.customers UNION ALL
SELECT 'categories',  COUNT(*) FROM dbo.categories  UNION ALL
SELECT 'products',    COUNT(*) FROM dbo.products    UNION ALL
SELECT 'orders',      COUNT(*) FROM dbo.orders      UNION ALL
SELECT 'order_items', COUNT(*) FROM dbo.order_items UNION ALL
SELECT 'payments',    COUNT(*) FROM dbo.payments;
GO
