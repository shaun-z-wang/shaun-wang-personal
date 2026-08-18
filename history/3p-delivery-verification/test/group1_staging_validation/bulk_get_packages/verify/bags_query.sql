-- Out-of-band verification of BulkGetPackages reads against the shoppers `bags` table.
-- BulkGetPackages is READ-ONLY: it returns bag rows keyed by order_delivery_id,
-- mapped to Package protos, sorted Ruby-side by (order_delivery_id ASC, index ASC).
--
-- Run via Blazer (data source: shoppers_staging) or an isc db proxy. Blazer
-- requires a time-range filter; the created_at window below is only there to
-- satisfy that guard (widen if seeds are older).
--
-- Replace the id list with the provisioned ODID_A / ODID_B / ODID_C.

-- Per-delivery row counts + index range. Confirms the RPC's count and grouping.
SELECT order_delivery_id,
       COUNT(*)        AS n,
       MIN("index")    AS min_idx,
       MAX("index")    AS max_idx
FROM bags
WHERE order_delivery_id IN (20812396763494404, 20813448721449264, 20813450726495452)
  AND created_at >= {blazer_now} - interval '90 days'
GROUP BY order_delivery_id
ORDER BY order_delivery_id ASC;

-- Full round-trip of each field the proto exposes, in the RPC's return order.
SELECT order_delivery_id,
       "index",
       id,
       bag_type,
       location_type,
       location_name,
       bag_scan_identifier,
       scan_identifier_type,
       visual_identifier,
       has_alternative_identifier,
       found_at,
       verified_at
FROM bags
WHERE order_delivery_id IN (20812396763494404, 20813448721449264, 20813450726495452)
  AND created_at >= {blazer_now} - interval '90 days'
ORDER BY order_delivery_id ASC, "index" ASC;

-- ROOT CAUSE of the order_delivery_id=0 timeout (G1-BGP-10/11). Run EXPLAIN only;
-- a real SELECT on order_delivery_id=0 seq-scans the whole table and will time out.
--   EXPLAIN SELECT * FROM bags WHERE order_delivery_id = 0;
-- Observed staging plan: "Seq Scan on bags (cost=0.00..43744533.40 rows=1068132672 ...)"
-- vs a real id list: "Index Scan using index_bags_on_order_delivery_id ... rows=1".
