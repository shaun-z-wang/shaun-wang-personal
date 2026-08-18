#!/usr/bin/env bash
# Group 1 staging validation runner for PackagesService.BulkGetPackages (shoppers monolith).
#
# IMPORTANT: shoppers PackagesService is Pumpkin RPC over HTTP (Twirp-style),
# NOT gRPC. The out-of-process client is curl, not grpcurl. READ, SYNC (direct
# DB read of the `bags` table, no Sidekiq). See RUNLOG.md.
#
# Usage:
#   source env.sh                       # sets BASE_URL, ODID_A/B/C, AUTH_HEADER
#   ./run_case.sh <request_file.json>   # method is always BulkGetPackages
#   ./run_case.sh --list                # list cases + expected result
#
# Examples:
#   ./run_case.sh requests/G1-BGP-01_single.json
#   ./run_case.sh requests/G1-BGP-10_zero_odid.json   # WARNING: reproduces the seq-scan timeout
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--list" ]]; then
  column -t -s $'\t' "$DIR/cases.tsv"; exit 0
fi

# shellcheck source=/dev/null
source "$DIR/env.sh"

SERVICE="instacart.fulfillment.domains.packing.v1.PackagesService"
METHOD="BulkGetPackages"
REQ_FILE="${1:?usage: run_case.sh <request_file.json> | --list}"

: "${BASE_URL:?set BASE_URL — see env.example.sh}"
: "${ODID_A:?set ODID_A (DevGen-provisioned, 2 pkgs) — see env.example.sh}"
: "${ODID_B:?set ODID_B (DevGen-provisioned, 3 pkgs) — see env.example.sh}"
: "${ODID_C:?set ODID_C (DevGen-provisioned, 0 pkgs) — see env.example.sh}"
AUTH_HEADER="${AUTH_HEADER:-}"

URL="${BASE_URL%/}/rpc/${SERVICE}/${METHOD}"

# Template tokens substituted into request files.
BODY="$(sed \
  -e "s/__ODID_A__/${ODID_A}/g" \
  -e "s/__ODID_B__/${ODID_B}/g" \
  -e "s/__ODID_C__/${ODID_C}/g" \
  "$REQ_FILE")"

echo "POST ${URL}"
echo "--- request body ---"
echo "$BODY"
echo "--- response ---"

curl_args=(-sS -m 35 -w '\n--- http_status=%{http_code} ---\n'
  -X POST "$URL"
  -H 'Content-Type: application/json'
  -H 'Accept: application/json'
  --data-binary "$BODY")
[ -n "$AUTH_HEADER" ] && curl_args+=(-H "$AUTH_HEADER")

curl "${curl_args[@]}"
