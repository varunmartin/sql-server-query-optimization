# sql-server-query-optimization
Hands-on SQL Server query tuning: slow vs optimized T-SQL with execution plans, indexes and measured results

## Query 01: Non-SARGable date filter

**Problem:** Finding last month's orders with `WHERE YEAR(order_date) = ... AND MONTH(order_date) = ...`
forces SQL Server to evaluate the functions on all 500,000 rows. Even with an index on
`order_date`, it can't seek.

**Fix:** Rewrite as a half-open date range (`>= @start AND < @end`) and add a covering index
on `order_date` that includes `customer_id` and `total_amount`.

| Version | Plan | Logical reads | Elapsed |
|---|---|---|---|
| Before (function, no index) | Clustered Index Scan | 2,853 | 130 ms |
| Function + index | Index Scan | 1,929 | 92 ms |
| After (range + index) | Index Seek | 60 | 19 ms |

**Improvement:** 97.9% fewer logical reads (2,853 → 60) for the same 14,479 rows.

**Takeaway:** An index alone doesn't help if the predicate wraps the column in a function.
The query has to be SARGable for SQL Server to seek.

Script: [`queries/01_non_sargable_date_filter.sql`](queries/01_non_sargable_date_filter.sql)


## Query 02: Missing foreign key indexes

**Problem:** Fetching one customer's orders with their line items and product names joins
`orders` to `order_items`. Neither `orders.customer_id` nor `order_items.order_id` was indexed
(SQL Server doesn't index foreign keys automatically), so the query scanned the full 500,000-row
`orders` table and the full 1.5M-row `order_items` table to return just 30 rows.

**Fix:** Add covering nonclustered indexes on both the filter and join columns:
- `IX_orders_customer_id` on `orders(customer_id)` including `order_date`
- `IX_order_items_order_id` on `order_items(order_id)` including `product_id, quantity, unit_price`

| Version | `orders` reads | `order_items` reads | Total logical reads | CPU | Elapsed |
|---|---|---|---|---|---|
| Before (no FK indexes) | 2,996 | 7,203 | 10,259 | 405 ms | 113 ms |
| Only `order_items` indexed | 2,853 | 30 | 2,896 | 42 ms | 47 ms |
| After (both indexed) | 3 | 30 | 46 | 5 ms | 6 ms |

**Improvement:** 99.6% fewer logical reads (10,259 → 46) for the same 30 rows, and
elapsed time dropped from 113 ms to 6 ms.

**Takeaway:** Index the columns you filter and join on. Fixing only one side of a join (second row)
removed most of the `order_items` reads but left `orders` scanning in full, so both sides needed an index.

Script: [`queries/02_missing_fk_indexes.sql`](queries/02_missing_fk_indexes.sql)


## Query 03: Scalar UDF vs inline table-valued function

**Problem:** Classifying all 500,000 orders into size bands with a scalar user-defined
function means SQL Server calls the function once per row. Queries that call a non-inlined scalar
UDF also can't use parallelism, and `STATISTICS IO` doesn't report the cost, so the problem is
easy to miss.

**Fix:** Rewrite the logic as an inline table-valued function and call it with `CROSS APPLY`.
The optimizer expands it into the main query like a view.

| Version | Logical reads (`orders`) | CPU | Elapsed |
|---|---|---|---|
| Before (scalar UDF, `INLINE = OFF`) | 2,853 | 1,793 ms | 2,056 ms |
| After (inline TVF + `CROSS APPLY`) | 2,853 | 73 ms | 77 ms |
| Bonus: scalar UDF with auto-inlining (SQL Server 2019+) | 2,853 | 159 ms | 160 ms |

**Improvement:** 96.3% lower elapsed time (2,056 → 77 ms, about 27× faster) with identical results
(verified: 0 mismatches between the scalar and inline versions).

**Takeaways:**
- Logical reads were identical in all three versions, so reads alone would have hidden the problem.
  Always compare CPU and elapsed time too.
- SQL Server 2019+ can inline simple scalar UDFs automatically, which helped a lot (2,056 → 160 ms),
  but it only applies to functions that meet certain restrictions, and here it was still slower than
  the explicit inline TVF. Writing the function as an inline TVF doesn't depend on that feature.

Script: [`queries/03_scalar_udf_vs_inline_tvf.sql`](queries/03_scalar_udf_vs_inline_tvf.sql)
