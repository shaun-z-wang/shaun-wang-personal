#!/usr/bin/env bash
# Group 1 staging validation runner for PackagesService.BulkUpdatePackages
# (shoppers monolith). Dedicated suite — mirrors ../replace_packages/run_case.sh.
#
# IMPORTANT: shoppers PackagesService is Pumpkin RPC over HTTP (Twirp-style),
# NOT gRPC. The out-of-process client is curl, not grpcurl. See RUNLOG.md.
#
# Usage:
#   source env.sh            # sets BASE_URL, ORDER_DELIVERY_ID, AUTH_HEADER
#   ./run_case.sh <Method> <request_file.json>
#
# Examples:
#   ./run_case.sh BulkUpdatePackages requests/BUP-01_pickup_found_only.json
#   ./run_case.sh BulkGetPackages    requests/VERIFY_BulkGetPackages.json
#   ./run_case.sh ReplacePackages    requests/SEED_replace_packages.json
set -euo pipefail

SERVICE="instacart.fulfillment.domains.packing.v1.PackagesService"
METHOD="${1:?usage: run_case.sh <Method> <request_file.json>}"
REQ_FILE="${2:?usage: run_case.sh <Method> <request_file.json>}"

: "${BASE_URL:?set BASE_URL (e.g. https://<shoppers-rpc staging endpoint>) — see RUNLOG.md}"
: "${ORDER_DELIVERY_ID:?set ORDER_DELIVERY_ID (from DevGen provisioning) — see RUNLOG.md}"
AUTH_HEADER="${AUTH_HEADER:-}"   # e.g. "Authorization: Bearer <token>"; may be empty inside the mesh

URL="${BASE_URL%/}/rpc/${SERVICE}/${METHOD}"

# __ODID__ is the only template token in the request files.
BODY="$(sed "s/__ODID__/${ORDER_DELIVERY_ID}/g" "$REQ_FILE")"

echo "POST ${URL}"
echo "--- request body ---"
echo "$BODY"
echo "--- response ---"

curl_args=(-sS -w '\n--- http_status=%{http_code} ---\n'
  -X POST "$URL"
  -H 'Content-Type: application/json'
  -H 'Accept: application/json'
  --data-binary "$BODY")
[ -n "$AUTH_HEADER" ] && curl_args+=(-H "$AUTH_HEADER")

curl "${curl_args[@]}"
