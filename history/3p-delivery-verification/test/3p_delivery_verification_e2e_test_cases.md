# 3P Delivery & Package Verification — Test Record

**Scope.** End-to-end and RPC-level test coverage for the third-party (3P) delivery-verification pipeline:
3P-picking package capture, pickup/dropoff verification (ID, PIN, signature, proof-of-delivery photo, package
barcode scans), and the reconcile backstop.

**Status of this document.** This is the polished record of what has actually been tested. It reflects two
things exactly as they stand:

- **Group 1** — the RPC-level staging validation under `/home/bento/group1_staging_validation/` (one folder per
  RPC method, each with `cases.md` / `cases.tsv` / `RUNLOG.md`). That folder is the source of truth for Group 1;
  the dispositions below mirror it.
- **Group 2** — the Go integration-test suites actually coded and registered in
  `/home/bento/carrot/fulfillment/fulfillment_provider_service/cmd/integration_tests`. The Group 2 section below
  describes only what is coded and registered in `main.go` — nothing aspirational.

**Sources originally merged:** RELAY-573 (bag verification), RELAY-574 (delivery verification),
ERD *3P Picking Delivery Package Info* (RELAY-493), ERD *3P Delivery Pickup/Dropoff Verification*.

---

## 1. The two test groups

| | Group 1 — RPC integration | Group 2 — end-to-end (with FPS) |
|---|---|---|
| **What drives it** | The test is the caller. It invokes the shoppers-monolith RPCs directly; FPS is **not** in the loop. | FPS is in the loop. The Go harness simulates the partner (inbound webhooks via FPT) and/or triggers the outbound path, then reads back what landed. |
| **Purpose** | Exhaustive input permutations — one field at a time, every enum, every validation/error branch. | A small set of representative scenarios that confirm end-to-end wiring where the response / payload / persistence path is materially different. Group 2 does **not** re-permute inputs. |
| **Vehicle** | `curl` against deployed staging (Pumpkin RPC over HTTP, Twirp-style — **not** grpcurl). Orders provisioned via DevGen; verified out-of-band via read RPCs / Blazer (`shoppers_staging`) / Datadog. | The Go `cmd/integration_tests` harness: real FPS over gRPC (spice), DevGen for order provisioning, FPT for partner simulation, direct shoppers-DB reads for assertions. |
| **Location** | `/home/bento/group1_staging_validation/` | `.../fulfillment_provider_service/cmd/integration_tests/` |

**Group 1 has a second, complementary local tier (1a).** The shoppers RSpec request/handler specs are hermetic and
**staging-incapable by design** (`rails_helper.rb` forces `RAILS_ENV=test` and refuses a set `DATABASE_URL`;
`test_env_guard.rb` raises on any non-local DB/RPC URL; `spec_helper.rb` disables net connect; `before(:suite)`
drops+recreates every Dynamo table). They cover concurrency, job-retry, and fault-injection cases that curl cannot
express. Where a Group 1 case is marked **RSpec-tier**, that is the reason.

---

## 2. System overview (pipeline under test)

```
                        ┌──────────────────────── FPS (Go / Temporal) ────────────────────────┐
3P Picking provider ──► picking_ready_for_pickup ──► ReplacePackages ─────► bags table
                                                        (PackagesService, shoppers)
Submit to 3P delivery ◄── BulkGetPackages ◄── GetVerificationRequirements ◄── OrderDetails RPC
                                                        (DeliveryVerificationService, shoppers)
3P Delivery provider ──► delivery_pickup_completed ─┐
                     ──► delivery_completed ────────┼─► CreateDeliveryVerification (RPC)
                                                    │      └► CreateDeliveryVerificationJob (Sidekiq, async, idempotent)
                                                    │           ├─ packages           → BulkUpdatePackages (found_at / verified_at)
                                                    │           ├─ proof_of_delivery   → ShopperOrderDeliveryPhoto
                                                    │           ├─ id_verification     → OrderDeliveryIdentification
                                                    │           ├─ pin                 → CertifiedDelivery → COMPLETED
                                                    │           └─ signature           → OrderDeliveryProperties.customer_signature
                     ReconcileDeliveryWorkflow ─────┘  (backstop: Get Delivery → same save path when the webhook is missed)
```

**FPS inbound happy-path lifecycle** (`partner.HappyPath` in `cmd/integration_tests/partner/events.go`):

```
SubmitBatch → [submitted]
 → delivery_acknowledged     [acknowledged]
 → driver_assigned           [driver_assigned]
 → driver_driving_to_store   [driving_to_store]
 → driver_arriving_at_pickup [at_pickup]
 → delivery_pickup_completed [picked_up]
 → delivering                [delivering]
 → delivery_completed        [delivered]
```
(`delivery_canceled` → `[canceled]` exists but is off the happy path.)

