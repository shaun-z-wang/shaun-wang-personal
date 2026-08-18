# RUNLOG — Group 1 staging validation: GetVerificationRequirements (READ)

Source of truth for this vehicle. Group 1 = call the **deployed staging**
`DeliveryVerificationService.GetVerificationRequirements` directly with an
out-of-process client (**curl**, Pumpkin/Twirp over HTTP POST — NOT gRPC), **no
FPS**. This RPC is a **READ** (no writes, no Sidekiq): the RPC response body is
the assertion. NOT_FOUND is cross-checked via a Datadog metric.

Last run: 2026-08-05 ~23:17Z.

## STATUS: 10 PASS (live on staging) / 1 PASS-with-FINDING / 4 author-only (RSpec or Group-2/driver-context)

- **Live PASS (10):** GVR-01, 02, 03, 05, 07, 09, 10, 11, 12, 15
- **Live PASS + FINDING (1):** GVR-ZERO (orderDeliveryId=0 -> NOT_FOUND, **not** InvalidArgument)
- **Author-only (4):** GVR-04 (RSpec — max-age math), GVR-06 (needs driver+batch+flag),
  GVR-08 (needs restricted-taxonomy item fixture), GVR-13 (UNREACHABLE via this RPC -> RSpec/unit)
- **PASS-by-design (1, counted in the 10):** GVR-14 (flag-insensitive at this RPC)

Full per-case disposition + evidence: `cases.tsv` (RESULT, EVIDENCE columns).

---

## Method under test

- Service: `instacart.fulfillment.delivery.delivery_verification.v1.DeliveryVerificationService`, method `GetVerificationRequirements`. READ, SYNC (no Sidekiq).
- Call: `POST <BASE>/rpc/<fullServiceName>/GetVerificationRequirements`, `Content-Type: application/json`, body `{"orderDeliveryId":"<id>"}` (int64 as quoted string).
- Response: `{"dropoff":{"signature":{required},"idVerification":{required,minimumAge},"pin":{required,code}}}`. proto3-JSON **omits false bools and unset wrappers**, so "no requirement" renders as `{}`.
- Handler: `shoppers/shoppers/app/rpc/.../delivery_verification_service_handler.rb:14` -> `DeliveryDomain::PublicServices::DeliveryVerificationService#requirements` (coordinator) -> `OrderDeliverySpecialRequirementsService` (business rules).

## Transport / endpoint / auth (unchanged from sibling vehicles)

- **BASE: `https://rpc-shoppers-shoppers-stg.instacart.team`** (health `GET /monitors/health` -> 200). DevGen: `https://devgen-rpc-shoppers-shoppers-stg.instacart.team`.
- **Auth: none** (VPN/mesh placement only). Headers sent: `Content-Type`, `ic-client-svc: relay.worker.shoppers.shoppers`, `ic-request-id`. No secrets.

---

## DevGen provisioning — order shapes (all via `mcp__devgen-mcp-v2-staging__run_script`)

| tag | order_delivery_id | recipe knobs |
|---|---|---|
| MKT | 20812396763494404 | reused from replace_packages vehicle (marketplace, no special items) |
| ALC-US | 20813434056449244 | `generate_order alcoholic:true warehouse_ids:[1]` (Safeway US; delivery state CA) |
| ALC-CA | 20813459830409416 | Canada: `create_user country_id:124 warehouse_location_id:40601`, `copy_warehouse_location_address source:40601`, `generate_order alcoholic:true warehouse_ids:[354] warehouse_location_id:40601` (zone 693) |
| RX-ATT | 20813477676430844 | `create_user warehouse_location_id:2254`, `generate_rx_order rx_items:2 warehouse_id:5 warehouse_location_id:2254` (attended, no driver/batch) |
| RX-UN | 20813474031409464 | same as RX-ATT + `unattended:true` |
| PIN | 20813444285502584 | `generate_order items_nothing:3 customer_handoff_pin:"4823"` (creates pin_exchange certified_delivery) |

Notes:
- `generate_rx_order` default warehouse 456 has **no delivery options in the default user zone 1** -> use `warehouse_id:5 / warehouse_location_id:2254` (from recipe "1 delivery, rx") and `create_user warehouse_location_id:2254` so the address zone matches.
- DevGen MCP intermittently times out; the order is usually still created — re-run and pick the new id, or verify via Blazer.

---

## Live results (fresh capture 2026-08-05 23:16-23:17Z)

