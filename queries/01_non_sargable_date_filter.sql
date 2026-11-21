/* =====================================================================
   Query 01: Non-SARGable date filter
   Goal: list all orders placed in a given month (last calendar month).

   Run each section SEPARATELY: highlight the section, then Execute Query.
   Before each run, turn on the statistics (they appear in the Messages tab):
       SET STATISTICS IO, TIME ON;
   ===================================================================== */

USE StoreOpt;

/* ---------------------------------------------------------------------
   SECTION 0: Reset (run this first, and any time you want to start over)
   --------------------------------------------------------------------- */
DROP INDEX IF EXISTS IX_orders_order_date ON dbo.orders;


/* ---------------------------------------------------------------------
   SECTION 1: BEFORE - function on the column, no supporting index
   Expect: Clustered Index Scan, ~500,000 rows read.
   --------------------------------------------------------------------- */
SET STATISTICS IO, TIME ON;
CHECKPOINT; DBCC DROPCLEANBUFFERS;   -- cold cache for a fair comparison

DECLARE @ref   DATETIME2 = DATEADD(MONTH, -1, SYSDATETIME());
DECLARE @year  INT = YEAR(@ref);
DECLARE @month INT = MONTH(@ref);

SELECT order_id, customer_id, order_date, total_amount
FROM   dbo.orders
WHERE  YEAR(order_date) = @year
  AND  MONTH(order_date) = @month
OPTION (RECOMPILE);   -- plan is built with the real variable values


/* ---------------------------------------------------------------------
   SECTION 2: Still slow - add an index but KEEP the function
   The index exists, yet SQL Server cannot SEEK on YEAR(order_date).
   Expect: Index Scan (reads drop a little since the index is narrower,
   but it still touches every row).
   --------------------------------------------------------------------- */
CREATE NONCLUSTERED INDEX IX_orders_order_date
    ON dbo.orders (order_date)
    INCLUDE (customer_id, total_amount);

SET STATISTICS IO, TIME ON;
CHECKPOINT; DBCC DROPCLEANBUFFERS;

DECLARE @ref   DATETIME2 = DATEADD(MONTH, -1, SYSDATETIME());
DECLARE @year  INT = YEAR(@ref);
DECLARE @month INT = MONTH(@ref);

SELECT order_id, customer_id, order_date, total_amount
FROM   dbo.orders
WHERE  YEAR(order_date) = @year
  AND  MONTH(order_date) = @month
OPTION (RECOMPILE);


/* ---------------------------------------------------------------------
   SECTION 3: AFTER - SARGable date range + the index
   Same rows returned, but now SQL Server can SEEK straight to the month.
   Expect: Index Seek, only the rows for that month are read.
   --------------------------------------------------------------------- */
SET STATISTICS IO, TIME ON;
CHECKPOINT; DBCC DROPCLEANBUFFERS;

DECLARE @ref   DATETIME2 = DATEADD(MONTH, -1, SYSDATETIME());
DECLARE @start DATETIME2 = DATEFROMPARTS(YEAR(@ref), MONTH(@ref), 1);
DECLARE @end   DATETIME2 = DATEADD(MONTH, 1, @start);

SELECT order_id, customer_id, order_date, total_amount
FROM   dbo.orders
WHERE  order_date >= @start
  AND  order_date <  @end
OPTION (RECOMPILE);


/* ---------------------------------------------------------------------
   SECTION 4: Proof that both versions return the same rows
   Expect: both counts are identical.
   --------------------------------------------------------------------- */
DECLARE @ref   DATETIME2 = DATEADD(MONTH, -1, SYSDATETIME());
DECLARE @start DATETIME2 = DATEFROMPARTS(YEAR(@ref), MONTH(@ref), 1);
DECLARE @end   DATETIME2 = DATEADD(MONTH, 1, @start);

SELECT
  (SELECT COUNT(*) FROM dbo.orders
   WHERE YEAR(order_date) = YEAR(@ref) AND MONTH(order_date) = MONTH(@ref)) AS slow_version_rows,
  (SELECT COUNT(*) FROM dbo.orders
   WHERE order_date >= @start AND order_date < @end)                       AS fast_version_rows;
