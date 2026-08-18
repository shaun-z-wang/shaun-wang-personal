# Copy to env.sh and fill in the human-supplied values, then `source env.sh`.
# Do NOT commit env.sh or paste real tokens anywhere.

# Base URL of the deployed shoppers internal RPC (shoppers-shoppers-rpc) in staging.
# This is a Pumpkin RPC-over-HTTP endpoint. The canonical internal hostname is
# derived from the proto package, reversed, e.g.:
#   v1.packing.domains.fulfillment.instacart.staging.internal.pika.ac
# but the real reachable address is whatever FPS's deploy sets in
#   RPC_INSTACART_FULFILLMENT_DOMAINS_DISPATCH_V1_ADDR
# (FPS shares one connection for all shoppers backend clients). Confirm the exact
# value with: isc conf get -e staging <fps-service> | grep RPC_..._ADDR
# *.internal.pika.ac is mesh-internal — reachable only from inside the mesh/VPN.
export BASE_URL="https://__FILL_ME__.staging.internal.pika.ac"

# order_delivery_id from DevGen provisioning (see devgen/provision_group1_order.yaml).
export ORDER_DELIVERY_ID="__FILL_ME__"

# Service-to-service auth header. May be empty when running from inside the mesh
# (e.g. via `isc run`/`isc shell` on a staging container that already holds the
# service identity). Otherwise supply the fernet/service token the mesh expects.
export AUTH_HEADER=""