| Case | order | response | HTTP |
|---|---|---|---|
| GVR-01 | MKT | `{"dropoff":{"signature":{},"idVerification":{},"pin":{}}}` | 200 |
| GVR-02 | ALC-US | `{"signature":{},"idVerification":{"required":true,"minimumAge":"21"},"pin":{}}` | 200 |
| GVR-03 | ALC-CA | `{"signature":{},"idVerification":{"required":true,"minimumAge":"19"},"pin":{}}` | 200 |
| GVR-05 | RX-ATT | `{"signature":{"required":true},"idVerification":{"required":true,"minimumAge":"18"},"pin":{}}` | 200 |
| GVR-07 | RX-UN | `{"signature":{"required":true},"idVerification":{"required":true,"minimumAge":"18"},"pin":{}}` | 200 |
| GVR-09 | PIN | `{"signature":{},"idVerification":{},"pin":{"required":true,"code":"4823"}}` | 200 |
| GVR-10 | MKT | `idVerification:{}` (minimumAge omitted when not required) | 200 |
| GVR-11 | nonexistent | `{"code":"not_found","msg":"NotFoundError"}` | 404 |
| GVR-12 | nonexistent | `{"code":"not_found","msg":"NotFoundError"}` | 404 |
| GVR-15 | ALC-US | signature=false (CA excluded from flag allowlist) | 200 |
| GVR-ZERO | 0 | `{"code":"not_found","msg":"NotFoundError"}` | 404 |

**Out-of-band:** `sum:custom.delivery_verification_service.rpc_order_details_not_found{*}.as_count()` = **3** at the 23:16:50Z bucket — exactly the three not-found calls (GVR-11, GVR-12, GVR-ZERO). Confirms the metric (coordinator:56) fires on every OrderDetails-not-found, including id=0.

**Roulette (GVR-15):** `retailers_alcohol_signature_by_state` (v14) is state-gated. `checkEvaluation` state `WA` -> `matchReason: ruleset` (enabled -> signature required); state `CA` -> `matchReason: no_match` (disabled). Allowlist: TN,MA,GA,MN,MS,LA,AZ,WA,VA,OR,HI,IL,AL,CT,IA,KY,NJ,NV. The ALC-US order (state CA) returning `signature=false` matches. To observe `signature.required=true` for alcohol, provision an order delivering to a listed state.

---

## Findings (propagate to the doc owner / Group 2)

1. **orderDeliveryId=0 -> NOT_FOUND, NOT InvalidArgument (GVR-ZERO).** The READ path has **no id>0 validation** — unlike `CreateDeliveryVerification`, whose coordinator `validate_create!` rejects id<=0 with `GRPC::InvalidArgument` (delivery_verification_service.rb:101). `#requirements` goes straight to `fetch_order_details` -> `OrderDetails.get(0)` -> `Pumpkin::RPC::NotFoundError` -> HTTP 404 `not_found` + `rpc_order_details_not_found` metric. The task's seed assumption ("0 -> InvalidArgument") mirrors the write RPC and is wrong for the read RPC.
2. **GVR-13 is UNREACHABLE via this RPC.** The coordinator always builds `OrderDeliverySpecialRequirementsService.new(order_details: fetch_order_details)` (coordinator:28), so `order_details` is never nil (a missing order raises NOT_FOUND first). The `ArgumentError` "must specify order_details when flag enabled" guard (svc.rb:29-34) only protects callers that pass `order_delivery:` instead. Reclassify to RSpec/unit.
3. **GVR-14 is flag-insensitive at this RPC.** Because `order_details` is always supplied, every predicate takes the `order_details.present?` branch regardless of `shopper_delivery_special_requirements_require_order_details`. The read path cannot exercise the `order_delivery`-only branch; toggling the flag changes nothing observable here.
4. **RX signature without a driver defaults to required (GVR-05/07).** `require_rx_signature?` (svc.rb:184) `return true unless driver.present?`. Pre-batch Group-1 orders have no driver, so RX -> signature required and the attended/unattended distinction collapses (unattended_rx flag needs a shopper_id from a batch, svc.rb:451-462). True unattended-RX-skip (GVR-06) and the pure attended-vs-unattended contrast need a driver+batch -> Group 2 / RSpec.
5. **Proto3-JSON omits false/unset.** "No requirement" is `{}`, not `{"required":false}`. Assert on presence, not on an explicit false. (Applies to Group 2 gRPC decoders that may materialize the false.)

---

## Reproduce

```bash
cd /home/bento/group1_staging_validation/get_verification_requirements
./run_case.sh --all      # every curl-expressible case
./run_case.sh G1-GVR-02  # one case
./run_case.sh --list     # case matrix
```

## Deliverables (this dir)
- `run_case.sh` — runner (`<CASE_ID>` | `--all` | `--list`); case->order_delivery_id map inline.
- `env.sh` — BASE_URL, SERVICE/METHOD, provisioned `ODID_*` order ids.
- `requests/` — one proto3-JSON body per curl-expressible case.
- `cases.tsv` — G1-GVR-01..15 (+ GVR-ZERO) matrix: prio, curl?, pre-state, expected, verify, result, evidence.
- `RUNLOG.md` — this file.
