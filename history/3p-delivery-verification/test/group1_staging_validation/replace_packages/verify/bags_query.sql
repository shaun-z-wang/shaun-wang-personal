-- Out-of-band verification of ReplacePackages persistence on the shoppers `bags` table.
-- Run against the staging shoppers DB. Reach it with an isc db proxy, e.g.:
--   isc db proxy -e staging <shoppers-datastore>     # opens a local proxy port
--   psql "postgres://<user>@localhost:<proxy_port>/<db>"
-- (Confirm the exact datastore name with `isc db list -e staging`.)
--
-- Replace :odid with the provisioned order_delivery_id.

-- All bags for the order delivery, newest first — confirms the new columns
-- (visual_identifier, scan_identifier_type, has_alternative_identifier) round-trip.
SELECT id,
       order_delivery_id,
       "index",
       bag_type,
       location_type,
       location_name,
       bag_scan_identifier,
       scan_identifier_type,
       visual_identifier,
       has_alternative_identifier,
       item_collection_id,
       found_at,
       verified_at,
       created_at,
       updated_at
FROM bags
WHERE order_delivery_id = :odid
ORDER BY "index" ASC;

-- Count == ReplacePackagesResponse.total_package_count.
SELECT COUNT(*) AS total_package_count
FROM bags
WHERE order_delivery_id = :odid;
