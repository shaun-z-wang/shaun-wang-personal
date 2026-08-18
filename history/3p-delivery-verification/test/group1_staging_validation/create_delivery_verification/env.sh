# Group 1 staging validation — CreateDeliveryVerification harness config.
# Source this (run.sh does automatically) or override any value inline:
#   ORDER_DELIVERY_ID=123 ./run.sh G1-CDV-12
#
# Group 1 = call the DEPLOYED STAGING RPC directly with curl (Pumpkin/Twirp
# over HTTP POST — NOT grpc). No FPS. No auth token (VPN/mesh placement only).
# Verify out-of-band via Blazer (shoppers_staging) + Datadog (custom.* metrics).

# --- Staging endpoint (VPN-gated; no bearer token) ---
: "${BASE_URL:=https://rpc-shoppers-shoppers-stg.instacart.team}"
SERVICE="instacart.fulfillment.delivery.delivery_verification.v1.DeliveryVerificationService"
METHOD="CreateDeliveryVerification"
: "${IC_CLIENT_SVC:=relay.worker.shoppers.shoppers}"

# --- Order under test (PROVISION FIRST: ./provision.sh) ---
# The attended-delivery order_delivery_id whose dropoff you are verifying.
# Provision a fresh order per run — a passing photo case creates a row, so replaying
# on the same odid hits the idempotent "already recorded" skip.
# Last PASSED photo runs (2026-08-07, T5 #843586 live on staging):
#   G1-CDV-04/05: ORDER_DELIVERY_ID=20829590130517604 (photo row 110925449)
#   G1-CDV-15:    ORDER_DELIVERY_ID=20829614511444524 (photo row 110925452)
: "${ORDER_DELIVERY_ID:=__SET_ORDER_DELIVERY_ID__}"

# --- Image fixtures (real https URLs; staging runs real SSRF-filtered download) ---
# Allow-list: https only, content-type image/png|jpeg|jpg, <=20MB.
: "${IMG_PNG:=https://www.gstatic.com/webp/gallery3/1.png}"      # VERIFIED image/png 200 (happy path)
: "${IMG_PNG2:=https://www.gstatic.com/webp/gallery3/2.png}"     # 2nd url for multi-photo case
: "${IMG_JPEG:=https://httpbin.org/image/jpeg}"                  # VERIFIED image/jpeg 200 (G1-CDV-13)
: "${IMG_4XX:=https://httpbin.org/status/404}"                   # returns 404 -> log-and-skip, no retry (G1-CDV-24)
: "${IMG_5XX:=https://httpbin.org/status/500}"                   # returns 500 -> re-raise -> Sidekiq retry (G1-CDV-25/30)
: "${IMG_TOOLARGE:=__SET_HTTPS_IMAGE_OVER_20MB_URL__}"           # >20MB png/jpeg (G1-CDV-26) — NO reachable fixture found
: "${IMG_GIF:=https://media.giphy.com/media/3o7TKr3nzbh5WgCFxe/giphy.gif}"  # VERIFIED image/gif 200 -> unsupported (G1-CDV-27)
: "${IMG_SSRF:=http://www.gstatic.com/webp/gallery3/1.png}"      # http:// (non-https) -> scheme block (G1-CDV-28)
