#!/usr/bin/env bash
# Provision a fresh attended-delivery order in STAGING via DevGen (over curl),
# and print the order_delivery_id to use with run.sh.
#
# DevGen is reached the same way as the RPC under test: Pumpkin over HTTP POST,
# VPN-gated, no auth token. No MCP / OAuth needed.
set -euo pipefail

DEVGEN_URL="${DEVGEN_URL:-https://devgen-rpc-shoppers-shoppers-stg.instacart.team}"
DEVGEN_RPC="/rpc/instacart.dev_gen.v1.DevGenService/RunScript"

read -r -d '' SCRIPT_YAML <<'YAML' || true
commands:
- name: "create_user"
  output: ["user_id"]
- name: "copy_warehouse_location_address"
  output: ["address_id"]
  params:
    user_id: $user_id
- name: "generate_order"
  output: ["order_id", "delivery_ids", "delivery_id"]
  params:
    user_id: $user_id
    items_nothing: 3
YAML

payload=$(SCRIPT_YAML="$SCRIPT_YAML" python3 -c 'import json,os;print(json.dumps({"user_id":0,"script_yaml":os.environ["SCRIPT_YAML"]}))')

echo ">> provisioning attended-delivery order via DevGen ..." >&2
resp=$(curl -sS -m 60 -X POST "${DEVGEN_URL}${DEVGEN_RPC}" \
  -H "Content-Type: application/json" --data "$payload")

echo "$resp"
echo >&2
echo ">> Extract from resultYaml above:" >&2
echo ">>   :delivery_id:  -> export ORDER_DELIVERY_ID=<that value>" >&2
echo ">>   :order_id: / :user_id: are also returned for cross-checks." >&2
