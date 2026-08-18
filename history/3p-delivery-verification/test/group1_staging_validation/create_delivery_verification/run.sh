#!/usr/bin/env bash
# Group 1 CreateDeliveryVerification staging runner.
#
#   ./run.sh <CASE_ID>            # e.g. ./run.sh G1-CDV-12
#   ./run.sh <CASE_ID> --replay   # send the same request twice (idempotency)
#   ./run.sh --list               # list curl-expressible cases + expected result
#
# Substitutes __ORDER_DELIVERY_ID__ and __IMG_*__ tokens from env.sh into the
# request template, POSTs to deployed staging, prints HTTP status + body, then
# the expected result and the out-of-band verification hint for that case.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$DIR/env.sh"

if [[ "${1:-}" == "--list" ]]; then
  column -t -s $'\t' "$DIR/cases.tsv"; exit 0
fi

CASE="${1:?usage: ./run.sh <CASE_ID> [--replay] | --list}"
REQ="$DIR/requests/${CASE}.json"
[[ -f "$REQ" ]] || { echo "No request template for $CASE (see cases.tsv 'curl?' column)"; exit 2; }

if grep -q "__SET_" <<<"$ORDER_DELIVERY_ID $IMG_JPEG $IMG_TOOLARGE $IMG_GIF"; then :; fi
body=$(sed \
  -e "s|__ORDER_DELIVERY_ID__|${ORDER_DELIVERY_ID}|g" \
  -e "s|__IMG_PNG2__|${IMG_PNG2}|g" \
  -e "s|__IMG_PNG__|${IMG_PNG}|g" \
  -e "s|__IMG_JPEG__|${IMG_JPEG}|g" \
  -e "s|__IMG_4XX__|${IMG_4XX}|g" \
  -e "s|__IMG_5XX__|${IMG_5XX}|g" \
  -e "s|__IMG_TOOLARGE__|${IMG_TOOLARGE}|g" \
  -e "s|__IMG_GIF__|${IMG_GIF}|g" \
  -e "s|__IMG_SSRF__|${IMG_SSRF}|g" \
  "$REQ")

if grep -q "__SET_" <<<"$body"; then
  echo "!! request still contains an unresolved placeholder — set it in env.sh:"; grep -o "__SET_[A-Z_]*__" <<<"$body" | sort -u; exit 3
fi

url="${BASE_URL}/rpc/${SERVICE}/${METHOD}"
send() {
  echo ">> POST $url"; echo ">> body: $body"
  curl -sS -m 30 -w $'\n>> HTTP %{http_code}\n' -X POST "$url" \
    -H "Content-Type: application/json" -H "ic-client-svc: ${IC_CLIENT_SVC}" \
    -H "ic-request-id: g1-$(date +%s)-$RANDOM" --data "$body"
}
echo "=== $CASE @ $(date -u +%FT%TZ) ==="; send
if [[ "${2:-}" == "--replay" ]]; then echo; echo "=== $CASE REPLAY @ $(date -u +%FT%TZ) ==="; send; fi

echo; echo ">> Expected + verify:"; grep -P "^${CASE}\t" "$DIR/cases.tsv" | column -t -s $'\t' || true
