/* =====================================================================
   Query 02: Missing indexes on foreign keys
   Goal: show one customer's orders with their line items and product names.

   Foreign keys do NOT create indexes in SQL Server. Here, neither
   orders.customer_id nor order_items.order_id is indexed, so every lookup
   by those columns reads whole tables.

   Run each section SEPARATELY: highlight it, then Execute Query.
   Read the numbers in the Messages tab AFTER the "(30 rows affected)" line.
   (Ignore the lines produced by CREATE INDEX itself.)
   ===================================================================== */

USE StoreOpt;

/* ---------------------------------------------------------------------
   SECTION 0: Reset to a clean baseline (run first, and to start over)
   Also drops the Query 01 index so it cannot be used as a shortcut here.
   --------------------------------------------------------------------- */
DROP INDEX IF EXISTS IX_orders_order_date    ON dbo.orders;
DROP INDEX IF EXISTS IX_orders_customer_id   ON dbo.orders;
DROP INDEX IF EXISTS IX_order_items_order_id ON dbo.order_items;


/* ---------------------------------------------------------------------
   SECTION 1: BEFORE - no foreign key indexes
   Expect: Clustered Index Scan on orders AND on order_items
   (1.5M rows scanned just to find ~30), joined with a hash join.
   --------------------------------------------------------------------- */
SET STATISTICS IO, TIME ON;
CHECKPOINT; DBCC DROPCLEANBUFFERS;

DECLARE @customer_id INT = 12345;

SELECT o.order_id, o.order_date, p.product_name, oi.quantity, oi.unit_price
FROM   dbo.orders o
JOIN   dbo.order_items oi ON oi.order_id   = o.order_id
JOIN   dbo.products p     ON p.product_id  = oi.product_id
WHERE  o.customer_id = @customer_id
OPTION (RECOMPILE);


/* ---------------------------------------------------------------------
   SECTION 2: PARTIAL FIX - index only order_items.order_id
   Expect: order_items is now read by seek, but orders is STILL scanned
   because customer_id has no index yet.
   --------------------------------------------------------------------- */
CREATE NONCLUSTERED INDEX IX_order_items_order_id
    ON dbo.order_items (order_id)
    INCLUDE (product_id, quantity, unit_price);

SET STATISTICS IO, TIME ON;
CHECKPOINT; DBCC DROPCLEANBUFFERS;

DECLARE @customer_id INT = 12345;

SELECT o.order_id, o.order_date, p.product_name, oi.quantity, oi.unit_price
FROM   dbo.orders o
JOIN   dbo.order_items oi ON oi.order_id   = o.order_id
JOIN   dbo.products p     ON p.product_id  = oi.product_id
WHERE  o.customer_id = @customer_id
OPTION (RECOMPILE);


/* ---------------------------------------------------------------------
   SECTION 3: AFTER - index orders.customer_id as well
   Expect: Index Seek on orders, Index Seek on order_items, and a small
   nested-loops join. Only a handful of pages are read in total.
   --------------------------------------------------------------------- */
CREATE NONCLUSTERED INDEX IX_orders_customer_id
    ON dbo.orders (customer_id)
    INCLUDE (order_date);

SET STATISTICS IO, TIME ON;
CHECKPOINT; DBCC DROPCLEANBUFFERS;

DECLARE @customer_id INT = 12345;

SELECT o.order_id, o.order_date, p.product_name, oi.quantity, oi.unit_price
FROM   dbo.orders o
JOIN   dbo.order_items oi ON oi.order_id   = o.order_id
JOIN   dbo.products p     ON p.product_id  = oi.product_id
WHERE  o.customer_id = @customer_id
OPTION (RECOMPILE);