**RPC contract** — `DeliveryVerificationService` (`instacart.fulfillment.delivery.delivery_verification.v1`):
- `GetVerificationRequirements(order_delivery_id)` — read path (what the driver must verify).
- `CreateDeliveryVerification(order_delivery_id, source, pickup, dropoff)` — write path, **idempotent**. Response is an
  empty `CreateDeliveryVerificationResponse`.

**Key code references:**

| Component | Path |
|---|---|
| DeliveryVerification proto | `shared/protos/instacart/fulfillment/delivery/delivery_verification/v1/delivery_verification.proto` |
| DeliveryVerification RPC handler | `shoppers/shoppers/app/rpc/instacart/fulfillment/delivery/delivery_verification/v1/delivery_verification_service_handler.rb` |
| Requirements business rules | `shoppers/shoppers/app/services/order_delivery_special_requirements_service.rb` |
| Async persistence job | `shoppers/shoppers/domains/delivery_domain/app/domain/delivery_domain/jobs/delivery_verification/create_delivery_verification_job.rb` |
| Packages proto | `shared/protos/instacart/fulfillment/domains/packing/v1/packages.proto` |
| Packages RPC handler | `shoppers/shoppers/domains/packing_domain/app/domain/packing_domain/rpc/packages_service_handler.rb` |
| Bag data-store adapter | `shoppers/shoppers/domains/packing_domain/app/domain/packing_domain/services/data_store_adapters/bag_data_store_adapter.rb` |
| FPS delivery activities | `fulfillment/fulfillment_provider_service/internal/fulfillment_relay_service/job/temporal/activity/delivery_activities.go` |
| FPS pickup webhook | `.../service/webhook/process_partner_delivery_pickup_completed.go` |
| FPS dropoff webhook | `.../service/webhook/process_partner_delivery_completed.go` |
| FPS reconcile workflow | `.../job/temporal/workflow/reconcile_delivery_workflow.go` |
| **Group 2 harness** | `fulfillment/fulfillment_provider_service/cmd/integration_tests/` |

---

## 3. Legend

- **Pri** — P0 (critical/blocking), P1 (important), P2 (edge/nice-to-have).
- **Disposition:**
  - **PASS** — run live against deployed staging, expectation confirmed.
  - **PARTIAL** — behavior confirmed; one observable (a metric/log) could not be independently captured.
  - **FAIL** — run live, a real defect surfaced (recorded as a finding).
  - **RSpec-tier** — covered by the local hermetic RSpec tier; not curl-expressible on staging.
  - **FPS-enforced** — the validation lives in FPS before the RPC call, so it is not testable at the RPC layer;
    exercised in Group 2 / FPS unit tests instead.
  - **Won't-do** — reviewed and accepted as unattainable on staging tooling; closed.
- **ID prefixes:** Group 1 — `G1-GVR-*` (GetVerificationRequirements), `G1-CDV-*` (CreateDeliveryVerification),
  `G1-RP-*` (ReplacePackages), `G1-BUP-*` (BulkUpdatePackages), `G1-BGP-*` (BulkGetPackages). Group 2 — `G2-E2E-*`
  (delivery lifecycle), `G2-PICK-*` (picking ready-for-pickup). Cross-cutting — `XC-*`.

---

# GROUP 1 — RPC integration tests (staging, no FPS)

Vehicle: `curl` → deployed staging shoppers (`https://rpc-shoppers-shoppers-stg.instacart.team`, Pumpkin HTTP,
no auth — reachability is VPN/mesh placement only). Orders provisioned via DevGen, stopping **before** batch submit
so FPS is never in the loop. Out-of-band verification via read RPCs, Blazer `shoppers_staging`, and Datadog `custom.*`.

## 1.1 `DeliveryVerificationService.GetVerificationRequirements`

Read path: order shape → resolved requirements. Vehicle:
`/home/bento/group1_staging_validation/get_verification_requirements/`.

