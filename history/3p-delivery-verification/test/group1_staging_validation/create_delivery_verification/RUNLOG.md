# RUNLOG — Group 1 staging validation: CreateDeliveryVerification (signature)

Source of truth for this vehicle. Group 1 = call the **deployed staging** DeliveryVerificationService directly with an out-of-process client, **no FPS**, verify out-of-band. Do NOT touch FPS/Packages (sibling agents own those).

Last updated: 2026-08-07 (photo re-test after T5 fix — see PHOTO RE-TEST section below). Prior: 2026-08-05 ~21:50Z (team-lead consolidation).

## STATUS (updated 2026-08-07): 25 PASS / 7 deferred-RSpec-tier / 2 reclassified→Group 2 = 34 total. Zero unknown-blocked. (Was 22/10/2 on 2026-08-05; photo cases 04/05/15 flipped BLOCKED→PASS after the T5 fix #843586 deployed to staging.)

Consolidated from three per-agent RUNLOGs (all against **deployed staging**, no FPS). `cases.tsv` is now the merged source of truth.
- **This file (signature/photo):** §1.2 base matrix → 18 PASS; photo happy-path 04/05/15/16 was proven not curl-expressible on 2026-08-05 (worker-context photo persistence raised → RELAY-919) → RSpec-tier. **UPDATE 2026-08-07: 04/05/15 now PASS live on staging after the T5 fix (#843586) deployed — see PHOTO RE-TEST section below.** See "Full matrix run" below.
- **`RUNLOG_certified_delivery.md` (08/09/11/22):** unblocked via `generate_order customer_handoff_pin` recipe + `GetPinExchangeCertifiedDelivery` read RPC. **08/09/22 PASS**; **11 → RSpec-tier** (off-nominal shape unprovisionable). Code proof: `FulfillmentCertifiedDeliveryService#transition:18` is an unguarded `update!` → PIN completes cert from `awaiting_arrival`.
- **`RUNLOG_fixtures.md` (26/32/33):** **26 PASS** (40MB Wikimedia JPEG; DD `image_download.count{kind:signature,error_type:too_large}=1` @21:04Z, confirmed by team-lead); **32/33 → reclassified Group 2** (the `missing_required_verification` metric is emitted only by the FPS Go wrapper, not the shoppers RPC Group 1 targets — one metric with `kind∈{signature,id_verification,pin,package}`, `step∈{pickup,dropoff}`).

### Final dispositions (updated 2026-08-07)
- **PASS (25):** 01,02,03,04,05,06,07,08,09,10,12,13,14,15,17,19,21,22,24,25,26,27,28,29,34  *(04/05/15 added 2026-08-07 — photo happy-path, live after T5 #843586 deployed to staging)*
- **Deferred → RSpec/local tier (7):** 16 (combined all-types — photo aspect now PASS via 04, but blocked on bag seeding for the package-scan step, same limitation as G2-3, NOT on T5), 11 (off-nominal cert shape), 18,20,23 (concurrency/job-rerun), 30 (retry-exhaustion), 31 (Hub-publish-swallow; the RELAY-919 fix adds adjacent per-step-isolation specs)
- **Reclassified → Group 2 / FPS-tier (2):** 32,33
- **Findings:** #1 500-not-400 asymmetry (01/02); #2 `non_https` scheme-guard vs private-IP SSRF (28); #3 photo per-step-isolation → RELAY-919 (the abort-cascade; the underlying photo *upload* crash is the T5 #843586 filename bug, now fixed + verified live — see PHOTO RE-TEST); graceful `no_address_id` (29) vs raise path.

---

## PHOTO RE-TEST (2026-08-07) — T5 fix #843586 confirmed DEPLOYED + WORKING on staging

Re-ran the photo happy-path cases (04/05/15) against **deployed staging** (curl → `CreateDeliveryVerification`, fresh DevGen orders via `provision.sh`). The **T5 fix** — "attach original_filename to downloaded IO" (**#843586**, commit `eb6c0298398db`, verified ancestor of `origin/master`) — is **live**: the pre-fix crash (filename-less StringIO → CarrierWave `store!` → `TypeError: no implicit conversion of nil into String`) no longer occurs, and the persisted `delivery_photo` now carries the `.png` key the fix's `original_filename` ("photo.png") produces. Metric `custom.fulfillment.delivery.delivery_verification.proof_of_delivery_photo_persistence.count{env:staging}` — NO DATA for 30d pre-fix — now fires `success:true`.

| Case | Prev (2026-08-05) | New (2026-08-07) | odid | photo row id | delivery_photo | created_at |
|---|---|---|---|---|---|---|
| G1-CDV-04 | BLOCKED (TypeError) | **PASS (live)** | 20829590130517604 | 110925449 | fc405e82-9a00-4d37-8433-af55e24a9b45.png | 19:58:33Z |
| G1-CDV-05 | BLOCKED | **PASS (live)** — address_id resolved (20829587759211076), same run as 04 | 20829590130517604 | 110925449 | (as 04) | 19:58:33Z |
| G1-CDV-15 | BLOCKED (row half) | **PASS (live)** — exactly ONE row (first url used); >1-url warn log-only | 20829614511444524 | 110925452 | 8e9e25b2-9532-434b-b11c-88351939bae5.png | 20:02:37Z |

- DD metric: `success:true` @19:58:30Z (CDV-04) and @20:02:30Z (CDV-15); only datapoints over 4h, zero failures.
- Verified via Blazer `shoppers_staging.shopper_order_delivery_photos` (columns id, order_delivery_id, address_id, delivery_photo, created_at).
- Test data (reproducible): order A user 20829587672215552 / order 20829590130511896 / address 20829587924512340; order B user 20829612578215924 / order 20829614511453680 / address 20829612822456556.
- Logs: WittyCart/Quickwit (OAuth-gated this session) holds the new post-fix INFO log_ids `a1f3c7d9e024`/`6b8e2d4f0c17`/`9c4a1e7b3d52`; not indexed in Datadog. Metric + DB rows are conclusive without them.
- G1-CDV-16 unchanged: photo aspect now covered by 04; combined case blocked only on bag seeding (G2-3 limitation), not T5.

---

## Transport / endpoint / auth — RESOLVED

- **Transport: Pumpkin RPC over HTTP (Twirp-style POST), NOT gRPC/HTTP2.** grpcurl cannot call it. Correct client = `curl`.
  - Call shape: `POST <BASE>/rpc/<fullServiceName>/<Method>`, `Content-Type: application/json`, proto3-JSON body (camelCase fields).
  - Health: `GET <BASE>/monitors/health` → 200.
- **BASE URL (WORKED): `https://rpc-shoppers-shoppers-stg.instacart.team`** (shoppers monolith RPC). DevGen: `https://devgen-rpc-shoppers-shoppers-stg.instacart.team`.
- **Auth: none / no bearer token.** VPN + mesh placement only. Headers sent (all unauthenticated, none are secrets): `Content-Type`, `ic-client-svc: relay.worker.shoppers.shoppers`, `ic-request-id: <generated>`. No token/cert pasted anywhere.
- How resolved: endpoint known from `shoppers/shoppers/engines/api/docs/staging-verification/README.md`; confirmed reachable (health 200, read 200, write 200). tf-instacart was suggested as a reference for resolving addresses but was NOT needed — the `rpc-shoppers-shoppers-stg` host resolves and works directly. Keep tf-instacart as the fallback reference if mesh routing changes.
- Method shapes (from `shared/protos/instacart/fulfillment/delivery/delivery_verification/v1/delivery_verification.proto`):
  - `CreateDeliveryVerification` (write): `{orderDeliveryId, source, pickupVerification, dropoffVerification}`. `dropoffVerification.signature.imageUrl` is the signature field.
  - `GetVerificationRequirements` (read): `{orderDeliveryId}` → `{dropoff:{signature,idVerification,pin}}`.
  - `source` enum: `VERIFICATION_SOURCE_FULFILLMENT_PROVIDER`.

## Async model
CreateDeliveryVerification handler validates synchronously, base64-encodes the proto, enqueues `CreateDeliveryVerificationJob` (Sidekiq on worker.shoppers.shoppers), returns `{}`. Persistence is async → **wait ~25-30s before verifying**. Job dispatch order: packages→photo→id→pin→signature. Idempotent (pre-check + double-checked TaskLock). RETRY_COUNT=3.

---

## Blockers hit and how they were unblocked

- **grpcurl assumption (FAILED)** → wrong transport. Switched to curl (see above). This is the core doc-framing correction.
- **devgen-mcp-v2-staging MCP: 401 OAuth (FAILED early)** → initially bypassed by driving DevGen via curl. **Later RECONNECTED by user** → now using MCP `run_script` (preferred path).
- **log-nexus-wittycart MCP: 401 OAuth (FAILED)** → unavailable; relied on Blazer for authoritative DB verification instead.
- **Blazer `orders_staging` "relation order_delivery_properties does not exist" (FAILED)** → root cause: `OrderDeliveryProperties < ShoppersRecord` lives in the **shoppers DB**, not orders. Fix: query data source **`shoppers_staging`** (WORKED).
- **Datadog metric NO DATA (FAILED, then RESOLVED)** → root cause: ICMetrics→Datadog pipeline prefixes metrics with **`custom.`**. Query `custom.fulfillment.delivery.delivery_verification.signature_persistence.count` (not the bare name). WORKED.
- **Candidate signature PNGs (FAILED): instacart.com carrot logo 403, cloudfront 400** → used `https://www.gstatic.com/webp/gallery3/1.png` (image/png, ~113KB, 200). WORKED.

---

## DevGen provisioning — recipe (WORKED)

Script (top-level `commands:`; `$var` references prior outputs):
```yaml
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
```
- Via MCP: `mcp__devgen-mcp-v2-staging__run_script{yaml: <above>}`.
- Via curl (fallback): `POST <DEVGEN_URL>/rpc/instacart.dev_gen.v1.DevGenService/RunScript` body `{"user_id":0,"script_yaml":"<yaml>"}`.
- `items_nothing: 3` avoids NoItemsFound (generates an order with 3 placeholder items). No NoItemsFound errors seen with this recipe.
- Saved as `provision.sh` (curl form).

### Provisioned orders
| when | order_delivery_id | order_id | user_id | via | result |
|---|---|---|---|---|---|
| 20:11Z | 20812380692494380 | 20812380692488180 | 20812378713214080 | DevGen curl | PASS |
| 20:22Z | 20812454307471548 | 20812454307460920 | 20812452048214400 | DevGen MCP run_script | PASS |

---

## Runs

### Run A (order 20812380692494380) — happy + idempotency
- Write: `CreateDeliveryVerification` dropoff.signature.imageUrl=gstatic 1.png → 200 `{}` at 20:11:08Z.
- Blazer `shoppers_staging`: `customer_signature = 594281023-776130f3e1d2810c45e3bccc1c11fa6fbe14155e0c298dc61b0bea16cbbc1ad2.png` (content-addressed `<odp.id>-<sha256>.png`; `.png` = content-type preserved). updated_at 20:11:08.
- Datadog: `custom....signature_persistence.count{success:true}`=1, `custom....image_download.count{kind:signature,success:true}`=1 at 20:11.
- **Idempotency (G1-CDV-17/19)**: replayed identical request twice (20:14, 20:20). Row byte-identical (updated_at unchanged 20:11:08.917783, same filename, no new row); DD metric stayed at 1 (no 2nd emission). Confirms pre-check/double-checked-lock skip. PASS.
- Also validated the runner live: `G1-CDV-01` (→ InvalidArgument, see finding below) and `G1-CDV-12` (→ 200, idempotent skip).

### Run B (order 20812454307471548) — fresh reproduction w/ MCP + read path
- Provisioned via DevGen **MCP** run_script.
- Health `GET /monitors/health` → 200.
- **GetVerificationRequirements** read → 200 `{"dropoff":{"signature":{},"idVerification":{},"pin":{}}}` (empty requirement shell — DevGen order isn't certified-delivery; read path itself confirmed).
- Write signature (gstatic 1.png) → 200 `{}` at 20:22:46Z.
- Blazer: new row id 594281028, `customer_signature = 594281028-776130f3e1d2810c45e3bccc1c11fa6fbe14155e0c298dc61b0bea16cbbc1ad2.png`, updated_at 20:22:46. **Same sha256 as Run A** → content hash is deterministic on source bytes; only `<odp.id>` prefix differs.
- Datadog: `signature_persistence.count{success:true}` and `image_download.count{kind:signature,success:true}` each fired fresh `1` at 20:22. (Also saw `kind:proof_of_delivery_photo,success:true` from sibling agent — per-kind tagging works.)

---

## Full matrix run (2026-08-05 ~20:30–20:45Z)

Ran every curl-expressible §1.2 case against deployed staging. Orders provisioned via DevGen MCP `run_script`:

| tag | order_delivery_id | used for |
|---|---|---|
| O1 | 20812510962408360 | signature PNG (12/17/19) |
| O2 | 20812514015471600 | id verified=true (06/21) |
| O3 | 20812516780429720 | photo attempts + decisive photo+sig abort test |
| O4 | 20812519259408372 | full-dropoff attempts, then sig-only/id-only isolation |
| O5 | 20812522614408376 | signature JPEG (13) |
| O6 | 20812525206471608 | photo attempts |
| O7 | 20812527550501492 | shared non-persisting: 02/03/07/09/10/14/24/25/27/28 |

**Counts: 18 PASS / 5 deferred-RSpec / 11 blocked (34 total).** Full per-case disposition + evidence is in `cases.tsv` (RESULT, EVIDENCE columns).

- PASS (18): 01, 02, 03, 06, 07, 10, 12, 13, 14, 17, 19, 21, 24, 25, 27, 28, 29, 34
- DEFERRED — RSpec/local tier (5): 18, 20, 23, 30, 31
- BLOCKED — provisioning/fixture (11): 04, 05, 15, 16 (photo, see FINDING #3), 08, 11, 22 (no DevGen certified-delivery recipe), 09 (CD pre-state), 26 (no >20MB fixture), 32, 33 (requirements/recorded-packages pre-state)

### Image-download taxonomy (all via O7, DD `image_download.count{success:false}`)
- 4xx (404): `error_type:http_client_error`, single (no Sidekiq retry). [24]
- 5xx (500): `error_type:http_error`, ×3 (Sidekiq retried). [25]
- gif: `error_type:unsupported_content_type`. [27]
- http:// scheme: `error_type:non_https`. [28]

### Idempotency
- Signature replay (O1): row byte-identical, updated_at unchanged, single row, DD count not re-emitted. [17/19]
- ID replay (O2): single id row, no dup. [21]

### Photo-step abort — root-caused (5 whys)
- Symptom: full-dropoff (16) and photo+signature both persisted NOTHING, even though signature-only ✓ and id-only ✓ on the SAME order (O4, both at 20:40:21).
- Decisive test: photo+signature on O3 → Blazer `order_delivery_properties` empty → signature did NOT persist.
- Why: `create_delivery_verification_job.rb` dispatches packages→photo→id→pin→signature (lines 55-59) with NO per-step rescue in `perform`/`dispatch_dropoff`.
- Why: `proof_of_delivery_photo_persistence_service.rb` top-level rescue **re-raises** (line 102) after logging + `ICMetrics.increment(METRIC_NAME, success:false)` — the ONE service in the chain that does not gracefully degrade on unexpected errors (id/pin/signature all swallow).
- Why the photo step raises for my orders: `fetch_address_id` (line 108-113) calls `RPC::Orders::OrderHandlingDetails.get`; DevGen-provisioned orders have no handling details, so the RPC raises (NOT a blank return). The graceful `no_address_id` path (line 33-41, returns) only fires when the RPC succeeds but `delivery.address_id` is blank.
- Consequence: a photo-step exception aborts id/pin/signature dispatched after it → job retries 3× → `retry_exhausted`. `bulk_update_packages` (line 86 `raise response.error`) has the same abort effect from the packages step. So photo and packages are the two non-graceful, job-aborting steps, and both precede signature in dispatch order.

## Photo happy-path chase (G1-CDV-04/05/15/16) — 2026-08-05 ~20:50Z+

Goal: unblock the photo cases with a **photo-capable order** (one whose `OrderHandlingDetails.delivery.address_id` resolves), then verify row + Hub event + `image_download.count{success:true}`.

### Mechanism confirmed in code (refines RELAY-919)
- `shared/shoppers-shared/app/models/rpc/orders/order_handling_details.rb:27-35` — `OrderHandlingDetails.get` **raises `response.error` unless `response.code == :ok` (line 32)**. For a plain `generate_order` (items_nothing, no batch, no unattended flag) the Orders service returns non-ok → RAISES → photo persistence re-raises (`proof_of_delivery_photo_persistence_service.rb:102`) → aborts id/pin/signature. This is the RELAY-919 abort, root-caused to the Orders RPC returning non-ok, not a blank address. The graceful `no_address_id` path (returns) only fires when the RPC returns ok but `delivery.address_id` is blank (`handling_details&.delivery&.address_id`).
- Photo/POD is the **unattended-delivery** case: `unattended_delivery?` = `special_requirements.include?(:UNATTENDED_DELIVERY)`.

### Photo-capable recipe FOUND (DevGen)
`search_recipes "delivery photo"` → **"QA: Delivery photo coordinates"** (uuid `8e0301bb-1bdb-4448-b39e-ef86d7856437`): "Creates a batch with multiple unattended deliveries for testing photo with coordinate upload." Key knobs vs my earlier recipe:
- `generate_order` with **`is_unattended: true`** (the crucial flag).
- Builds a driver, links user, `generate_batch` (warehouse_location_id 53 = Safeway SF), `next_batch_state target_state: "delivering"`.
Relevant commands also available: `GenerateDeliveryAddressDetails` (delivery_ids + lat/lon → DeliveryAddressDetails), `GenerateDeliveryOption`.

### MCP bridge degraded then recovered (2026-08-05 ~20:47–21:35Z)
- DevGen/Blazer/glean MCP all timed out simultaneously ~20:47–21:34; direct staging RPC curl health stayed 200/0.13s (network fine, MCP bridge was the degraded layer). Recovered ~21:35.

### RESULT: photo happy-path is NOT achievable via curl-on-staging (RELAY-919 is reference-resolution, not order-shape)

Provisioned progressively richer photo-capable orders and tested each:
| order | shape | photo-only | photo+sig | sig-only |
|---|---|---|---|---|
| O8 = 20812895690448704 | is_unattended, no batch | no row | sig NOT persisted (photo raised) | — |
| O9 = 20812920709494924 | is_unattended + batch (whl 53) advanced to completed | no row | sig NOT persisted (photo raised) | **PERSISTED** 594281057-776130f3...png @21:43:51 |

O9 is a healthy order (sig-only works), yet photo-only creates no `shopper_order_delivery_photos` row and photo+sig aborts the signature → **the photo step raises even on a fully-provisioned unattended + batched delivery.** Order shape does NOT fix it.

**Why (5 whys, code-confirmed):** `proof_of_delivery_photo_persistence_service.rb:108-112 fetch_address_id` → `OrderHandlingDetails.get(order_delivery_id:)` with **no `user_id`** → `order_handling_details.rb:32 raise unless code==:ok` → the reference lookup `application_proto_model.rb:14-38 get_order_reference` with `user_id: nil` relies on `get_shard_key` (`MultiTenant.current_tenant_id`, nil in the Sidekiq worker) then `OrderDetails.user_id_by_id`; when the Orders RPC returns non-ok it `raise response.error` (line 33) / `raise "Could not get order_reference"` (line 35). So the raise is driven by **order-reference resolution in the worker context**, which is lifecycle-independent — advancing the batch to delivering/completed cannot change it. The DevGen "QA: Delivery photo coordinates" recipe makes orders photo-capable for the **driver-app** upload path (`Api::OrderDeliveryPhotos::PhotoUploadedPushService`, which passes user context), NOT for the DeliveryVerification async job that omits user_id. **This IS the RELAY-919 repro, now reproduced on properly-provisioned unattended orders — strengthens the ticket.**

**Disposition:** G1-CDV-04/05/15/16 remain BLOCKED via curl-on-staging. They belong in **RSpec** (Group 1 is now RSpec per the updated test-cases doc), where `OrderHandlingDetails`/`OrderDetails` are stubbable so the address resolves and the photo persistence + Hub-event + `image_download{success:true,kind:proof_of_delivery_photo}` can be asserted. No further staging-provisioning variant will unblock these.

### Photo-capable recipe (documented for reuse / driver-flow tests)
"QA: Delivery photo coordinates" (uuid 8e0301bb-1bdb-4448-b39e-ef86d7856437). Chunk it (MCP times out on the full script): (1) create_driver + create_user + change_driver_role[full_service,tester,developer] + link_user; (2) generate_order is_unattended:true (user_id literal); (3) generate_batch (delivery_ids literal, warehouse_location_id:53, driver_id literal); (4) next_batch_state target_state:"delivering" (jumps to completed). `enable_flipper` is deprecated/no-op in shoppers now.

## Verification queries (reusable)

- **Blazer** (data source `shoppers_staging`; requires a time filter, use `{blazer_now}` not now()):
  ```sql
  SELECT id, order_delivery_id, customer_signature, created_at, updated_at
  FROM order_delivery_properties
  WHERE order_delivery_id = <ODID>
    AND updated_at >= {blazer_now} - interval '30 minutes'
  ```
- **Datadog** (note `custom.` prefix): `sum:custom.fulfillment.delivery.delivery_verification.signature_persistence.count{*} by {success}.as_count()` and `...image_download.count{*} by {success,kind}.as_count()`.
- **Read RPC**: `POST /rpc/<svc>/GetVerificationRequirements` body `{"orderDeliveryId": <ODID>}`.
- rails console not used — Blazer hits the same shoppers DB and is authoritative.

---

## Findings to propagate

1. **Validation over the HTTP adapter (G1-CDV-01/02)**: `GRPC::InvalidArgument` does NOT return HTTP 400. Observed: **HTTP 500** body `{"code":"internal","msg":"3:order_delivery_id is required","meta":{"error_class":"GRPC::InvalidArgument", ...}}`. gRPC code `3`=INVALID_ARGUMENT is preserved in the msg prefix; Pumpkin HTTP adapter wraps as `internal`. Validation fires correctly at `delivery_verification_service.rb:101`. Group 2 (FPS, real gRPC) should assert the gRPC status, not HTTP 400. cases.tsv updated to reflect observed behavior.
2. **Doc-framing correction** for §1 Group 1: it is deployed-staging **curl** (Pumpkin HTTP), no FPS, heavy-permutation tier for §1.2; RSpec is a **separate local tier** for concurrency/fault-injection cases (G1-CDV-18/20/23/31). Wording sent to team-lead.
3. **Photo (proof_of_delivery_photo) persistence re-raises + no per-step isolation (G1-CDV-04/05/15/16)**: `proof_of_delivery_photo_persistence_service.rb:102` re-raises on unexpected `StandardError` (unlike id/pin/signature which swallow), and `create_delivery_verification_job.rb` dispatches packages→photo→id→pin→signature with no per-step rescue. So a photo-step (or packages-step, `job.rb:86`) exception aborts every verification type dispatched after it and drives the job to `retry_exhausted`. For a *permanently*-failing photo (e.g. address resolution error), signature/id for that delivery never persist. The re-raise is intentional for transient-5xx retry, but its blast radius spans co-located verification types. Worth a doc note + possibly per-step isolation. NOTE: this also means photo happy-path cannot be validated on DevGen-provisioned orders (they have no `OrderHandlingDetails` → `fetch_address_id` raises); needs a photo-capable order (Packages/photo sibling domain).
4. **`error_type:non_https` vs "SSRF" (G1-CDV-28)**: an `http://` URL is rejected by the **scheme guard** with `error_type:non_https`, not the private-IP SSRF filter. The doc's "SSRF-blocked / private IP" framing conflates two distinct guards; the private-IP path would need a URL resolving to a private/link-local address to exercise separately.

---

## Deliverables (this dir)
- `run.sh` — runner (`./run.sh <CASE_ID> [--replay]` | `--list`). Substitutes `__ORDER_DELIVERY_ID__`/`__IMG_*__` from env.sh. Live-validated.
- `env.sh` — BASE_URL, ORDER_DELIVERY_ID, image fixtures (real ones filled; `__SET_...__` = needs a real asset: IMG_JPEG, IMG_TOOLARGE>20MB, IMG_GIF).
- `provision.sh` — DevGen provisioning (curl form).
- `cases.tsv` — G1-CDV-01…34 matrix: prio, curl?/method, pre-state/fixture, expected, verify-out-of-band. Marks the 5 non-curl (RSpec-tier) cases.
- `requests/` — 30 proto3-JSON request templates.

## Open questions / next step if interrupted
- Full §1.2 matrix is DONE (18 PASS / 5 deferred-RSpec / 11 blocked). Results in cases.tsv + "Full matrix run" above.
- To unblock the 11: (a) photo cases 04/05/15/16/29-raise-path need an order whose `OrderHandlingDetails.delivery.address_id` resolves — Packages/photo sibling domain; (b) 08/09/11/22 need a certified-delivery pre-state (no DevGen recipe); (c) 26 needs a reachable >20MB https image/png|jpeg; (d) 32/33 need requirements / recorded-packages pre-state.
- The 5 deferred (18/20/23/30/31) are RSpec/local-tier (concurrency/fault-injection/retry-exhaustion), not single-curl.
- FINDINGS #1–#4 to propagate to Group 2 (FPS) and the doc owner.
