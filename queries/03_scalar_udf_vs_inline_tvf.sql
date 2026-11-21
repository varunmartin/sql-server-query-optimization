/* =====================================================================
   Query 03: Scalar user-defined function vs inline table-valued function
   Goal: count orders per size band (Small / Medium / Large / XL)
         across all 500,000 orders.

   A classic scalar UDF is executed once PER ROW, and it also forces the
   whole query to run single-threaded. An inline table-valued function
   (iTVF) is expanded into the calling query like a view, so the optimizer
   sees through it.

   IMPORTANT: STATISTICS IO does not show work done inside scalar UDFs and
   the logical reads of the table scan stay the same. The difference shows
   up in CPU time and ELAPSED time, so compare those.

   Run each section SEPARATELY: highlight it, then Execute Query.
   The slow version may take several seconds on an emulated Mac setup.
   ===================================================================== */

USE StoreOpt;

/* ---------------------------------------------------------------------
   SECTION 0: Create the three functions (run once)
   --------------------------------------------------------------------- */
DROP FUNCTION IF EXISTS dbo.fn_order_band_scalar;
GO
DROP FUNCTION IF EXISTS dbo.fn_order_band_inline;
GO
DROP FUNCTION IF EXISTS dbo.fn_order_band_auto;
GO

-- Classic scalar UDF. INLINE = OFF forces the old per-row behavior
-- (SQL Server 2019+ might otherwise inline it automatically).
CREATE FUNCTION dbo.fn_order_band_scalar (@total DECIMAL(12,2))
RETURNS VARCHAR(10)
WITH INLINE = OFF
AS
BEGIN
    RETURN CASE WHEN @total <  500  THEN 'Small'
                WHEN @total < 1500  THEN 'Medium'
                WHEN @total < 3000  THEN 'Large'
                ELSE 'XL' END;
END;
GO

-- Inline table-valued function: same logic, expanded into the query.
CREATE FUNCTION dbo.fn_order_band_inline (@total DECIMAL(12,2))
RETURNS TABLE
AS
RETURN (
    SELECT CASE WHEN @total <  500  THEN 'Small'
                WHEN @total < 1500  THEN 'Medium'
                WHEN @total < 3000  THEN 'Large'
                ELSE 'XL' END AS band
);
GO

-- Same scalar UDF, but WITHOUT INLINE = OFF (used in the bonus section).
CREATE FUNCTION dbo.fn_order_band_auto (@total DECIMAL(12,2))
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN CASE WHEN @total <  500  THEN 'Small'
                WHEN @total < 1500  THEN 'Medium'
                WHEN @total < 3000  THEN 'Large'
                ELSE 'XL' END;
END;
GO


/* ---------------------------------------------------------------------
   SECTION 1: BEFORE - classic scalar UDF (called once per row)
   Expect: noticeably high CPU and elapsed time, serial plan.
   --------------------------------------------------------------------- */
SET STATISTICS IO, TIME ON;
CHECKPOINT; DBCC DROPCLEANBUFFERS;

SELECT x.band, COUNT(*) AS order_count
FROM  (SELECT dbo.fn_order_band_scalar(total_amount) AS band
       FROM   dbo.orders) AS x
GROUP BY x.band
ORDER BY x.band;


/* ---------------------------------------------------------------------
   SECTION 2: AFTER - inline table-valued function via CROSS APPLY
   Same result. Expect: far lower CPU and elapsed time,
   and the plan can use parallelism.
   --------------------------------------------------------------------- */
SET STATISTICS IO, TIME ON;
CHECKPOINT; DBCC DROPCLEANBUFFERS;

SELECT b.band, COUNT(*) AS order_count
FROM   dbo.orders o
CROSS APPLY dbo.fn_order_band_inline(o.total_amount) AS b
GROUP BY b.band
ORDER BY b.band;


/* ---------------------------------------------------------------------
   SECTION 3 (BONUS): the same scalar UDF WITHOUT "INLINE = OFF"
   SQL Server 2019+ can inline simple scalar UDFs automatically, so this
   may be about as fast as Section 2. It only works when the function meets
   certain rules (no loops, no table variables, no time-dependent built-ins,
   and so on), so don't rely on it for every function.
   --------------------------------------------------------------------- */
SET STATISTICS IO, TIME ON;
CHECKPOINT; DBCC DROPCLEANBUFFERS;

SELECT x.band, COUNT(*) AS order_count
FROM  (SELECT dbo.fn_order_band_auto(total_amount) AS band
       FROM   dbo.orders) AS x
GROUP BY x.band
ORDER BY x.band;


/* ---------------------------------------------------------------------
   SECTION 4: Proof that the scalar and inline versions agree
   Expect: mismatches = 0
   --------------------------------------------------------------------- */
SELECT COUNT(*) AS mismatches
FROM   dbo.orders o
CROSS APPLY dbo.fn_order_band_inline(o.total_amount) AS b
WHERE  b.band <> dbo.fn_order_band_scalar(o.total_amount);