| ID | Pri | Title | Disposition |
|----|-----|-------|-------------|
| G1-GVR-01 | P0 | Non-restricted / marketplace → no requirements | **PASS** — dropoff all-empty (proto3 JSON omits false bools) |
| G1-GVR-02 | P0 | Alcohol, US zone → ID required, `minimum_age=21` | **PASS** |
| G1-GVR-03 | P1 | Alcohol, Canada zone → `minimum_age=19` | **PASS** (distinct from US 21) |
| G1-GVR-04 | P1 | Multiple age-restricted lines → max age | **RSpec-tier** — alcohol path uses zone age, not max-of-lines; per-line ages not DevGen-provisionable. GVR-02/03 prove single-line age. |
| G1-GVR-05 | P1 | RX attended → signature + ID required | **PASS** (min age 18; no-driver `require_rx_signature?` returns true) |
| G1-GVR-06 | P1 | RX unattended, flag ON → ID/signature skipped | **RSpec-tier** — needs a shopper_id from a batch; pre-batch orders never evaluate the flag. |
| G1-GVR-07 | P1 | RX unattended, flag OFF → ID/signature required | **PASS** (no shopper_id → flag false → behaves attended) |
| G1-GVR-08 | P1 | Signature-triggering restricted item (taxonomy 2935) | **RSpec-tier** — no DevGen knob for a specific restricted-taxonomy line. |
| G1-GVR-09 | P0 | PIN handoff order → `pin.required=true`, code echoed | **PASS** (`customer_handoff_pin "4823"` → `{"pin":{"required":true,"code":"4823"}}`) |
| G1-GVR-10 | P0 | `minimum_age` omitted when not required / unknown | **PASS** (live omission half); `:unknown` half **RSpec-tier** |
| G1-GVR-11 | P0 | Nonexistent order_delivery_id → NOT_FOUND | **PASS** (HTTP 404 `not_found`; `rpc_order_details_not_found` metric) |
| G1-GVR-12 | P1 | OrderDetails RPC degraded/404 | **PASS** (same rescue+metric path as GVR-11) |
| G1-GVR-13 | P1 | `require_order_details` ON, details missing | **RSpec-tier** — unreachable via RPC by design (coordinator always supplies `order_details`) |
| G1-GVR-14 | P1 | `require_order_details` on/off both resolve | **PASS** (flag-insensitive at this RPC — `order_details` always supplied) |
| G1-GVR-15 | P1 | Signature by delivery state (`retailers_alcohol_signature_by_state`) | **PASS** (CA excluded → signature false; Roulette eval confirms allowlist) |
| G1-GVR-ZERO | P0 | `order_delivery_id = 0` | **PASS-with-finding** — read path has **no** id>0 guard; `0 → OrderDetails.get(0) → 404 not_found` (not `InvalidArgument`). See Finding F5. |

**Coverage:** 11 PASS · 4 RSpec-tier (04, 06, 08, 13) · 1 PASS-with-finding (GVR-ZERO) = 16. No open/blocked items.

> The `GetVerificationRequirements` response has **no** proof-of-delivery-photo requirement field. Photo is attempted
> on inbound, not surfaced as an outbound read requirement — do not assert a photo requirement here.

## 1.2 `DeliveryVerificationService.CreateDeliveryVerification`

Write path, idempotent. Vehicle: `/home/bento/group1_staging_validation/create_delivery_verification/`.

**Validation & sub-field persistence**

