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
