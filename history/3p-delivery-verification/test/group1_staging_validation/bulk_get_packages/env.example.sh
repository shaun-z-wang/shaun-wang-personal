# Copy to env.sh and fill in the human/DevGen-supplied values, then `source env.sh`.
# Do NOT commit env.sh or paste real tokens anywhere.

# Deployed shoppers internal RPC (Pumpkin RPC-over-HTTP, Twirp-style) in staging.
# Reachable directly from this sandbox; no VPN hop / auth token needed inside the mesh.
export BASE_URL="https://rpc-shoppers-shoppers-stg.instacart.team"

# order_delivery_ids from DevGen provisioning + ReplacePackages seeding (see RUNLOG.md).
#   ODID_A: seeded with 2 packages   ODID_B: seeded with 3 packages   ODID_C: order with 0 packages
export ODID_A="__FILL_ME__"
export ODID_B="__FILL_ME__"
export ODID_C="__FILL_ME__"

# Service-to-service auth header. Empty inside the mesh.
export AUTH_HEADER=""