| ID | Pri | Title | Disposition |
|----|-----|-------|-------------|
| G1-CDV-01 | P0 | `order_delivery_id ≤ 0` rejected | **PASS** (HTTP **500** wrapping `GRPC::InvalidArgument` — see Finding F1) |
| G1-CDV-02 | P0 | Neither pickup nor dropoff present → rejected | **PASS** (HTTP 500, distinct msg) |
| G1-CDV-03 | P0 | Pickup, zero packages → empty shell | **PASS** (200; no package rows, no error) |
| G1-CDV-04 | P0 | Proof-of-delivery photo persisted | **PASS** (live, 2026-08-07 after the T5 filename fix #843586) — `shopper_order_delivery_photos` row with `.png` key; `proof_of_delivery_photo_persistence` metric `success:true` |
| G1-CDV-05 | P1 | Photo address resolution | **PASS** (row keyed by `(order_delivery_id, address_id)`, address_id resolved) |
| G1-CDV-06 | P0 | ID `verified=true` persisted | **PASS** (`order_delivery_identifications` row, `source=fulfillment_provider`) |
| G1-CDV-07 | P1 | ID `verified=false` → no-op | **PASS** (no row) |
| G1-CDV-08 | P0 | PIN `verified=true` → CertifiedDelivery COMPLETED | **PASS** (`awaiting_arrival → COMPLETED`, reproduced on two orders) |
| G1-CDV-09 | P1 | PIN `verified=false` → no-op | **PASS** (state unchanged) |
| G1-CDV-10 | P1 | PIN, no CertifiedDelivery row | **PASS** (skip; `reason=not_found` metric) |
| G1-CDV-11 | P2 | PIN on non-`pin_exchange` cert type | **Won't-do** — off-nominal shape unprovisionable by any staging tooling; user-accepted, closed |
| G1-CDV-12 | P0 | Signature persisted (private S3) | **PASS** (`customer_signature = <id>-<sha256>.png`) |
| G1-CDV-13 | P1 | Non-PNG signature preserves content type | **PASS** (`.jpg` preserved, not forced `.png`) |
| G1-CDV-14 | P1 | Blank signature/photo URL → no-op | **PASS** (no error, no metric) |
| G1-CDV-15 | P1 | Multiple photo `image_urls` → first used | **PASS** (live; exactly one row; >1-url warn is log-only) |
| G1-CDV-16 | P0 | Full dropoff, all types in sequence | **RSpec-tier** — components each verified independently (04/06/08/12); the true combined all-types run needs seeded barcoded bags (same limitation as G2 barcodes) and was the RELAY-919 repro (Finding F3) |
| G1-CDV-17 | P0 | Same request twice → idempotent | **PASS** (byte-identical row, `updated_at` unchanged, no double emit) |
| G1-CDV-18 | P1 | Photo unique-index race → idempotent no-op | **RSpec-tier** (concurrency) |
| G1-CDV-19 | P1 | Signature already present → skipped | **PASS** (`updated_at` unchanged, no re-download) |
| G1-CDV-20 | P1 | Signature TaskLock concurrency | **RSpec-tier** (concurrency) |
| G1-CDV-21 | P1 | ID already exists → skip insert | **PASS** (single row) |
| G1-CDV-22 | P1 | PIN already COMPLETED → skipped | **PASS** (state stays COMPLETED, `created_at` unchanged) |
| G1-CDV-23 | P1 | Job retried after partial success | **RSpec-tier** (job re-invoke) |
| G1-CDV-24 | P0 | Download 4xx (expired URL) → log-and-skip, no retry | **PASS** (`error_type=http_client_error`, single attempt) |
| G1-CDV-25 | P0 | Download 5xx / timeout → re-raised, Sidekiq retries | **PASS** (`error_type=http_error` ×3 retries) |
| G1-CDV-26 | P1 | Image >20 MB → `too_large`, skip | **PASS** (40 MB image; `too_large` metric, log-and-skip) |
| G1-CDV-27 | P1 | Unsupported content type → skip | **PASS** (`unsupported_content_type`) |
| G1-CDV-28 | P1 | Non-https / SSRF-blocked URL → skip | **PASS** (`error_type=non_https` — scheme guard fires first, not the private-IP SSRF filter; see Finding F2) |
| G1-CDV-29 | P1 | Photo, no resolvable address_id → graceful skip | **PASS** (`no_address_id` metric — the graceful path, distinct from the raise path in F3) |
| G1-CDV-30 | P0 | Job exhausts 3 retries → paging metric | **RSpec-tier** (3× retries observed via CDV-25; exhaustion metric not asserted live) |
| G1-CDV-31 | P1 | Hub publish failure after photo row → swallowed | **RSpec-tier** (fault injection) |
| G1-CDV-32 | P1 | Provider omits a requested verification | **FPS-tier (→ Group 2)** — `missing_required_verification` is emitted only by the FPS Go wrapper; the shoppers RPC has no such cross-check |
| G1-CDV-33 | P1 | Recorded package absent from payload | **FPS-tier (→ Group 2)** — same FPS wrapper (`kind:package`) |
| G1-CDV-34 | P0 | Base64 proto round-trip integrity | **PASS** (implicit — nested sub-fields survived the Sidekiq string arg across 04/06/12) |

**Coverage:** 25 PASS · 6 RSpec-tier (16, 18, 20, 23, 30, 31) · 1 won't-do (11) · 2 → Group 2 (32, 33) = **34**.

## 1.3 `PackagesService.ReplacePackages`

3P-picking package save. The handler validates **only `order_delivery_id`**; per-package validations
(`visual_identifier` required, `location_type` enum, empty `details`) run **FPS-side** before the call. Vehicle:
`/home/bento/group1_staging_validation/replace_packages/` (order_delivery_id `20812396763494404`).

| ID | Pri | Title | Disposition |
|----|-----|-------|-------------|
| G1-RP-01 | P0 | Happy path, full details | **PASS** (2 bags; visual/scan-type/location round-trip) |
| G1-RP-02 | P1 | Minimal valid (visual_identifier only) | **PASS** |
| G1-RP-03 | P1 | Multiple packages one payload | **PASS** (`index` is **1-based**) |
| G1-RP-04 | P1 | Array with one empty element → 1 bag | **PASS** (id/type/index only, data fields nil) |
| G1-RP-05 | P1 | No array → backfill | **FPS-enforced** — RPC returns `{}` / 0 rows; the "1 backfilled row with `has_alternative_identifier=true`" is FPS-side (`builder.go`), not RPC. Contrast RP-04 (empty *element* → 1 nil bag) vs RP-05 (no *array* → 0 bags). |
| G1-RP-06 | P1 | `scan_identifier_type` mapping | **PASS** (CODE_39 / QR_CODE / absent→UNKNOWN) |
| G1-RP-07 | P1 | `location_type` enum values | **PASS** (FREEZER/SHELF/FRIDGE/HOT round-trip) |
| G1-RP-08 | P0 | Re-send before submission → atomic replace | **PASS** (old bags deleted, new created atomically; new bag ids prove delete+recreate) |
| G1-RP-09 | P0 | `order_delivery_id ≤ 0` → rejected | **PASS** (HTTP **400** `invalid_argument` — this handler validates at the RPC layer) |
| G1-RP-10 | P0 | Empty `details` array → error | **FPS-enforced** (before RPC) |
| G1-RP-11 | P0 | Missing/empty `visual_identifier` → error | **FPS-enforced** (before RPC) |
| G1-RP-12 | P0 | Invalid `location_type` → error | **FPS-enforced** (before RPC) |
| G1-RP-13 | P0 | Already submitted → skip replace | **FPS-enforced** (FPS skips the call) |

**Coverage:** 8 PASS · 5 FPS-enforced (05, 10–13).

## 1.4 `PackagesService.BulkUpdatePackages`

Sets `found_at` (pickup) / `verified_at` (dropoff) on matching bags by scan. Vehicle:
`/home/bento/group1_staging_validation/bulk_update_packages/`. The executed harness IDs below (V01–V04 validation,
01–11 behavior) are the record; an earlier design-phase numbering was superseded after reconciliation against the
code and the live run.

| ID | Pri | Title | Disposition |
|----|-----|-------|-------------|
| G1-BUP-V01 | P0 | `order_delivery_id = 0` → 400 "order_delivery_id is required" | **PASS** |
| G1-BUP-V02 | P0 | Empty `packages` → 400 "packages is required" | **PASS** |
| G1-BUP-V03 | P0 | Missing `scan_identifier` → 400 "scan_identifier is required for every package" | **PASS** |
| G1-BUP-V04 | P1 | Blank `scan_identifier ""` → same 400 (`.blank?` guard) | **PASS** |
| G1-BUP-01 | P0 | Pickup scan sets `found_at` + `found_via=SCANNER`; verified stays null | **PASS** |
| G1-BUP-02 | P0 | Dropoff scan sets `verified_at` + `verified_via`; found stays null | **PASS** |
| G1-BUP-03 | P0 | All four fields set in one input | **PASS** |
| G1-BUP-04 | P1 | `found_via=FORCE_MARK` round-trips (DB "force_mark") | **PASS** |
| G1-BUP-05 | P0 | Partial update: send verified only → found **preserved**, no clobber | **PASS** |
| G1-BUP-06 | P1 | `found_via=UNKNOWN` dropped; `found_at` still persists (found_via NULL) | **PASS** (Finding F4) |
| G1-BUP-07 | P0 | Unknown scan → 404 `not_found` + `reason=not_found` metric | **PASS** |
| G1-BUP-08 | P0 | Mixed valid+bad → whole `Bag.transaction` rolls back | **PASS** (valid update reverted; atomic) |
| G1-BUP-09 | P1 | One scan matches multiple bags → all updated, warn + `reason=multiple_bags` | **PARTIAL** — both rows updated + HTTP 200 confirmed live (Blazer read-back); the `multiple_bags` metric/warn emission could not be independently captured (staging shoppers telemetry not observable via available tooling). Emission is in the same branch that updated both rows, so it provably executed. |
| G1-BUP-10 | P0 | 4 bags updated in one call; each bag's verified_* preserved | **PASS** |
| G1-BUP-11 | P1 | Identical replay → DB no-op, `updated_at` **not** bumped | **PASS** (Finding F4) |

**Coverage:** 14 PASS · 1 PARTIAL (09). No `verified_at`-required rule exists (all timestamp/via fields are optional);
there is **no success metric** — only `packing_domain.bulk_update_packages.fail{reason=not_found|multiple_bags}`.

## 1.5 `PackagesService.BulkGetPackages`

Read/verification vehicle used to confirm every write above. Also permuted in its own right. Vehicle:
`/home/bento/group1_staging_validation/bulk_get_packages/`.

| ID | Pri | Title | Disposition |
|----|-----|-------|-------------|
| G1-BGP-01 | P0 | New fields round-trip from DB (2 pkgs) | **PASS** (visual/scan-type/location/found/verified) |
| G1-BGP-02 | P0 | Multi-delivery, reversed request order | **PASS** (sorted odid ASC then index ASC; flat `packages[]`) |
| G1-BGP-03 | P1 | Mix of populated + zero-package delivery | **PASS** (zero-package delivery contributes nothing) |
| G1-BGP-04 | P1 | Valid-but-empty delivery | **PASS** (200 `{}`) |
| G1-BGP-05 | P1 | Nonexistent odid | **PASS** (200 `{}`, silently ignored) |
| G1-BGP-06 | P1 | Large list (2+3+0 + 7 nonexistent) | **PASS** (5 rows; empties ignored) |
| G1-BGP-07 | P0 | Empty list → 400 "order_delivery_ids is required" | **PASS** |
| G1-BGP-08 | P1 | Omitted field → 400 (decodes to empty) | **PASS** |
| G1-BGP-09 | P2 | Duplicate id in request → de-duped | **PASS** (2 rows, not 4) |
| G1-BGP-10 | P0 | `order_delivery_id = 0` | **FAIL** — Finding F6 (bulk path has no zero-guard → full-table seq scan → request hangs/times out) |
| G1-BGP-11 | P0 | `[0, valid]` mixed | **FAIL** — Finding F6 (any batch containing 0 hangs) |
| G1-BGP-12 | P2 | Non-numeric id | **PASS** (codec-layer 500 `Encoding error`, before the handler) |

**Coverage:** 10 PASS · 2 FAIL (10, 11 — one genuine reliability defect, Finding F6).

---

# GROUP 2 — End-to-end integration tests (with FPS)

The Go `cmd/integration_tests` harness drives each scenario: DevGen provisions a real order, FPS runs the lifecycle,
FPT simulates the partner (inbound webhooks and the outbound `SubmitDelivery` capture), and read-only shoppers-DB
queries assert what landed. Everything below is **coded and registered in `main.go`** — this is the exact set of
delivery-verification suites that exist.

> **Run vehicle.** `bazel run //fulfillment/fulfillment_provider_service/cmd/integration_tests -- --scenarios
> staging:integration_test` (requires a VPN-connected host with `.env.staging` provisioned). `--name` selects
> individual tests. The base `EndToEnd` suite also runs in the `canary` use case.

## 2.1 Delivery lifecycle suites

### G2-E2E-01 — Happy path, no verification required · P0

- **Suite / test:** `endtoend.go` · `RegisterEndToEnd` · `"EndToEnd/3P delivery submitted->delivered (no mocks,
  DevGen + FPT)"`.
- **Scenarios:** staging + development, both `integration_test` and `canary`.
- **Order shape:** plain marketplace order — no alcohol, PIN, barcodes; attended. Warehouse 1 / store 50 / zone 1 (SF).
- **Flow:** DevGen seeds the order + 3P batch (auto-calls FPS `SubmitBatch`) → assert step `submitted`; fire every
  happy-path inbound event via FPT → assert the step reaches `delivered`.
- **Asserts (negative):** a no-requirements order persists **no** verification of any kind — 0 identification rows,
  no completed certified delivery, no signature, 0 delivery photos, 0 packages (`AssertNoVerificationPersisted`,
  after a settle delay so the async job can't false-pass).

### G2-E2E-02 — Full inbound + outbound verification · P0

- **Suite / test:** `endtoend_full_verification.go` · `RegisterEndToEndFullVerification` ·
  `"EndToEndFullVerification/end-to-end with full inbound and outbound payload"`.
- **Scenarios:** staging + development, `integration_test`.
- **Order shape:** attended alcohol (drives age-restricted ID + signature) + PIN-exchange certified delivery
  (`customer_handoff_pin = 4242`). Warehouse 1 / **store 8047** (Queen Creek, AZ — stocks alcohol on staging; AZ is an
  enabled signature-by-state) / zone 367. Two barcoded packages seeded via the packing `CreatePackages` RPC.
- **Outbound assert (via FPT body matchers — the `SubmitDelivery` request FPS sends is gated on all of these):**
  `signature.required=true`, `proof_of_delivery_photo.required_if_delivery_unattended=true`,
  `id_verification.required=true`, `id_verification.minimum_age=21`, `pin.required=true`, `pin.code=4242`,
  `packages.barcode_scan_required=true`.
- **Inbound flow:** fire the happy path; `delivery_pickup_completed` carries the package scans;
  `delivery_completed` carries ID + PIN + signature + proof-of-delivery photo + package scans.
- **Persistence asserts (shoppers DB):** certified delivery → `COMPLETED`; ≥1 `order_delivery_identifications` row
  with `source=fulfillment_provider`; **both** packages get `found_at` (pickup) and `verified_at` (dropoff);
  `order_delivery_properties.customer_signature` set; ≥1 `shopper_order_delivery_photos` row.
- **Idempotency:** replay `delivery_completed` → FPS **rejects** it on terminal status
  (`"already in terminal status: delivered"`) and the identification count is unchanged.

### G2-E2E-03 — Reconcile fallback · P2

- **Suite / test:** `endtoend_reconcile.go` · `RegisterEndToEndReconcile` ·
  `"EndToEndReconcile/end to end reconciliation job test"`.
- **Scenarios:** staging + development, `integration_test`.
- **Order shape:** same alcohol + PIN shape as G2-E2E-02; two barcoded packages seeded.
- **Precondition:** the step is deliberately stuck — only `delivery_acknowledged` is fired; no further webhooks.
- **Flow:** the `ReconcileDeliveryWorkflow`'s `get_delivery` poll is answered (via FPT) with `status=delivered` +
  full dropoff and pickup verification. The suite waits out the real stuck threshold (poll cap 12 min, 15 s interval).
- **Asserts:** reconcile carries the step to `delivered` on its own and persists via the **same** save path as the
  webhook — full delivery-verification persistence (cert COMPLETED, `fulfillment_provider` ID row, package
  `found_at`/`verified_at`, signature, photo).

## 2.2 Picking ready-for-pickup suites

Suite: `picking_ready_for_pickup.go` · `RegisterPickingReadyForPickup`. Both provision an order + picking batch via
DevGen, insert the picking step in `submitted`, fire a single `picking_ready_for_pickup` inbound event via FPT, and
assert the step reaches `ready_for_pickup`. Scenarios: staging + development, `integration_test`.

### G2-PICK-01 — Ready-for-pickup with packages · P1

- **Test:** `"PickingReadyForPickup/picking ready-for-pickup with packages"`.
- **Flow:** the event carries two package details (visual_identifier, `code_39` barcode, `shelf` location).
- **Assert:** packages are persisted, read back through `BulkGetPackages` — each seeded barcode present with a
  non-empty `visual_identifier`.

### G2-PICK-02 — Ready-for-pickup without packages · P1

- **Test:** `"PickingReadyForPickup/picking ready-for-pickup without packages"`.
- **Flow:** the event carries no packages.
- **Assert:** FPS synthesizes a single package with `has_alternative_identifier=true` (the missing-array rule),
  confirmed via `BulkGetPackages`.

## 2.3 Also in the harness (not delivery-verification)

These suites share the harness and run in the same runs, but exercise the constraints/config surface rather than
delivery verification: `SubmitBatch` (`submit_batch.go`), `ProviderCRUD`, `PartnerConfig`, `RuleCRUD`, `StrategyCRUD`.

## 2.4 Coverage notes

- FPS gRPC error taxonomy is clean: a real gRPC client sees `INVALID_ARGUMENT` regardless of the HTTP-adapter
  asymmetry that Group 1 curl observes (Finding F1). Group 2 asserts on the gRPC status / step behavior.
- The following FPS behaviors are pinned by **existing Go unit tests**, so Group 2 does not re-assert them
  end-to-end: nil/empty requirements → payload built with shells; `GetVerificationRequirements` RPC error →
  activity retries; submit retry after transient outage; pickup/dropoff primitive-disabled → no-op + metric;
  reconcile persist-failure → no premature terminal transition; reconcile step-not-found → error/metric.
  (`delivery_activities_test.go`, `process_partner_delivery_*_test.go`, `reconcile_delivery_workflow_test.go`.)

---

# Cross-cutting — regression, compliance & monitoring

Assertions that must hold regardless of which group exercised the path. Verify in whichever suite is convenient
(RSpec for data-shape/CODEOWNERS; the FPS harness or manual staging for cross-order and monitoring).

| ID | Pri | Title | Expected |
|----|-----|-------|----------|
| XC-REG-01 | P0 | Zero regression for 1P/LMD orders | Existing ReplacePackages/GetPackages/UpdatePackage callers pass unchanged (additive nullable schema) |
| XC-REG-02 | P0 | 1P delivery under same user as a 3P order | Photo/signature/ID/PIN reads unaffected |
| XC-REG-03 | P0 | `user_id` queries filter 1P vs 3P rows | 3P rows filtered via LEFT JOIN on `fulfillment_provider_fulfillment_steps` |
| XC-REG-04 | P0 | ML "best photo" excludes 3P photos | 3P rows NOT scored / marked `is_best` (legal requirement) |
| XC-REG-05 | P1 | First-party `verify_bags` omega flow intact | Unaffected by the 3P path |
| XC-REG-06 | P1 | PoD photo visible in CS tools like 1P | Photo appears the same as 1P |
| XC-REG-07 | P1 | Signature stored privately | On the private bucket (`instacart-private-shopper-<env>`), not the public CDN |
| XC-REG-08 | P1 | Omega transition ignores package info | Gating is FPS-side only |
| XC-REG-09 | P1 | CODEOWNERS magic comment on moved files | Every Ruby file retains its `# owner …` comment |
| XC-REG-10 | P1 | Monitoring emitted | Packages RPC request/error/latency; FPS inbound-webhook + outbound submit-delivery failure metrics; per-type persistence success/failure metrics fire |

---

# Findings (code-grounded, worth recording)

- **F1 — Validation surfaces as HTTP 500 (not 400) over the Pumpkin HTTP adapter for `DeliveryVerificationService`.**
  `GRPC::InvalidArgument` → HTTP 500 `{code:internal, meta.error_class:GRPC::InvalidArgument, msg:"3:…"}`. Note the
  asymmetry: `PackagesService` returns a clean HTTP 400 `invalid_argument`. A real gRPC client (the FPS / Group 2 path)
  sees `INVALID_ARGUMENT` regardless — so Group 2 asserts the gRPC status, and Group 1 curl expectations encode
  500-vs-400 per service.
- **F2 — `http://` is rejected by a scheme guard (`non_https`), not the private-IP SSRF filter.** The scheme check
  fires first (G1-CDV-28).
- **F3 — Photo persistence re-raises with no per-step isolation (RELAY-919).** `CreateDeliveryVerificationJob`
  dispatches packages → photo → id → pin → signature with no per-step rescue, and the photo step is the one that
  re-raises on an unexpected error. A failing photo (or packages) step aborts **every** verification type after it and
  drives the job to retry-exhaustion. Proven on staging (photo+signature persisted nothing, yet signature-only and
  id-only succeeded on the same order). The **T5 fix (#843586)** — attach `original_filename` to the downloaded IO —
  is deployed and working on staging, so the photo happy path (CDV-04/05/15) now passes; the broader per-step-isolation
  hardening is RELAY-919.
- **F4 — `BulkUpdatePackages` enum & idempotency behavior.** A `SCAN_METHOD_UNKNOWN` via is silently dropped
  (`enum_name_or_nil`) while its `found_at`/`verified_at` still persists (found_via/verified_via NULL). An identical
  replay is a true DB no-op — `update!` skips the write when no attribute is dirty, so `updated_at` is not bumped.
- **F5 — `GetVerificationRequirements` has no `order_delivery_id > 0` guard** (unlike `CreateDeliveryVerification`).
  `0` flows to `OrderDetails.get(0)` → 404 `not_found`, not `InvalidArgument`.
- **F6 — `BulkGetPackages` has no per-odid zero-guard → reliability/DoS (FAIL).** An `order_delivery_id = 0` anywhere
  in the batch reaches the DB and forces a full sequential scan of `bags` (`EXPLAIN` shows a seq scan, est. ~1B rows,
  vs an index scan for real ids), hanging the request (~30 s+ timeout). The handler only checks `.empty?` on the list.
  Single-id methods reject 0; the bulk path does not.

---

# Notes & confirmed behaviors

- **RPC naming.** ERDs referred to the write RPC as `SaveDeliveryVerification` / `SaveFulfillmentVerifications`; the
  shipped name is `CreateDeliveryVerification`, returning an empty response.
- **Enum naming.** The proto uses `SCAN_IDENTIFIER_TYPE_UNKNOWN` (ERD text said `…_UNSPECIFIED`). Fixtures use the
  shipped name.
- **PoD photo requirement.** There is no photo-requirement field on `GetVerificationRequirements`; photo is attempted
  on inbound. The outbound payload carries `proof_of_delivery_photo.required_if_delivery_unattended` (asserted in
  G2-E2E-02).
- **Missing-required behavior** is observe-only (metric + log), emitted by the FPS Go wrapper
  (`observeMissingRequiredVerifications`), never by the shoppers RPC — hence G1-CDV-32/33 are FPS-tier.
- **PIN completion.** A PIN-only `CreateDeliveryVerification` completes the certified delivery directly from
  `awaiting_arrival` (the transition is unguarded; the `awaiting_confirmation` check only gates the confirmation push).
