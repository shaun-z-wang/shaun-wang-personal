#!/usr/bin/env bash
# Group 1 GetVerificationRequirements staging runner (READ path, no FPS).
#
#   ./run_case.sh <CASE_ID>     # e.g. ./run_case.sh G1-GVR-02
#   ./run_case.sh --all         # run every curl-expressible case
#   ./run_case.sh --list        # print the case matrix
#
# GetVerificationRequirements is a pure read: POSTs {"orderDeliveryId": <id>}
# to deployed staging and prints HTTP status + body, then the expected result.
# The request body has exactly one field, so each case just selects an order id
# (see env.sh) — the per-case request templates under requests/ mirror that.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$DIR/env.sh"

if [[ "${1:-}" == "--list" ]]; then column -t -s $'\t' "$DIR/cases.tsv"; exit 0; fi

# Case -> provisioned order_delivery_id. Only curl-expressible cases are listed;
# author-only cases (see cases.tsv RESULT column) have no mapping here.
case_odid() {
  case "$1" in
    G1-GVR-01) echo "$ODID_MKT" ;;
    G1-GVR-02) echo "$ODID_ALC_US" ;;
    G1-GVR-03) echo "$ODID_ALC_CA" ;;
    G1-GVR-05) echo "$ODID_RX_ATT" ;;
    G1-GVR-07) echo "$ODID_RX_UN" ;;
    G1-GVR-09) echo "$ODID_PIN" ;;
    G1-GVR-10) echo "$ODID_MKT" ;;      # id NOT required -> minimum_age omitted
    G1-GVR-11) echo "$ODID_NONEXISTENT" ;;
    G1-GVR-12) echo "$ODID_NONEXISTENT" ;;  # same OrderDetails-not-found path as 11
    G1-GVR-15) echo "$ODID_ALC_US" ;;   # signature value tracks alcohol-signature-by-state flag
    G1-GVR-ZERO) echo "$ODID_ZERO" ;;   # orderDeliveryId 0 (FINDING: NOT_FOUND, not InvalidArgument)
    *) echo "" ;;
  esac
}

url="${BASE_URL%/}/rpc/${SERVICE}/${METHOD}"

run_one() {
  local case_id="$1" odid
  odid="$(case_odid "$case_id")"
  if [[ -z "$odid" ]]; then
    echo ">> $case_id has no curl mapping (author-only; see cases.tsv RESULT)"; return 0
  fi
  local body="{\"orderDeliveryId\":\"${odid}\"}"
  echo "=== $case_id  (order_delivery_id=$odid) @ $(date -u +%FT%TZ) ==="
  echo ">> POST $url"
  echo ">> body: $body"
  curl -sS -m 30 -w $'\n>> HTTP %{http_code}\n' -X POST "$url" \
    -H "Content-Type: application/json" -H "ic-client-svc: ${IC_CLIENT_SVC}" \
    -H "ic-request-id: g1-gvr-$(date +%s)-$RANDOM" --data "$body"
  echo; echo ">> Expected + verify:"
  grep -P "^${case_id}\t" "$DIR/cases.tsv" | column -t -s $'\t' || true
  echo
}

if [[ "${1:-}" == "--all" ]]; then
  for c in G1-GVR-01 G1-GVR-02 G1-GVR-03 G1-GVR-05 G1-GVR-07 G1-GVR-09 \
           G1-GVR-10 G1-GVR-11 G1-GVR-12 G1-GVR-15 G1-GVR-ZERO; do run_one "$c"; done
  exit 0
fi

run_one "${1:?usage: ./run_case.sh <CASE_ID> | --all | --list}"
