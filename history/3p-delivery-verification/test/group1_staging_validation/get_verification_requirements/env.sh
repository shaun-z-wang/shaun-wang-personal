# Group 1 staging validation — GetVerificationRequirements harness config.
# Source this (run_case.sh does automatically) or override any value inline.
#
# Group 1 = call the DEPLOYED STAGING RPC directly with curl (Pumpkin/Twirp
# over HTTP POST — NOT grpc). No FPS. No auth token (VPN/mesh placement only).
# GetVerificationRequirements is a READ (no writes, no Sidekiq) — the RPC
# response itself is the assertion; NOT_FOUND is cross-checked via the
# `custom.delivery_verification_service.rpc_order_details_not_found` DD metric.

: "${BASE_URL:=https://rpc-shoppers-shoppers-stg.instacart.team}"
SERVICE="instacart.fulfillment.delivery.delivery_verification.v1.DeliveryVerificationService"
METHOD="GetVerificationRequirements"
: "${IC_CLIENT_SVC:=relay.worker.shoppers.shoppers}"

# --- Provisioned order_delivery_ids (DevGen, staging, 2026-08-05) ---
# Each maps to one order shape. See RUNLOG.md for the provisioning recipe.
: "${ODID_MKT:=20812396763494404}"       # marketplace, no special items (reused from replace_packages)
: "${ODID_ALC_US:=20813434056449244}"    # alcoholic, Safeway US (delivery state = CA)
: "${ODID_ALC_CA:=20813459830409416}"    # alcoholic, Costco Canada (zone 693, country 124)
: "${ODID_RX_ATT:=20813477676430844}"    # rx, attended, warehouse 5, no driver/batch
: "${ODID_RX_UN:=20813474031409464}"     # rx, is_unattended:true, warehouse 5, no driver/batch
: "${ODID_PIN:=20813444285502584}"       # customer_handoff_pin "4823" -> pin_exchange certified_delivery
: "${ODID_NONEXISTENT:=999999999999999}" # never provisioned -> OrderDetails NOT_FOUND
: "${ODID_ZERO:=0}"                       # order_delivery_id 0 -> (see FINDING: NOT_FOUND, not InvalidArgument)
