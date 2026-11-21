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
(SQL Server doesn't index foreign keys automatically), so the query scanned 500,000 order rows
and 1.5 million line-item rows to return 30 rows.

**Fix:** Add covering nonclustered indexes on both join/filter columns:
- `IX_orders_customer_id` on `orders(customer_id)` including `order_date`
- `IX_order_items_order_id` on `order_items(order_id)` including `product_id, quantity, unit_price`

| Version | Plan | Total logical reads | Elapsed |
|---|---|---|---|
| Before (no FK indexes) | Scan + Scan, hash join | ___ | ___ ms |
| Only `order_items` indexed | Scan on orders, Seek on order_items | ___ | ___ ms |
| After (both indexed) | Seek + Seek, nested loops | ___ | ___ ms |

**Improvement:** ___% fewer logical reads for the same 30 rows.

**Takeaway:** Index the columns you filter and join on. Fixing one side of a join leaves the
other side scanning.

Script: [`queries/02_missing_fk_indexes.sql`](queries/02_missing_fk_indexes.sql)
