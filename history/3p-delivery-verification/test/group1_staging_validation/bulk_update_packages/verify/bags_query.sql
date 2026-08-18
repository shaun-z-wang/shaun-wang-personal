-- Out-of-band verification of BulkUpdatePackages persistence on the shoppers `bags` table.
--
-- Fastest path (used for this suite): Blazer MCP, data source `shoppers_staging`.
-- Blazer requires a time filter; keep the created_at window.
-- Substitute :odid with the provisioned order_delivery_id (env.sh ORDER_DELIVERY_ID).
--
-- Alternatively via isc db proxy:
--   isc db proxy -e staging <shoppers-datastore>
--   psql "postgres://<user>@localhost:<proxy_port>/<db>"

-- Per-bag scan/verification state. Confirms found_*/verified_* changed on the
-- targeted scan_identifiers and that partial updates did not clobber siblings.
-- NOTE: found_via/verified_via are stored as lowercase strings ("scanner",
-- "force_mark"); the RPC maps them to SCAN_METHOD_* enums.
SELECT id,
       "index",
       bag_scan_identifier,
       found_at,
       found_via,
       verified_at,
       verified_via,
       updated_at
FROM bags
WHERE order_delivery_id = :odid
  AND created_at >= {blazer_now} - interval '4 hours'   -- drop this line outside Blazer
ORDER BY "index" ASC;
